import Foundation

/// Display-only bar aggregation for the waveform (ADR 0049). Compression (`WaveformAmplitude`)
/// lifts the skyline but leaves a fine 1px comb that reads as jittery/uneasy in user testing.
/// When the stored envelope is drawn far more densely than the screen can meaningfully show
/// (zoomed out, ~512 bars across a phone width → ~1px bars), neighbouring bars are grouped into
/// one **wider** drawn bar whose height is their mean. Wider *and* smoother: the averaging
/// low-passes the comb, so the waveform reads as deliberate bars, not a dense picket fence.
///
/// It self-tunes with zoom — when bars are already at least the target width (zoomed in, or a
/// crisp windowed re-downsample, ADR 0020), the group size is 1 and nothing changes, so deep
/// zoom keeps full transient detail. **Display only:** snapping/markers read the raw peaks.
enum WaveformBars {
    /// How many source bars collapse into one drawn bar to reach `targetPitch` on screen.
    /// `sourcePitch` is the current on-screen distance between source bars. Never below 1
    /// (can't un-draw), and 1 whenever the bars are already wide enough — a pure widen, never
    /// a thinning.
    static func groupSize(sourcePitch: Double, targetPitch: Double) -> Int {
        guard sourcePitch > 0, targetPitch > sourcePitch else { return 1 }
        return max(1, Int((targetPitch / sourcePitch).rounded()))
    }

    /// Collapse `bars` into buckets of `group`, each the **mean** of its members (the trailing
    /// bucket may be smaller). `group <= 1` returns the input unchanged. Mean, not peak, is the
    /// point — it smooths the comb rather than preserving every spike.
    static func bucketedMean(_ bars: [Double], group: Int) -> [Double] {
        guard group > 1, !bars.isEmpty else { return bars }
        var out: [Double] = []
        out.reserveCapacity((bars.count + group - 1) / group)
        var index = 0
        while index < bars.count {
            let upper = min(index + group, bars.count)
            var sum = 0.0
            for position in index..<upper { sum += bars[position] }
            out.append(sum / Double(upper - index))
            index = upper
        }
        return out
    }
}
