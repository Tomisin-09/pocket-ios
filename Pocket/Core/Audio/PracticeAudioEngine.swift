import AVFoundation
import Observation

/// Minimal practice playback engine: AVAudioEngine → player → time-pitch
/// (pitch-preserving speed) → mixer. AVFoundation lives here in Core/Audio; the
/// pure math stays in `AudioMath`. See docs/architecture.md, ADRs 0001, 0006 & 0008.
///
/// play / pause / seek / rate, plus continuous **seamless region looping**: an
/// active loop plays a pre-rendered, crossfaded buffer on `.loops`, so the wrap is
/// gapless *and* click-free. Publishes `currentTime`.
@MainActor
@Observable
final class PracticeAudioEngine {

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// How many times the active loop has wrapped since its buffer started (0-based) —
    /// drives the per-loop automator's speed ramp (ADR 0013). Resets when the loop
    /// (re)starts; stays 0 when not looping.
    private(set) var loopIteration = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    /// Metronome (ADR 0026): a click voice on this same engine — so it shares the
    /// player's render clock and stays sample-locked to the (possibly time-stretched)
    /// song. `metronomeBeats` is the song's grid in *source* seconds; the click follows
    /// playback rate via `MetronomeSchedule`. `clickWatermark` is the source time of the
    /// last beat already queued, so each beat is scheduled exactly once across the
    /// 0.03 s refresh ticks; it resets on any discontinuity (seek / rate / loop wrap).
    private(set) var metronomeOn = false
    private let clickVoice = ClickVoice()
    private var metronomeBeats: [(time: TimeInterval, isDownbeat: Bool)] = []
    private var clickWatermark: TimeInterval = -.infinity
    private var metronomeLoopIteration = 0
    /// How far ahead (real seconds) clicks are scheduled; refreshed each timer tick.
    private let metronomeHorizon: TimeInterval = 1.0

    private var file: AVAudioFile?
    private var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var scheduled = false
    /// Invalidates the in-flight straight-through segment's completion across
    /// stop/seek/loop changes so a stale "reached end" can't reset state.
    private var generation = 0
    private var displayTimer: Timer?

