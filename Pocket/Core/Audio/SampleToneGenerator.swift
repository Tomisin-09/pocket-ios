import AVFoundation

/// Generates a short looping arpeggio and writes it to a temp file, so the
/// practice engine has real audio to play before file import exists (chosen as
/// the dev audio source — asset-free, no licensing). Returns the file URL plus
/// the waveform amplitudes derived from the same buffer, so what you see matches
/// what you hear.
enum SampleToneGenerator {

    struct Sample {
        let url: URL
        let amplitudes: [Double]
    }

    static func makeSample(duration: TimeInterval, bars: Int = 120) throws -> Sample {
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let totalFrames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames),
              let channel = buffer.floatChannelData?[0] else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = totalFrames

        // A slow G-minor-ish arpeggio so pitch-preserved speed changes are clearly
        // audible. Phase resets each note (uses time-within-note) to avoid clicks.
        let scale: [Double] = [196.00, 233.08, 293.66, 349.23, 392.00] // G3 Bb3 D4 F4 G4
        let noteFrames = Int(sampleRate * 0.5)
        for frame in 0..<Int(totalFrames) {
            let freq = scale[(frame / noteFrames) % scale.count]
            let tInNote = Double(frame % noteFrames) / sampleRate
            let envelope = exp(-3.0 * tInNote)
            channel[frame] = Float(sin(2 * .pi * freq * tInNote) * envelope * 0.3)
        }

        let raw = Array(UnsafeBufferPointer(start: channel, count: Int(totalFrames)))
        let amplitudes = AudioMath.downsample(raw, to: bars).map { max(0.06, $0) }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pocket-sample-\(UUID().uuidString).caf")
        let outFile = try AVAudioFile(forWriting: url, settings: format.settings)
        try outFile.write(from: buffer)
        return Sample(url: url, amplitudes: amplitudes)
    }
}
