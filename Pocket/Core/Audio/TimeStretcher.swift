import AVFoundation

/// The one owner of the practice graph's time-stretching audio unit: its **node**, its **rate** and
/// its **latency** (ADR 0140 §1). Every slowdown surface in the app — the waveform speed slider, the
/// loop-run percent, the song play-along percent — funnels through `PracticeAudioEngine.setRate` onto
/// this one object.
///
/// Three jobs that were previously scattered or absent:
///
/// - **Rate is stored, not read back off the unit.** Apple's *high quality* stretcher (`'tmpt'`,
///   ADR 0140 §4) is an `AVAudioUnitTimeEffect` with no Swift `rate` property — its rate goes via
///   `AudioUnitSetParameter`. Callers that need the current rate (the metronome's real-time divide)
///   read it from here, so swapping the AU underneath never reaches them.
/// - **Smoothness follows the rate.** Set in one place, from the pure `StretchQuality` curve, at the
///   same moment rate is written. See that type for why the old pinned `overlap = 3.0` was backwards.
/// - **Latency is exposed.** The stretcher's latency is *rate-dependent* — `'nutp'` measured 93 ms at
///   1×, 139 ms at 0.5× — and the song is heard that much after the player renders it, while the
///   click bypasses this node entirely. Compensating that flam (ADR 0140 §3) needs a live reading at
///   the moment rate changes, which is here.
///
/// `pitch` stays 0, always: slowing down is pitch-preserving, and a varispeed "tape" mode is a
/// different product decision (ADR 0140, *What this closes off*).
@MainActor
final class TimeStretcher {

    /// Playback rate bounds. Wider than the UI's own ceiling (ADR 0124 caps the speed axis at 1.5×) —
    /// this is the engine's hard floor and roof, not the product's. Both of Apple's stretchers cover
    /// this range: `'nutp'` spans 1/32…32, `'tmpt'` spans 0.25…4.0 — which puts our floor *exactly* on
    /// `'tmpt'`'s boundary, and is why ADR 0140 §4's adoption rule names 0.25× as a case to check at
    /// the boundary rather than near it.
    static let minimumRate = 0.25
    static let maximumRate = 2.0

    /// Which of Apple's two stretchers is inside. Apple describes `AVAudioUnitTimePitch` as *"good
    /// quality"* and `kAudioUnitSubType_TimePitch` as *"high quality time stretching"*, and the header
    /// says `NewTimePitch` *"is computationally less expensive"* — cheaper is the only advantage
    /// claimed for the one we have always used.
    ///
    /// ADR 0140 §4 declined to swap on that basis alone and put the question behind a device A/B.
    /// **The A/B was run on 2026-08-04 and `'tmpt'` won** — *"the sound quality is so much better"* —
    /// so it is now the default and there is no toggle. `.newTimePitch` survives as the **fallback**
    /// for the one case that would otherwise be catastrophic: see `makeHighQualityUnit`.
    enum Kind: Equatable {
        /// `'nutp'` — `AVAudioUnitTimePitch`. No longer the default; retained as the availability
        /// fallback. Rate and smoothness are Swift properties, and smoothness follows the
        /// `StretchQuality` curve — which is why that curve is still live code rather than a leftover.
        case newTimePitch
        /// `'tmpt'` — `kAudioUnitSubType_TimePitch`, Apple's high-quality stretcher, as an
        /// `AVAudioUnitTimeEffect`. **The shipping stretcher.** Rate goes through
        /// `AudioUnitSetParameter`, and it has **no** smoothness parameter — that knob is a
        /// `NewTimePitch` feature, so `StretchQuality` does not apply on this path.
        case highQuality

        /// The kind every build runs. Not a setting and not a Debug flag: ADR 0140 closes off exposing
        /// the stretcher to the player, and §4's rule was that the swap is adopted by *writing it into
        /// the ADR* once the device A/B settles it — which it now has. The only way this resolves to
        /// `.newTimePitch` is the availability fallback in `init`.
        static var configured: Kind { .highQuality }
    }

    /// The unit itself, in the one shape that differs per kind. Everything else about the two is
    /// reached through `AVAudioUnit`, which is why only rate-writing switches.
    private enum Backend {
        case newTimePitch(AVAudioUnitTimePitch)
        case highQuality(AVAudioUnitTimeEffect)

        var unit: AVAudioUnit {
            switch self {
            case .newTimePitch(let unit): return unit
            case .highQuality(let unit): return unit
            }
        }
    }

