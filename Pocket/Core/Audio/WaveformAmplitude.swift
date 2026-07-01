import Foundation

/// Display-only shaping of the waveform envelope (ADR 0049). The stored envelope is already
/// peak-normalised to 0…1 (`AudioMath.downsample`, 95th-percentile reference), but drawn
/// **linearly** most bars sit well below the ceiling, giving the jagged, low skyline that
/// reads as "aggressive" in user testing. A gamma curve (< 1) lifts the quiet/mid bars toward
/// the top — the dynamic-range compression a *display* waveform (SoundCloud, DAW clip
/// envelopes) uses for a fuller, calmer read — while pinning the endpoints so silence stays
/// flat and a full bar stays full.
///
/// **Display only.** Snapping, markers and loop edges read the raw peaks elsewhere; this
/// shapes *only* the drawn height, so editing precision is untouched. That's the
/// accuracy-vs-appeal trade resolved by decoupling render from data — not by smoothing the
/// samples we position against (AGENTS.md: this timing/geometry math is unit-tested).
enum WaveformAmplitude {
    /// The compression exponent. `< 1` lifts low values (`0.25^0.6 ≈ 0.43`); `1.0` is the old
    /// linear draw. 0.6 gives a full skyline without flattening every bar onto the ceiling.
    static let displayGamma = 0.6

    /// Shape a normalised amplitude (0…1) into its drawn fraction (0…1). Monotonic and
    /// endpoint-preserving; values outside 0…1 clamp so a stray reading can't invert or
    /// overshoot the region.
    static func display(_ amplitude: Double, gamma: Double = displayGamma) -> Double {
        let clamped = min(1, max(0, amplitude))
        return pow(clamped, gamma)
    }
}
