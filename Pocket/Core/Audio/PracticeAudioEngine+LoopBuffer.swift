import AVFoundation

// The active loop's PCM buffer construction (ADR 0006 / 0008), split out of
// `PracticeAudioEngine.swift` for file length. Reading the region off disk and folding its seam into
// an equal-power crossfade is the engine's biggest self-contained chunk of work and touches nothing
// but the file, the region and the loop bookkeeping — so it is what moves, leaving the lifecycle,
// scheduling and playhead behind. The declaring file's `crossfadeSeconds` / `loopAnchorFrame` /
// `loopBufferFrames` / `file` / `sampleRate` lose their `private` to make this possible: Swift has no
// cross-file-private for one type, the same tax `PracticeAudioEngine+Metronome` already pays.
extension PracticeAudioEngine {

    /// Copy frames `[fromFrame, end)` of `buffer` into a fresh one — the partial first
    /// pass when seeking into an active loop. Same PCM format, so it queues seamlessly
    /// ahead of the full looping buffer.
    func makeSubBuffer(of buffer: AVAudioPCMBuffer, fromFrame: Int) -> AVAudioPCMBuffer? {
        let count = Int(buffer.frameLength) - fromFrame
        guard count > 0,
              let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
              let src = buffer.floatChannelData, let dst = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(count)
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<count { dst[channel][frame] = src[channel][fromFrame + frame] }
        }
        return out
    }

    /// Read the loop region into a buffer and crossfade its seam: fold the last
    /// `fade` frames into the first `fade` with equal-power gains, looping `R − fade`
    /// frames so the wrap is sample-continuous and click-free
    /// (`AudioMath.crossfadeGains`).
    func makeLoopBuffer() -> AVAudioPCMBuffer? {
        guard let file, let loop = currentLoopSegment() else { return nil }
        let format = file.processingFormat
        guard let region = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(loop.frameCount)) else { return nil }
        do {
            file.framePosition = AVAudioFramePosition(loop.startFrame)
            try file.read(into: region, frameCount: AVAudioFrameCount(loop.frameCount))
        } catch { return nil }

        let regionFrames = Int(region.frameLength)
        let fade = min(Int(crossfadeSeconds * sampleRate), regionFrames / 2)
        let loopFrames = regionFrames - fade
        guard loopFrames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(loopFrames)),
              let src = region.floatChannelData, let dst = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(loopFrames)

        for channel in 0..<Int(format.channelCount) {
            for frame in 0..<loopFrames { dst[channel][frame] = src[channel][frame] }  // body + head
            for frame in 0..<fade {                                  // crossfade head with the folded tail
                let gains = AudioMath.crossfadeGains(position: frame, length: fade)
                dst[channel][frame] = src[channel][frame] * gains.fadeIn
                                    + src[channel][loopFrames + frame] * gains.fadeOut
            }
        }

        loopAnchorFrame = loop.startFrame
        loopBufferFrames = loopFrames
        return out
    }
}
