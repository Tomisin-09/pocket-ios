import AVFoundation

/// Rewrites a **practice take** down to a span of itself (ADR 0174) — the destructive half of
/// trimming, and the only thing in the app that overwrites a take's audio. `TakeTrim` decides
/// *what* span; this writes it.
///
/// **Destructive by decision, safe by construction.** A trim reclaims the disk a take was costing,
/// which a stored in/out span could never do, and the price is that it cannot be undone: a take has
/// no source to regenerate from. So the original is never opened for writing. The span is encoded
/// to a sibling temp file, the result is verified to hold real audio of about the right length, and
/// only then does it replace the original in one `replaceItemAt`. Every failure path — an
/// unreadable source, a refused encoder, a short write — leaves the take exactly as it was.
///
/// **`AVAudioFile`, not `AVAssetExportSession`.** The deployment target is iOS 17, where the export
/// session's async API does not exist and `exportAsynchronously` is deprecated in the next release —
/// an availability fork for no gain. `AVAudioFile` is synchronous, is already the idiom in
/// `TakeRecorder` and `WaveformExtractor`, and reading the encode settings off the *source* means a
/// trimmed take comes back in the same format it went in as.
enum TakeTrimmer {

    enum TrimError: Error {
        /// The take won't open, or holds no frames.
        case unreadable
        /// The requested span lands outside the audio, or covers no frames.
        case emptySpan
        /// The encoder refused, or the written file holds nothing.
        case writeFailed
        /// The written file's length doesn't match what was asked for — the original is left alone.
        case lengthMismatch
    }

    /// Frames per read, matching `WaveformExtractor` — a long take is copied in bounded chunks so
    /// trimming never pulls the whole file into memory on a RAM-constrained device.
    private static let chunkCapacity: AVAudioFrameCount = 1 << 20

    /// How far the written length may fall from the requested span before the trim is rejected. An
    /// AAC encoder pads and aligns to its own frame size, so an exact match is not on offer; a
    /// quarter-second is far tighter than any real encoder drift and far looser than the kind of
    /// mismatch that means the write went wrong.
    private static let lengthTolerance: TimeInterval = 0.25

    /// Trim the take at `fileName` down to `start…end` (seconds), replacing the file in place, and
    /// return the new duration.
    ///
    /// Blocking file I/O and encoding — `nonisolated`, and callers must run it off the main actor.
    /// On any throw the take is untouched and still playable.
    nonisolated static func trim(fileName: String, from start: TimeInterval,
                                 to end: TimeInterval) throws -> TimeInterval {
        let url = try RecordingStore.url(for: fileName)
        let source = try AVAudioFile(forReading: url)
        let format = source.processingFormat
        guard format.sampleRate > 0, source.length > 0 else { throw TrimError.unreadable }

        let range = frameRange(start: start, end: end,
                               totalFrames: Int(source.length), sampleRate: format.sampleRate)
        guard range.frameCount > 0 else { throw TrimError.emptySpan }

        // A sibling temp file: `replaceItemAt` wants the same volume, and the same directory is the
        // simplest way to guarantee it. It keeps the `.m4a` suffix on purpose — a temp stranded by a
        // crash is then an unreferenced take file, which is exactly what `RecordingStore`'s orphan
        // sweep exists to reap.
        let tempURL = url.deletingPathExtension()
            .appendingPathExtension("trimtmp")
            .appendingPathExtension("m4a")
        try? FileManager.default.removeItem(at: tempURL)

        do {
            try write(source: source, range: range, format: format, to: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            AudioPlumbing.log.error("TakeTrimmer: write failed for \(fileName): \(error.localizedDescription)")
            throw error
        }

        // Verify before replacing anything. This is the whole safety story: past this line the
        // original bytes are gone, so nothing gets past it that hasn't been read back off disk.
        guard let written = duration(of: tempURL), written > 0 else {
            try? FileManager.default.removeItem(at: tempURL)
            AudioPlumbing.log.error("TakeTrimmer: trimmed file for \(fileName) holds no audio")
            throw TrimError.writeFailed
        }
        let requested = end - start
        guard abs(written - requested) <= lengthTolerance else {
            try? FileManager.default.removeItem(at: tempURL)
            AudioPlumbing.log.error(
                """
                TakeTrimmer: trimmed \(fileName) to \(written, format: .fixed(precision: 2))s, \
                asked for \(requested, format: .fixed(precision: 2))s
                """)
            throw TrimError.lengthMismatch
        }

        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        return written
    }

    /// The frame range a `start…end` span covers in a file of `totalFrames`, clamped into the file.
    /// Pure — split out so the off-by-one that would clip a take's last moment is unit-testable.
    static func frameRange(start: TimeInterval, end: TimeInterval, totalFrames: Int,
                           sampleRate: Double) -> (start: Int, frameCount: Int) {
        guard totalFrames > 0, sampleRate > 0 else { return (0, 0) }
        let first = min(max(AudioMath.secondsToFrames(start, sampleRate: sampleRate), 0), totalFrames)
        let last = min(max(AudioMath.secondsToFrames(end, sampleRate: sampleRate), 0), totalFrames)
        return (first, max(0, last - first))
    }

    /// Copy `range` out of `source` into a freshly encoded file at `destination`.
    ///
    /// The encode settings take their **format** from `TakeRecorder.settings` (AAC, high quality —
    /// what every take in the container already is) but their sample rate and channel count from the
    /// source file. That keeps the writer's `processingFormat` identical to the reader's, so buffers
    /// pass straight across with no converter in between — and a take recorded under different
    /// settings, or restored from an older install, still trims correctly instead of being resampled
    /// into something the rest of the app doesn't expect.
    private static func write(source: AVAudioFile, range: (start: Int, frameCount: Int),
                              format: AVAudioFormat, to destination: URL) throws {
        var settings = TakeRecorder.settings
        settings[AVSampleRateKey] = format.sampleRate
        settings[AVNumberOfChannelsKey] = Int(format.channelCount)
        let output = try AVAudioFile(forWriting: destination, settings: settings)

        source.framePosition = AVAudioFramePosition(range.start)
        var remaining = range.frameCount
        while remaining > 0 {
            let want = AVAudioFrameCount(min(Int(chunkCapacity), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: want) else {
                throw TrimError.writeFailed
            }
            try source.read(into: buffer, frameCount: want)
            let frames = Int(buffer.frameLength)
            // A read that returns nothing before the span is done means the file is shorter than its
            // header claims. Stop rather than spin: what has been written is still verified below.
            guard frames > 0 else { break }
            try output.write(from: buffer)
            remaining -= frames
        }
    }

    /// Length of a written file, read from its header, or `nil` if it won't open.
    ///
    /// Deliberately **not** `TakeRecorder.writtenDuration(of:)`, which logs an error on every call —
    /// it exists for a recorder that was stopped behind our back, where a duration read is always a
    /// symptom. Here it is the ordinary verification step, and borrowing it would report a fault on
    /// every successful trim.
    private static func duration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url),
              file.processingFormat.sampleRate > 0, file.length > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
