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
/// - **Latency is exposed.** `AUNewTimePitch`'s latency is *rate-dependent* — measured 93 ms at 1×,
///   139 ms at 0.5× — and the song is heard that much after the player renders it, while the click
///   bypasses this node entirely. Compensating that flam (ADR 0140 §3) needs a live reading at the
///   moment rate changes, which is here.
///
/// `pitch` stays 0, always: slowing down is pitch-preserving, and a varispeed "tape" mode is a
/// different product decision (ADR 0140, *What this closes off*).
@MainActor
final class TimeStretcher {

    /// Playback rate bounds. Wider than the UI's own ceiling (ADR 0124 caps the speed axis at 1.5×) —
    /// this is the engine's hard floor and roof, not the product's.
    static let minimumRate = 0.25
    static let maximumRate = 2.0

    private let unit = AVAudioUnitTimePitch()

    /// The current playback rate. Stored rather than read off the unit so the AU stays swappable.
    private(set) var rate: Double = 1.0

    /// The node to wire into the engine's graph. Callers connect *through* it and never touch it
    /// otherwise — which AU is inside is this type's business.
    var node: AVAudioNode { unit }

    /// How far behind the player's render position this unit's output is heard, in real seconds.
    /// Rate-dependent, so it is read live rather than cached.
    var latency: TimeInterval { unit.auAudioUnit.latency }

    init() {
        unit.pitch = 0
        apply(rate: rate)
    }

    /// Set the pitch-preserving playback rate, clamped to the engine's bounds. Returns the rate
    /// actually applied, so a caller that needs to react to a discontinuity acts on the real value.
    @discardableResult
    func setRate(_ newRate: Double) -> Double {
        apply(rate: min(Self.maximumRate, max(Self.minimumRate, newRate)))
        return rate
    }

    /// Write a (pre-clamped) rate and the smoothness that goes with it. One place, one moment — the
    /// two must not drift apart.
    private func apply(rate newRate: Double) {
        rate = newRate
        unit.rate = Float(newRate)
        unit.overlap = StretchQuality.smoothness(forRate: newRate)
    }
}
