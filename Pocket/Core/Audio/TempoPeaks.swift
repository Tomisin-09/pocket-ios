import Foundation

/// Pure transient-peak snapping for placing the downbeat ("the 1") on the waveform
/// (ADR 0024).
///
/// Snare/kick hits surface as the loudest bars in the envelope, so the downbeat handle
/// snaps to the most prominent bar near where it's dropped — assisted precision without
/// frame-perfect dragging, in the same spirit as the gesture snap of ADR 0021. Snapping
/// against the *currently displayed* bars means a deep zoom (crisp re-downsample, ADR
/// 0020) gives finer peaks for free. UI-free so the arithmetic is unit-tested.
enum TempoPeaks {

    /// The song fraction of the highest-amplitude bar within `searchRadius` (a song
    /// fraction) either side of `target`. `bars` cover `[coveredStart, coveredEnd]` of
    /// the song — the whole envelope (`[0, 1]`) or a crisp zoomed window — each placed at
    /// its centre via `WaveformGesture.barCentreFraction`. Returns `nil` when no bar
    /// falls in range (the caller keeps the raw drop). Ties resolve to the bar nearest
    /// `target`, so a flat stretch doesn't jump the handle sideways.
    static func snap(toFraction target: Double, bars: [Double],
                     coveredStart: Double = 0, coveredEnd: Double = 1,
                     searchRadius: Double) -> Double? {
        guard !bars.isEmpty, coveredEnd > coveredStart, searchRadius > 0 else { return nil }
        let lower = target - searchRadius
        let upper = target + searchRadius
        var bestFraction: Double?
        var bestAmp = -Double.greatestFiniteMagnitude
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, amp) in bars.enumerated() {
            let fraction = WaveformGesture.barCentreFraction(
                index: index, count: bars.count, coveredStart: coveredStart, coveredEnd: coveredEnd)
            guard fraction >= lower, fraction <= upper else { continue }
            let distance = abs(fraction - target)
            // Higher amplitude wins; equal amplitude → the bar nearer the drop.
            guard amp > bestAmp || (amp == bestAmp && distance < bestDistance) else { continue }
            bestFraction = fraction
            bestAmp = amp
            bestDistance = distance
        }
        return bestFraction
    }
}
