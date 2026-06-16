import Foundation

/// Pure audio helpers — no AVFoundation, so they stay unit-testable (per
/// AGENTS.md: pure logic stays free of AVFoundation imports).
enum AudioMath {

    /// Reduce raw samples to `bars` normalised peak values (0...1) for drawing a
    /// waveform. Always returns exactly `bars` values (when input is non-empty).
    static func downsample(_ samples: [Float], to bars: Int) -> [Double] {
        guard bars > 0, !samples.isEmpty else { return [] }
        let count = samples.count
        var peaks = [Double](repeating: 0, count: bars)
        for bar in 0..<bars {
            let start = bar * count / bars
            let end = max(start + 1, (bar + 1) * count / bars)
            var peak: Float = 0
            var index = start
            while index < end && index < count {
                peak = max(peak, abs(samples[index]))
                index += 1
            }
            peaks[bar] = Double(peak)
        }
        let maxPeak = peaks.max() ?? 0
        guard maxPeak > 0 else { return peaks }
        return peaks.map { $0 / maxPeak }
    }

    /// Sample-frame index for a position in seconds.
    static func secondsToFrames(_ seconds: TimeInterval, sampleRate: Double) -> Int {
        Int((seconds * sampleRate).rounded())
    }

    /// Position in seconds for a sample-frame count.
    static func framesToSeconds(_ frames: Int, sampleRate: Double) -> TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(frames) / sampleRate
    }

    /// Frame range for a loop region, clamped to the file. Returns the start
    /// frame and the number of frames to play before wrapping back to the start.
    /// `start`/`end` are seconds; out-of-order or out-of-range inputs are clamped
    /// so the result is always a valid, non-negative segment inside the file.
    static func loopSegment(start: TimeInterval, end: TimeInterval,
                            sampleRate: Double, totalFrames: Int) -> (startFrame: Int, frameCount: Int) {
        guard sampleRate > 0, totalFrames > 0 else { return (0, 0) }
        let lower = min(start, end)
        let upper = max(start, end)
        let startFrame = min(max(0, secondsToFrames(lower, sampleRate: sampleRate)), totalFrames)
        let endFrame = min(max(0, secondsToFrames(upper, sampleRate: sampleRate)), totalFrames)
        return (startFrame, max(0, endFrame - startFrame))
    }
}
