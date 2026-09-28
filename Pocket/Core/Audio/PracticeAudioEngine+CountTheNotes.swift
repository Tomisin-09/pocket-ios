import AVFoundation

// Count the notes' two engine seams (ADR 0225), split out because `PracticeAudioEngine.swift` sits on
// SwiftLint's 400-line cap. `player`, `loopBaseSampleTime`, `currentSampleTime()`, `heard(_:)` and
// `startEngineIfNeeded()` lose their `private` for it: Swift has no cross-file-private for one type, the
// tax `+LoopBuffer` and `+Metronome` already pay.
extension PracticeAudioEngine {

    // MARK: - The loop's clock, read at a tap

    /// The loop's clock **right now**, or `nil` when no region is looping. Computed from the player's
    /// last render time on demand rather than read from `currentTime`, which only moves once per display
    /// frame: a tap between two frames would otherwise land up to a frame late.
    ///
    /// `elapsed` stays unwrapped, so `TapTally` can tell which pass a tap belongs to, instead of trusting
    /// `loopIteration`. That counts *rendered* wraps (ADR 0140 §3), and the render position runs a whole
    /// output latency ahead of the ear, so near a wrap it has already moved on to a pass the player
    /// hasn't heard yet.
    ///
    /// Read in actions and in the one leaf that draws the live playhead, never in a body (ADR 0153).
    func loopClock() -> LoopClockReading? {
        guard isPlaying, loopBufferFrames > 0, currentLoopSegment() != nil, sampleRate > 0 else { return nil }
        let elapsedFrames = max(0, Double(currentSampleTime() - loopBaseSampleTime))
        return LoopClockReading(elapsed: heard(elapsedFrames / sampleRate),
                                regionStart: Double(loopAnchorFrame) / sampleRate,
                                passLength: Double(loopBufferFrames) / sampleRate,
                                rate: stretcher.rate,
                                outputLatency: routeLatency)
    }

    /// Wall-clock seconds from a rendered buffer to the ear: the route's latency plus one IO buffer.
    private var routeLatency: TimeInterval {
        let session = AVAudioSession.sharedInstance()
        return session.outputLatency + session.ioBufferDuration
    }

    /// The clock of the slice playing now, which starts at `start` in the song and plays `length` of it
    /// (ADR 0227 D2: the strip rings a phrase's notes). `nil` while the loop plays or nothing does. A
    /// slice stops the player before it starts, which sets the player's sample time back to zero, so
    /// the samples played so far are the slice's own.
    func sliceClock(start: TimeInterval, length: TimeInterval) -> SliceClockReading? {
        guard !isPlaying, player.isPlaying, sampleRate > 0 else { return nil }
        return SliceClockReading(elapsed: heard(Double(max(0, currentSampleTime())) / sampleRate),
                                 start: start, length: length, rate: stretcher.rate,
                                 outputLatency: routeLatency)
    }

    // MARK: - A slice of the song

    /// Play `[start, start + length)` of the song **once** at `rate`, through the same stretcher the loop
    /// uses, for Name the notes. Refuses while the loop itself is playing: the sheet stops the loop
    /// before it opens (ADR 0225), and a slice must never land on top of it.
    ///
    /// The buffer carries its own fades (`AudioSlice.gain`), so it starts and ends at silence whatever
    /// the render cycle does. A new slice stops the old one first; `onFinished` still fires for the old
    /// one, so the caller keeps a token to tell them apart.
    @discardableResult
    func playSlice(from start: TimeInterval, length: TimeInterval, rate: Double,
                   onFinished: @escaping @MainActor @Sendable () -> Void) -> Bool {
        guard !isPlaying, let buffer = makeSliceBuffer(from: start, length: length) else { return false }
        startEngineIfNeeded()
        setRate(rate)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [],
                              completionCallbackType: .dataPlayedBack) { @Sendable _ in
            Task { @MainActor in onFinished() }
        }
        player.play()
        return true
    }

    /// Silence a slice mid-flight. A no-op while the loop is playing, so it can never stop the loop.
    func stopSlice() {
        guard !isPlaying else { return }
        player.stop()
    }

    /// The slice as a PCM buffer with its envelope applied, plus enough silence after it for the
    /// stretcher's own latency to play the tail out rather than holding it until the next sound.
    private func makeSliceBuffer(from start: TimeInterval, length: TimeInterval) -> AVAudioPCMBuffer? {
        guard let file, sampleRate > 0, length > 0 else { return nil }
        let format = file.processingFormat
        let startFrame = AVAudioFramePosition(AudioMath.secondsToFrames(max(0, start), sampleRate: sampleRate))
        let wanted = AudioMath.secondsToFrames(length, sampleRate: sampleRate)
        let available = Int(file.length - startFrame)
        let frames = min(wanted, available)
        let tail = AudioMath.secondsToFrames(max(0.12, stretcher.latency), sampleRate: sampleRate)
        guard frames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames + tail))
        else { return nil }
        do {
            file.framePosition = startFrame
            try file.read(into: out, frameCount: AVAudioFrameCount(frames))
        } catch { return nil }
        let read = Int(out.frameLength)
        guard read > 0, let channels = out.floatChannelData else { return nil }
        let fadeIn = AudioMath.secondsToFrames(AudioSlice.fadeIn, sampleRate: sampleRate)
        let fadeOut = AudioMath.secondsToFrames(AudioSlice.fadeOut, sampleRate: sampleRate)
        for channel in 0..<Int(format.channelCount) {
            for frame in 0..<read {
                channels[channel][frame] *= AudioSlice.gain(frame: frame, frameCount: read,
                                                            fadeInFrames: fadeIn, fadeOutFrames: fadeOut)
            }
            for frame in read..<(read + tail) { channels[channel][frame] = 0 }
        }
        out.frameLength = AVAudioFrameCount(read + tail)
        return out
    }
}
