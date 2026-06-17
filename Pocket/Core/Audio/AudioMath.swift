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

    /// Average parallel channel sample arrays into a single mono signal — so a
    /// hard-panned track still contributes to the extracted waveform. Channels are
    /// assumed equal length; the result is the length of the shortest. Empty input
    /// returns empty; a single channel passes straight through (no copy of work).
    static func mixToMono(_ channels: [[Float]]) -> [Float] {
        guard let first = channels.first else { return [] }
        guard channels.count > 1 else { return first }
        let frames = channels.map(\.count).min() ?? 0
        guard frames > 0 else { return [] }
        var mono = [Float](repeating: 0, count: frames)
        for channel in channels {
            for index in 0..<frames { mono[index] += channel[index] }
        }
        let scale = 1 / Float(channels.count)
        for index in 0..<frames { mono[index] *= scale }
        return mono
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

    /// Equal-power crossfade gains at `position` frames into a fade of `length`
    /// frames. `fadeIn` rises 0→1, `fadeOut` falls 1→0 along a quarter sine/cosine,
    /// so `fadeIn² + fadeOut² == 1` (constant power — no dip at the seam). Used to
    /// fold a loop's tail into its head for a click-free wrap. Guards `length <= 0`
    /// (returns full head) and clamps `position` into `[0, length]`.
    static func crossfadeGains(position: Int, length: Int) -> (fadeIn: Float, fadeOut: Float) {
        guard length > 0 else { return (1, 0) }
        let progress = Float(min(max(0, position), length)) / Float(length)
        let angle = progress * .pi / 2
        return (sin(angle), cos(angle))
    }

    /// Map continuous elapsed playback time back into a loop region for the
    /// playhead. With gapless looping the player runs without stopping, so
    /// elapsed time grows past the loop end; this wraps it via modulo.
    /// `elapsed` is seconds since the loop's first frame began playing. Guards a
    /// non-positive `loopLength` (returns `loopStart`) and normalises any
    /// negative remainder.
    static func loopedPlayhead(elapsed: TimeInterval, loopStart: TimeInterval,
                               loopLength: TimeInterval) -> TimeInterval {
        guard loopLength > 0 else { return loopStart }
        let pos = elapsed.truncatingRemainder(dividingBy: loopLength)
        return loopStart + (pos < 0 ? pos + loopLength : pos)
    }
}
