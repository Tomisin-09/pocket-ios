import Foundation

/// Pure, UI-free **stretch quality** math: the time-pitch unit's smoothness setting for a given
/// playback rate (ADR 0140 §2).
///
/// `AVAudioUnitTimePitch.overlap` is the parameter iOS 16 renamed **Smoothness**
/// (`kNewTimePitchParam_Overlap` → `kNewTimePitchParam_Smoothness`, same id 4). Apple documents it as
/// *"a higher value results in fewer artifacts in the output signal"*, range 3–32, default 8, with CPU
/// cost directly proportional. The engine used to pin it at **3.0** — the *minimum*, i.e. maximum
/// artifacts — on the theory that a low value keeps pick attacks crisp. It doesn't: transient
/// crispness is `EnableTransientPreservation`'s job (a different parameter, on by default), and the
/// documented carve-out for low values is *percussive* material. Ours is whole backing tracks —
/// sustained guitar, vocals, cymbals, room — which is the case the floor is worst for.
///
/// **The shape.** Artifacts track the *stretch factor* (`1/rate`), not the rate: 0.5× asks the phase
/// vocoder to make one second of audio last two, 0.25× to make it last four. So smoothness climbs
/// linearly in stretch factor, passing the 8.0 default around 0.5× and reaching the high teens at
/// 0.25× where the stretch is largest and the artifacts worst. At and above 1× nothing is being
/// stretched, so it rests at a low value and the CPU is left alone.
///
/// **Cannot desync the click.** Smoothness was measured not to change the AU's reported latency
/// (0.0929 s at both 3.0 and 8.0), so this is independent of ADR 0140's latency compensation.
///
/// Kept free of AVFoundation so the curve is unit-tested per AGENTS.md — it is exactly the kind of
/// silent-breaking math the repo insists on covering.
enum StretchQuality {

    /// The AU parameter's own bounds (`AVAudioUnitTimePitch.overlap`, range 3–32). Output is clamped
    /// into these, so no rate — however extreme — can produce a value the unit would reject.
    static let minimumSmoothness: Float = 3.0
    static let maximumSmoothness: Float = 32.0

    /// Smoothness at and above 1×, where no stretching happens. Deliberately *below* the 8.0 default:
    /// there are no stretch artifacts to smooth away at unity, and the parameter costs CPU for a whole
    /// practice session's worth of playback.
    static let unitySmoothness: Float = 4.0

    /// How much smoothness each extra unit of stretch factor buys. Sized so the 4× stretch at 0.25×
    /// lands at 18.0 — the high teens the ADR calls for, comfortably inside the AU's 32 ceiling.
    static let smoothnessPerStretchFactor: Float = 14.0 / 3.0

    /// The smoothness to run the time-pitch unit at for playback `rate`.
    ///
    /// Monotonically **non-increasing** in rate: slowing down never makes the output less smooth.
    /// A non-positive rate (never reachable through the engine, which clamps) falls back to unity
    /// rather than dividing by zero.
    static func smoothness(forRate rate: Double) -> Float {
        guard rate > 0 else { return unitySmoothness }
        let stretchFactor = 1.0 / rate                     // 0.5× ⇒ the audio is stretched 2× longer
        let extraStretch = Float(max(0, stretchFactor - 1))  // 0 at and above 1×
        let raw = unitySmoothness + extraStretch * smoothnessPerStretchFactor
        return min(maximumSmoothness, max(minimumSmoothness, raw))
    }
}
