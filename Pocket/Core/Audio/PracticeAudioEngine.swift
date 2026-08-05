import AVFoundation
import Observation

/// Minimal practice playback engine: AVAudioEngine → player → time-pitch (pitch-preserving speed) →
/// mixer. AVFoundation lives here in Core/Audio; the pure math stays in `AudioMath` (docs/architecture,
/// ADRs 0001, 0006 & 0008). play / pause / seek / rate, plus continuous **seamless region looping** —
/// an active loop plays a pre-rendered, crossfaded buffer on `.loops`, so the wrap is gapless and
/// click-free. Publishes `currentTime`.
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

    /// Fired once when straight-through playback reaches the file's natural end — never on a manual
    /// stop/seek, never while looping. The song-block play-along (ADR 0071) hangs auto-advance off it.
    var onReachedEnd: (() -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// Owns the time-stretching unit, its rate and its latency (ADR 0140). Read by the metronome
    /// split for the rate; engine-internal otherwise.
    let stretcher = TimeStretcher()

    /// Metronome (ADR 0026): a click voice on this same engine, sample-locked to the (possibly
    /// time-stretched) song. `metronomeBeats` is the grid in *source* seconds; the click follows
    /// playback rate via `MetronomeSchedule`. `clickWatermark` is the source time of the last beat
    /// queued, so each beat schedules once across the 0.03 s ticks; it resets on any discontinuity
    /// (seek / rate / loop wrap). Engine-internal but driven by the `+Metronome` split.
    private(set) var metronomeOn = false
    let clickVoice = ClickVoice()
    var metronomeBeats: [(time: TimeInterval, isDownbeat: Bool)] = []
    var clickWatermark: TimeInterval = -.infinity
    var metronomeLoopIteration = 0
    /// How far ahead (real seconds) clicks are scheduled; refreshed each timer tick.
    let metronomeHorizon: TimeInterval = 1.0

    /// Internal (not `private`) so the `+LoopBuffer` split can read the region — see that file.
    var file: AVAudioFile?
    var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var scheduled = false
    /// This instance's claim on the shared audio session — paired across repeated `load`/`stop` calls.
    private var sessionClaim = AudioSessionClaim()
    /// Invalidates the in-flight straight-through segment's completion across
    /// stop/seek/loop changes so a stale "reached end" can't reset state.
    private var generation = 0
    /// Advances the playhead once per display frame (ADR 0054) — vsync-aligned, so
    /// it glides instead of stepping at the metronome timer's sub-refresh cadence.
    private var playheadTicker: DisplayLinkTicker?
    /// Metronome click-scheduling refresh. Kept on a plain `Timer` (audio scheduling
    /// doesn't need display rate; its horizon covers this interval).
    private var metronomeTimer: Timer?

    /// When set, playback loops this region (seconds) via a crossfaded `.loops` buffer; `nil` plays
    /// straight through. (Read by the +Metronome split for its cutoff.)
    var loopRegion: (start: TimeInterval, end: TimeInterval)?
    /// Loop-buffer bookkeeping for the playhead: the region's start frame, the looped length (region
    /// minus crossfade), and the player sampleTime at which the current loop buffer began.
    var loopAnchorFrame = 0
    var loopBufferFrames = 0
    private var loopBaseSampleTime: AVAudioFramePosition = 0
    /// Equal-power crossfade length folded into the loop seam.
    let crossfadeSeconds: TimeInterval = 0.015

    init() {
        engine.attach(player)
        engine.attach(stretcher.node)
        clickVoice.attach(to: engine)
        // Headroom for song + click (ADR 0140 §5). Both land on this mixer, and it's their *sum* that
        // clips — so the trim goes on the sum, which also leaves the voiced song-to-click balance
        // untouched. Set once: it must not move under the player mid-session.
        engine.mainMixerNode.outputVolume = AudioMath.headroomTrim(
            peakClick: ClickTimbre.loudestPeakAmplitude)
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
        engine.connect(player, to: stretcher.node, format: format)
        engine.connect(stretcher.node, to: engine.mainMixerNode, format: format)
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
        sessionClaim.give(label: "practice")
    }

    /// Move the play position; resumes from `seconds` if it was playing. A seek inside
    /// an active loop resumes from that point within the region (not the loop start),
    /// so you can reposition the playhead mid-loop — ADR 0041.
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
    /// rate, so flush and let the next tick refill at the new one. The stretcher clamps the
    /// rate and picks the smoothness that goes with it (ADR 0140).
    func setRate(_ rate: Double) {
        stretcher.setRate(rate)
        flushMetronome()
    }

    /// Loop a region (seconds). When playing, the crossfaded loop buffer is rebuilt
    /// and swapped in immediately (`.interrupts`) so the change is heard at once
    /// with no overlap; when paused it takes effect on the next `play`.
    /// When `keepingPlayhead` is true and the live playhead still falls inside the new region,
    /// playback continues from there (plays out to the new end, then loops) instead of restarting
    /// from the start (ADR 0067) — a loop-edge resize shouldn't yank the audition to the top.
    func setLoop(start: TimeInterval, end: TimeInterval, keepingPlayhead: Bool = false) {
        loopRegion = (start: start, end: end)
        flushMetronome()
        guard isPlaying else { return }
        if keepingPlayhead, AudioMath.playheadInsideLoop(currentTime, start: start, end: end) {
            seek(toSeconds: currentTime)    // resume within the new region from here (no restart)
            return
        }
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
    func currentLoopSegment() -> (startFrame: Int, frameCount: Int)? {
        guard let loopRegion else { return nil }
        let seg = AudioMath.loopSegment(start: loopRegion.start, end: loopRegion.end,
                                        sampleRate: sampleRate, totalFrames: Int(totalFrames))
        return seg.frameCount > 0 ? seg : nil
    }

    /// Schedule the active loop's crossfaded buffer, or the straight-through
    /// segment to the file end when not looping.
    private func primeSchedule() {
        if currentLoopSegment() != nil {
            scheduleLoopBuffer(offsetFrames: loopOffsetFrames(forSeekFrame: Int(seekFrame)))
        } else if let file {
            scheduleSegment(file, fromFrame: Int(seekFrame), toFrame: Int(totalFrames))
        }
        scheduled = true
    }

    /// How far into the active loop a seek lands, in source frames (clamped at 0 below
    /// the loop start). Lets a tap inside a playing loop resume from there instead of
    /// snapping back to the loop start (ADR 0041).
    private func loopOffsetFrames(forSeekFrame frame: Int) -> Int {
        guard let loopRegion else { return 0 }
        return max(0, frame - AudioMath.secondsToFrames(loopRegion.start, sampleRate: sampleRate))
    }

    /// Build the crossfaded loop buffer and schedule it on `.loops` (`.interrupts`
    /// so it cleanly replaces any currently-playing buffer). Records the playhead
    /// anchor. `offsetFrames` starts playback partway through the region (a seek
    /// *into* an active loop, ADR 0041) by playing the buffer's tail
    /// `[offset, end)` once, then looping the whole region — seamless because the
    /// tail's last frame meets the buffer's frame 0 at the already-crossfaded seam.
    /// Returns `false` if the buffer couldn't be built.
    @discardableResult
    private func scheduleLoopBuffer(offsetFrames: Int = 0) -> Bool {
        guard let buffer = makeLoopBuffer() else { return false }   // sets loopAnchorFrame / loopBufferFrames
        let offset = max(0, min(offsetFrames, loopBufferFrames - 1))
        // Rewind the base by the offset so elapsed-in-loop starts at `offset`, not 0,
        // and the playhead maths land on the tapped point rather than the loop start.
        loopBaseSampleTime = (isPlaying ? currentSampleTime() : 0) - AVAudioFramePosition(offset)
        loopIteration = 0
        if offset > 0, let tail = makeSubBuffer(of: buffer, fromFrame: offset) {
            player.scheduleBuffer(tail, at: nil, options: [.interrupts], completionHandler: nil)  // offset→seam once
            player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)     // then loop region
        } else {
            player.scheduleBuffer(buffer, at: nil, options: [.loops, .interrupts], completionHandler: nil)
        }
        return true
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
        // Natural end of the file (not a manual stop/seek) — let an observing play-along advance.
        onReachedEnd?()
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
            // even as the automator changes playback rate mid-loop. Deliberately counted from
            // the *rendered* position, not the heard one: the iteration drives the per-loop ramp
            // (ADR 0013), and pulling it back across a wrap boundary would re-fire a pass and
            // step the ramp on every lap (ADR 0140 §3).
            let iteration = Int(elapsedFrames / Double(loopBufferFrames))
            if iteration != loopIteration { loopIteration = iteration }
            let elapsed = heard(elapsedFrames / playerTime.sampleRate)
            currentTime = AudioMath.loopedPlayhead(elapsed: elapsed,
                                                   loopStart: Double(loopAnchorFrame) / sampleRate,
                                                   loopLength: Double(loopBufferFrames) / sampleRate)
        } else {
            let played = heard(Double(playerTime.sampleTime) / playerTime.sampleRate)
            currentTime = min(duration, Double(seekFrame) / sampleRate + played)
        }
    }

    /// Pull a rendered position back to what the ear is hearing, through the stretcher's
    /// rate-dependent latency (ADR 0140 §3). `currentTime` is published in *heard* time, which is why
    /// the metronome needs no offset of its own: `MetronomeSchedule` measures each beat from this
    /// value, so the click and the visual playhead are corrected by the same single subtraction.
    private func heard(_ rendered: TimeInterval) -> TimeInterval {
        guard compensatesStretcherLatency else { return max(0, rendered) }
        return AudioMath.heardPlayhead(rendered: rendered, latency: stretcher.latency,
                                       rate: stretcher.rate)
    }

    /// Release always compensates — ADR 0140 closes off exposing the stretcher to the player. The
    /// DEBUG toggle exists only to A/B the correction by ear against the uncorrected build, which is
    /// a far easier judgment than deciding in the absolute whether a click is 93 ms early. Read live
    /// rather than cached so flipping it in Settings takes effect on the next frame.
    private var compensatesStretcherLatency: Bool {
        #if DEBUG
        return AppSettings.compensateStretchLatency
        #else
        return true
        #endif
    }

    private func startEngineIfNeeded() {
        AudioPlumbing.startIfNeeded(engine, label: "practice")
        // Starting the engine initialises the stretcher's audio unit, and `'tmpt'`'s rate is a raw
        // parameter write rather than a retained Swift property (ADR 0140 §4). One write here and the
        // question of whether it survived initialisation doesn't arise.
        stretcher.reassertRate()
    }

    private func configureSession() {
        // The claim is taken **first**, exactly as the metronome does: it holds whatever the category
        // is, and an engine that takes the guarded early return below is still a producer that needs
        // the session live. (So `stop()` can't deactivate a session another producer is using.)
        sessionClaim.take()
        // Guarded, so loading audio can't downgrade a `.playAndRecord` session and kill an in-flight
        // take. This engine was thought to be exempt because it "configures once at load" — true on
        // the loop trainer, which preloads in `.task`, but false on improvise, where the first play
        // tap loads *after* the take was armed (device pass 2026-08-05).
        AudioPlumbing.ensurePlaybackSession(label: "practice")
    }

    private func startTimer() {
        stopTimer()
        // Playhead: one update per display frame (assumeIsolated is safe — the link
        // runs on the main run loop, i.e. the main thread / main actor).
        if playheadTicker == nil {
            playheadTicker = DisplayLinkTicker { [weak self] in
                MainActor.assumeIsolated { self?.updateCurrentTime() }
            }
        }
        playheadTicker?.start()
        // Metronome: unchanged 0.03 s cadence, now decoupled from the playhead.
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshMetronome() }
        }
    }

    private func stopTimer() {
        playheadTicker?.stop()
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }
}

// MARK: - Metronome (ADR 0026)

extension PracticeAudioEngine {
    /// Turn the in-song click on/off. Writes the `private(set) metronomeOn` flag, so it stays in the
    /// declaring file (the rest of the metronome surface is in the `+Metronome` split). The beat grid is
    /// supplied separately via `setMetronomeBeats` (no grid ⇒ nothing schedules).
    func setMetronome(enabled: Bool) {
        metronomeOn = enabled
        if enabled {
            armMetronome()
        } else {
            clickVoice.stopAll()
        }
    }
}
