import AVFoundation

/// Loads a DRM-free local/iCloud audio file (per ADR 0001) and reduces it to the
/// `(duration, amplitudes)` a `Song` stores (ADR 0011, Slice 2). This is the thin
/// AVFoundation I/O boundary on top of pure, unit-tested math: the bucketing /
/// normalisation is `AudioMath.downsample`, the channel mix is `AudioMath.mixToMono`.
enum WaveformExtractor {

    enum ExtractError: Error { case emptyFile }

    /// Envelope buckets sampled across the whole song for the detail waveform.
    /// Bumped from 240 with ADR 0017 so the envelope reads finely — ~0.42 s per bar
    /// on a 3.5-min song — and holds up better when zoomed. This count also doubles
    /// as the stored-format version: a persisted waveform with a different count
    /// predates the current reduction and is re-extracted on next open (see
    /// `WaveformPracticeModel.refreshWaveformIfOutdated`), so it is bumped whenever
    /// the reduction changes (240 peak → 480 RMS → 512 transient-resistant). Crisp
    /// *deep* zoom still wants per-viewport re-downsampling — page-mode (ADR 0010).
    static let defaultBuckets = 512

    /// Decode `url` to mono PCM and reduce it to a stored waveform. Reads in
    /// frame-bounded chunks so a long file never pulls the whole buffer into memory
    /// at once (the device is RAM-constrained). Throws on an empty/unreadable file.
    static func extract(from url: URL, buckets: Int = defaultBuckets) throws
        -> (duration: TimeInterval, amplitudes: [Double]) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = file.length
        let duration = AudioMath.framesToSeconds(Int(totalFrames), sampleRate: format.sampleRate)
        guard totalFrames > 0 else { throw ExtractError.emptyFile }

        let channelCount = Int(format.channelCount)
        var mono = [Float]()
        mono.reserveCapacity(Int(totalFrames))

        let chunkCapacity: AVAudioFrameCount = 1 << 20  // ~1M frames per read
        while file.framePosition < totalFrames {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkCapacity) else { break }
            try file.read(into: buffer)
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channelData = buffer.floatChannelData else { break }
            let channels = (0..<channelCount).map { channel in
                Array(UnsafeBufferPointer(start: channelData[channel], count: frames))
            }
            mono.append(contentsOf: AudioMath.mixToMono(channels))
        }
        return (duration, AudioMath.downsample(mono, to: buckets))
    }

    /// Re-reduce just the `[startFraction, endFraction]` slice of `url` to `buckets`
    /// bars, for crisp deep-zoom (ADR 0020). At a deep zoom the stored whole-song
    /// envelope has only a handful of bars in the visible window; reading that
    /// window from the source and reducing it afresh restores full detail where the
    /// user is working. Returns `nil` for a degenerate (zero-frame) window so the
    /// caller can fall back to the stretched stored bars.
    ///
    /// Mirrors `extract`'s chunked read so a wide window on a long file never pulls
    /// the whole range into memory at once. The reduction is the same pure
    /// `AudioMath.downsample`; only the seek + bounded read are added here.
    static func extractWindow(from url: URL, startFraction: Double, endFraction: Double,
                              buckets: Int = defaultBuckets) throws -> [Double]? {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = Int(file.length)
        let range = AudioMath.windowFrameRange(startFraction: startFraction,
                                               endFraction: endFraction, totalFrames: totalFrames)
        guard range.frameCount > 0 else { return nil }

        file.framePosition = AVAudioFramePosition(range.startFrame)
        let channelCount = Int(format.channelCount)
        var mono = [Float]()
        mono.reserveCapacity(range.frameCount)

        let chunkCapacity: AVAudioFrameCount = 1 << 20  // ~1M frames per read
        var remaining = range.frameCount
        while remaining > 0 {
            let want = AVAudioFrameCount(min(Int(chunkCapacity), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: want) else { break }
            try file.read(into: buffer, frameCount: want)
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channelData = buffer.floatChannelData else { break }
            let channels = (0..<channelCount).map { channel in
                Array(UnsafeBufferPointer(start: channelData[channel], count: frames))
            }
            mono.append(contentsOf: AudioMath.mixToMono(channels))
            remaining -= frames
        }
        guard !mono.isEmpty else { return nil }
        return AudioMath.downsample(mono, to: buckets)
    }
}