    /// When set, playback loops this region (seconds) via a crossfaded `.loops`
    /// buffer. `nil` plays straight through.
    private var loopRegion: (start: TimeInterval, end: TimeInterval)?
    /// Loop-buffer bookkeeping for the playhead: the region's start frame, the
    /// looped length (region minus crossfade), and the player sampleTime at which
    /// the current loop buffer began (so elapsed-in-loop = now − base).
    private var loopAnchorFrame = 0
    private var loopBufferFrames = 0
    private var loopBaseSampleTime: AVAudioFramePosition = 0
    /// Equal-power crossfade length folded into the loop seam.
    private let crossfadeSeconds: TimeInterval = 0.015

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        clickVoice.attach(to: engine)
    }

    /// Open `url` and wire it into the graph. The header read happens off the main
    /// actor — `AVAudioFile(forReading:)` can block on I/O for large or
    /// not-yet-downloaded iCloud files — so the UI stays responsive (and a loading
    /// state can render) while it opens; the graph wiring runs back on the main actor.
    func load(url: URL) async throws {
        let audioFile = try await Self.openFile(at: url).value
        file = audioFile
        let format = audioFile.processingFormat
        sampleRate = format.sampleRate
        totalFrames = audioFile.length
        duration = AudioMath.framesToSeconds(Int(totalFrames), sampleRate: sampleRate)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        configureSession()
    }

    /// Open an `AVAudioFile` off the main actor. The file is non-`Sendable`, but it's
    /// constructed here and only ever touched on the main actor afterwards, so it's
    /// safe to hand back across the boundary in an unchecked box.
    private static func openFile(at url: URL) async throws -> UncheckedSendableBox<AVAudioFile> {
        try await Task.detached(priority: .userInitiated) {
            UncheckedSendableBox(try AVAudioFile(forReading: url))
        }.value
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard file != nil else { return }
        startEngineIfNeeded()
        if !scheduled { primeSchedule() }
        player.play()
        isPlaying = true
        armMetronome()
        startTimer()
    }

    func pause() {
        player.pause()
        isPlaying = false
        clickVoice.stopAll()
        stopTimer()
    }

    /// Tear down for screen exit (ADR 0025): halt playback, stop the engine, and
    /// release the shared audio session so nothing keeps rendering — or holding
    /// the session active — after the practice view is dismissed. The owning model
    /// is recreated per visit, so the next entry reconfigures from scratch.
    func stop() {
        pause()
        clickVoice.stopAll()
        player.stop()
        engine.stop()
        scheduled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Move the play position; resumes from `seconds` if it was playing. (When a
    /// loop is active the buffer restarts at the loop start regardless.)
    func seek(toSeconds seconds: TimeInterval) {
        let clamped = min(max(0, seconds), duration)
        seekFrame = AVAudioFramePosition(AudioMath.secondsToFrames(clamped, sampleRate: sampleRate))
        let wasPlaying = isPlaying
        generation += 1
        player.stop()
        flushMetronome()
        scheduled = false
        loopIteration = 0
        currentTime = clamped
        if wasPlaying { play() }
    }

    /// Pitch-preserving playback speed (0.25×–2.0×). Queued clicks were timed at the old
    /// rate, so flush and let the next tick refill at the new one.
    func setRate(_ rate: Double) {
        timePitch.rate = Float(min(2.0, max(0.25, rate)))
        flushMetronome()
    }

    /// Loop a region (seconds). When playing, the crossfaded loop buffer is rebuilt
    /// and swapped in immediately (`.interrupts`) so the change is heard at once
    /// with no overlap; when paused it takes effect on the next `play`.
    func setLoop(start: TimeInterval, end: TimeInterval) {
        loopRegion = (start: start, end: end)
        flushMetronome()
        guard isPlaying else { return }
        generation += 1                 // kill any pending straight-through completion
        if scheduleLoopBuffer() { scheduled = true }
    }

    /// Stop looping; if playing, resume straight through from the current position.
    func clearLoop() {
        loopRegion = nil
        loopBufferFrames = 0
        loopIteration = 0
        flushMetronome()
        if isPlaying { seek(toSeconds: currentTime) }
    }

    // MARK: - Private

    /// The active loop as concrete frames, or `nil` when not looping (or the
    /// region is degenerate). Pure math in `AudioMath.loopSegment`.
    private func currentLoopSegment() -> (startFrame: Int, frameCount: Int)? {
        guard let loopRegion else { return nil }
        let seg = AudioMath.loopSegment(start: loopRegion.start, end: loopRegion.end,
                                        sampleRate: sampleRate, totalFrames: Int(totalFrames))
        return seg.frameCount > 0 ? seg : nil
    }

    /// Schedule the active loop's crossfaded buffer, or the straight-through
    /// segment to the file end when not looping.
    private func primeSchedule() {
        if currentLoopSegment() != nil {
            _ = scheduleLoopBuffer()
        } else if let file {
            scheduleSegment(file, fromFrame: Int(seekFrame), toFrame: Int(totalFrames))
        }
        scheduled = true
    }

    /// Build the crossfaded loop buffer and schedule it on `.loops` (`.interrupts`
    /// so it cleanly replaces any currently-playing buffer). Records the playhead
    /// anchor. Returns `false` if the buffer couldn't be built.
    @discardableResult
    private func scheduleLoopBuffer() -> Bool {
        guard let buffer = makeLoopBuffer() else { return false }
        loopBaseSampleTime = isPlaying ? currentSampleTime() : 0
        loopIteration = 0
        player.scheduleBuffer(buffer, at: nil, options: [.loops, .interrupts], completionHandler: nil)
        return true
    }

    /// Read the loop region into a buffer and crossfade its seam: fold the last
    /// `fade` frames into the first `fade` with equal-power gains, looping `R − fade`
    /// frames so the wrap is sample-continuous and click-free
    /// (`AudioMath.crossfadeGains`).
    private func makeLoopBuffer() -> AVAudioPCMBuffer? {
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

    /// Schedule a straight-through segment `[fromFrame, toFrame)` that stops at the
    /// file end (`.dataPlayedBack`, after the tail has played out).
    private func scheduleSegment(_ file: AVAudioFile, fromFrame: Int, toFrame: Int) {
        let count = toFrame - fromFrame
        guard count > 0 else { return }
        let token = generation
        player.scheduleSegment(file, startingFrame: AVAudioFramePosition(fromFrame),
                               frameCount: AVAudioFrameCount(count), at: nil,
                               completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.handleReachedEnd(token: token) }
        }
    }

    /// The straight-through segment finished — stop and reset to the top.
    private func handleReachedEnd(token: Int) {
        guard token == generation else { return }   // a newer schedule superseded this one
        player.stop()
        scheduled = false
        isPlaying = false
        seekFrame = 0
        currentTime = 0
        generation += 1
        stopTimer()
    }

    /// The player's current render position (source frames since it started).
    private func currentSampleTime() -> AVAudioFramePosition {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return 0 }
        return playerTime.sampleTime
    }

    private func updateCurrentTime() {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        if loopBufferFrames > 0, currentLoopSegment() != nil {
            // The loop buffer runs continuously; map elapsed-since-its-start back
            // into the region. Length is region − crossfade, so the playhead wraps
            // in lockstep with the audio.
            let elapsedFrames = max(0, Double(playerTime.sampleTime - loopBaseSampleTime))
            // Wrap count is in *source* frames (the buffer's own length), so it's stable
            // even as the automator changes playback rate mid-loop.
            let iteration = Int(elapsedFrames / Double(loopBufferFrames))
            if iteration != loopIteration { loopIteration = iteration }
            let elapsed = elapsedFrames / playerTime.sampleRate
            currentTime = AudioMath.loopedPlayhead(elapsed: elapsed,
                                                   loopStart: Double(loopAnchorFrame) / sampleRate,
                                                   loopLength: Double(loopBufferFrames) / sampleRate)
        } else {
            let played = max(0, Double(playerTime.sampleTime) / playerTime.sampleRate)
            currentTime = min(duration, Double(seekFrame) / sampleRate + played)
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }

    private func startTimer() {
        stopTimer()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
                self?.refreshMetronome()
            }
        }
    }

    private func stopTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
}

