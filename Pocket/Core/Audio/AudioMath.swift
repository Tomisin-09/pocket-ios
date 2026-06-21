import Foundation

/// Pure audio helpers — no AVFoundation, so they stay unit-testable (per
/// AGENTS.md: pure logic stays free of AVFoundation imports).
enum AudioMath {

    /// Sub-windows each display bar is split into before reducing it (ADR 0017). A
    /// snare/transient occupies only a few of these, so a percentile across them can
    /// step over it.
    static let transientSubFrames = 16
    /// Percentile taken across a bar's sub-windows to set its level. 0.5 (median)
    /// reads the *sustained* energy and steps over brief loud hits like a snare;
    /// lower rejects transients harder, 1.0 is the bar's peak (fully transient-led).
    static let transientReject = 0.5

    /// Reduce raw samples to `bars` normalised values (0...1) for drawing a waveform.
    /// Always returns exactly `bars` values (when input is non-empty).
    ///
    /// The envelope is **energy-based and transient-resistant** (ADR 0017). Peak
    /// per bar reads flat on brick-walled masters; a straight RMS reads better but
    /// *squares* loud brief events, so a rhythmic snare towers over the musical bed
    /// and the shape looks spiky/murky. Instead each bar is split into `subFrames`
    /// short sub-windows and reduced to the `reject`-percentile (median) of their
    /// RMS — the snare lands in only a few sub-windows, so the median reads the level
    /// the rest of the bar sits at. See `sectionEnergy`.
    ///
    /// Normalisation divides by the 95th percentile of the bar energies, not the
    /// single max, so one loud bar can't crush the rest; bars above it clamp to 1.
    static func downsample(_ samples: [Float], to bars: Int,
                           subFrames: Int = transientSubFrames,
                           reject: Double = transientReject) -> [Double] {
        guard bars > 0, !samples.isEmpty else { return [] }
        let energies = sectionEnergy(samples, to: bars, subFrames: subFrames, reject: reject)
        let reference = percentile(energies, 0.95)
        guard reference > 0 else { return energies }
        return energies.map { min(1, $0 / reference) }
    }

    /// Transient-resistant energy per display bar (un-normalised). Each bar is split
    /// into `subFrames` short sub-windows; the bar's value is the `reject`-percentile
    /// of those sub-windows' RMS. A snare hit lands in only a few sub-windows, so a
    /// median (`reject` = 0.5) reads the sustained level and steps over the hit —
    /// unlike a straight RMS over the whole bar, which squares the transient and lets
    /// it dominate. Composed from the tested `bucketRMS` + `percentile`.
    static func sectionEnergy(_ samples: [Float], to bars: Int,
                              subFrames: Int = transientSubFrames,
                              reject: Double = transientReject) -> [Double] {
        guard bars > 0, subFrames > 0, !samples.isEmpty else { return [] }
        let frames = bucketRMS(samples, to: bars * subFrames)
        return (0..<bars).map { bar in
            let lower = bar * subFrames
            let upper = lower + subFrames
            return percentile(Array(frames[lower..<upper]), reject)
        }
    }

    /// Per-bucket RMS energy (un-normalised) — `samples` split into `bars` even
    /// buckets, each reduced to `sqrt(mean(sample²))`. Pulled out of `downsample`
    /// so the energy reduction and the normalisation can be tested in isolation.
    static func bucketRMS(_ samples: [Float], to bars: Int) -> [Double] {
        guard bars > 0, !samples.isEmpty else { return [] }
        let count = samples.count
        var energies = [Double](repeating: 0, count: bars)
        for bar in 0..<bars {
            let start = bar * count / bars
            let end = max(start + 1, (bar + 1) * count / bars)
            var sumSquares = 0.0
            var sampleCount = 0
            var index = start
            while index < end && index < count {
                let value = Double(samples[index])
                sumSquares += value * value
                index += 1
                sampleCount += 1
            }
            energies[bar] = sampleCount > 0 ? (sumSquares / Double(sampleCount)).squareRoot() : 0
        }
        return energies
    }

    /// An **onset-strength envelope** for tempo estimation (ADR 0004, rung 2): a
    /// coarse per-frame energy curve reduced to the *increases* in energy, which is
    /// where note/drum onsets live. `samples` is split into `frames` even buckets
    /// (each ~1/100 s in practice); the value of frame `i` is the half-wave-rectified
    /// rise in RMS from `i-1`, `max(0, rms[i] - rms[i-1])`. Steady tone → ~0; a kick or
    /// strum → a spike. This is what `TempoEstimator` autocorrelates, so it must be
    /// fine enough to resolve a beat: at 100 frames/s a 200 BPM beat is still 30 frames
    /// apart. The first frame is 0 (no predecessor). Built on the tested `bucketRMS`.
    static func onsetEnvelope(_ samples: [Float], frames: Int) -> [Double] {
        guard frames > 0, !samples.isEmpty else { return [] }
        let rms = bucketRMS(samples, to: frames)
        var onsets = [Double](repeating: 0, count: rms.count)
        for index in 1..<rms.count {
            onsets[index] = max(0, rms[index] - rms[index - 1])
        }
        return onsets
    }

    /// Linearly-interpolated `quantile`-percentile (in 0...1) of `values`. Used to
    /// pick a robust normalisation reference that ignores a few loud outliers. Empty
    /// input returns 0; `quantile` is clamped to `0...1`.
    static func percentile(_ values: [Double], _ quantile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = Double(sorted.count - 1) * quantile.clamped(to: 0...1)
        let low = Int(rank.rounded(.down))
        let high = Int(rank.rounded(.up))
        guard low != high else { return sorted[low] }
        let frac = rank - Double(low)
        return sorted[low] * (1 - frac) + sorted[high] * frac
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

    /// Frame range covering a `0...1` slice of the file, for re-reading a zoomed
    /// window at full detail (crisp deep-zoom, ADR 0020). `startFraction`/
    /// `endFraction` are clamped to `0...1` and ordered; the result is always a
    /// valid, non-negative span inside `0..<totalFrames`. A degenerate window
    /// (zero/negative frames) returns a `frameCount` of 0 so callers can skip it.
    static func windowFrameRange(startFraction: Double, endFraction: Double,
                                 totalFrames: Int) -> (startFrame: Int, frameCount: Int) {
        guard totalFrames > 0 else { return (0, 0) }
        let lower = min(startFraction, endFraction).clamped(to: 0...1)
        let upper = max(startFraction, endFraction).clamped(to: 0...1)
        let startFrame = min(Int((lower * Double(totalFrames)).rounded()), totalFrames)
        let endFrame = min(Int((upper * Double(totalFrames)).rounded()), totalFrames)
        return (startFrame, max(0, endFrame - startFrame))
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