    /// Which stretcher actually loaded. Not necessarily the one asked for — `'tmpt'` is looked up in
    /// the component registry and we fall back rather than ship a silent graph if it isn't there.
    let kind: Kind

    private let backend: Backend

    /// The current playback rate. Stored rather than read off the unit so the AU stays swappable.
    private(set) var rate: Double = 1.0

    /// The node to wire into the engine's graph. Callers connect *through* it and never touch it
    /// otherwise — which AU is inside is this type's business.
    var node: AVAudioNode { backend.unit }

    /// How far behind the player's render position this unit's output is heard, in real seconds.
    /// Rate-dependent, so it is read live rather than cached. Note `'tmpt'` measured *lower* than
    /// `'nutp'` (79 ms vs 139 ms at 0.5×), which ADR 0140 §4 rules out as a reason to reject it —
    /// §3 compensates whatever it is.
    var latency: TimeInterval { backend.unit.auAudioUnit.latency }

    init(kind requested: Kind = .configured) {
        switch requested {
        case .highQuality:
            if let unit = Self.makeHighQualityUnit() {
                backend = .highQuality(unit)
                kind = .highQuality
            } else {
                backend = .newTimePitch(AVAudioUnitTimePitch())
                kind = .newTimePitch
            }
        case .newTimePitch:
            backend = .newTimePitch(AVAudioUnitTimePitch())
            kind = .newTimePitch
        }
        writePitchZero()
        apply(rate: rate)
    }

    /// Set the pitch-preserving playback rate, clamped to the engine's bounds. Returns the rate
    /// actually applied, so a caller that needs to react to a discontinuity acts on the real value.
    @discardableResult
    func setRate(_ newRate: Double) -> Double {
        apply(rate: min(Self.maximumRate, max(Self.minimumRate, newRate)))
        return rate
    }

    /// Re-write the current rate onto the unit without treating it as a change. `'tmpt'`'s parameters
    /// are written with raw `AudioUnitSetParameter` calls, which for an audio unit that has not been
    /// initialised yet are not guaranteed to survive initialisation; the engine only initialises the
    /// AU when it starts. Calling this after `engine.start()` costs one parameter write and removes
    /// the whole question. A no-op in substance for `'nutp'`, whose Swift properties are retained by
    /// the object.
    func reassertRate() {
        apply(rate: rate)
    }

    // MARK: - Private

    /// Instantiate `'tmpt'`. Looked up in the component registry first: it is not a Swift-wrapped AU,
    /// so an absent component would otherwise surface as a dead node in the graph rather than as a
    /// `nil` here.
    ///
    /// **This is the whole reason `.newTimePitch` still exists.** `AVAudioUnitTimeEffect` has no
    /// failable initialiser, so without the lookup an absent `'tmpt'` would leave the practice screen
    /// **silent** — the worst failure this app has, on its most-used feature. The fallback costs a
    /// handful of lines and a `switch` arm; a silent slowdown costs the session.
    private static func makeHighQualityUnit() -> AVAudioUnitTimeEffect? {
        var description = AudioComponentDescription(componentType: kAudioUnitType_FormatConverter,
                                                    componentSubType: kAudioUnitSubType_TimePitch,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0,
                                                    componentFlagsMask: 0)
        guard AudioComponentFindNext(nil, &description) != nil else { return nil }
        return AVAudioUnitTimeEffect(audioComponentDescription: description)
    }

    /// Write a (pre-clamped) rate and, on `'nutp'`, the smoothness that goes with it. One place, one
    /// moment — the two must not drift apart.
    private func apply(rate newRate: Double) {
        rate = newRate
        switch backend {
        case .newTimePitch(let unit):
            unit.rate = Float(newRate)
            unit.overlap = StretchQuality.smoothness(forRate: newRate)
        case .highQuality(let unit):
            AudioUnitSetParameter(unit.audioUnit, kTimePitchParam_Rate,
                                  kAudioUnitScope_Global, 0, Float(newRate), 0)
        }
    }

    /// Pitch is never touched again after this — slowing down is pitch-preserving, full stop.
    private func writePitchZero() {
        switch backend {
        case .newTimePitch(let unit):
            unit.pitch = 0
        case .highQuality(let unit):
            AudioUnitSetParameter(unit.audioUnit, kTimePitchParam_Pitch,
                                  kAudioUnitScope_Global, 0, 0, 0)
        }
    }
}