// MARK: - Metronome (ADR 0026)

extension PracticeAudioEngine {

    /// Turn the in-song click on/off. The song's beat grid is supplied separately via
    /// `setMetronomeBeats`; with no grid (tempo/downbeat unset) nothing schedules.
    func setMetronome(enabled: Bool) {
        metronomeOn = enabled
        if enabled {
            armMetronome()
        } else {
            clickVoice.stopAll()
        }
    }

    /// Update the song's beat grid (source seconds + downbeat flags), e.g. when the BPM
    /// or downbeat changes. Drops any stale schedule.
    func setMetronomeBeats(_ beats: [(time: TimeInterval, isDownbeat: Bool)]) {
        metronomeBeats = beats
        flushMetronome()
    }

    /// Begin (or resume) the click voice for the current playback and reset the dedup
    /// watermark so the next tick refills from the live playhead.
    func armMetronome() {
        guard metronomeOn, isPlaying else { return }
        clickVoice.start()
        clickWatermark = -.infinity
        metronomeLoopIteration = loopIteration
    }

    /// Cancel queued clicks and reset the watermark; re-arm if still playing. Called on
    /// any timing discontinuity (seek / rate / loop change / grid change) so a click is
    /// never heard at a stale time.
    func flushMetronome() {
        clickVoice.stopAll()
        clickWatermark = -.infinity
        if metronomeOn, isPlaying {
            clickVoice.start()
            metronomeLoopIteration = loopIteration
        }
    }

    /// Schedule the clicks now due within the lookahead horizon (one per beat, deduped
    /// by the watermark). Follows the playback rate, so the click tracks a slowed or
    /// sped track. During an active loop, a new pass resets the watermark so the
    /// region's beats re-fire, and beats past the loop end are skipped (playback wraps
    /// before reaching them).
    func refreshMetronome() {
        guard metronomeOn, isPlaying, !metronomeBeats.isEmpty else { return }
        if loopIteration != metronomeLoopIteration {
            metronomeLoopIteration = loopIteration
            clickWatermark = -.infinity            // new loop pass ⇒ re-fire the region
        }
        let cutoff = loopRegion?.end ?? .infinity
        let clicks = MetronomeSchedule.upcoming(beats: metronomeBeats,
                                                currentSourceTime: currentTime,
                                                rate: Double(timePitch.rate),
                                                horizon: metronomeHorizon)
        for click in clicks where click.time > clickWatermark && click.time < cutoff {
            clickVoice.schedule(delay: click.delay, accented: click.isDownbeat)
            clickWatermark = click.time
        }
    }
}

/// Carries a non-`Sendable` value across an actor boundary when the caller
/// guarantees single-threaded use (here: open off-main, then main-actor only).
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
