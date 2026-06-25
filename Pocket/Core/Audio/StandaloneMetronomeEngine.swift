import AVFoundation
import Observation
import QuartzCore

/// The **standalone** metronome's audio engine (ADR 0043, slice 3). Unlike the in-song
/// click (which rides a song's playback clock through `PracticeAudioEngine`), this owns
/// its **own** `AVAudioEngine` and reuses `ClickVoice` + the pure `MetronomeBeats`
/// generator: there is no song to follow, so it generates its own grid from a tempo and a
/// time signature and sounds it on the audio hardware clock.
///
/// **Steadiness comes from the sample clock.** Every click is scheduled at an *absolute*
/// sample position — `phaseOrigin + index · framesPerBeat` — so the tempo is locked to the
/// audio hardware and can't wander with `Timer` jitter (the timer only tops up the
/// look-ahead; it never decides *when* a beat sounds). The on-screen **flash** is derived
/// from the same render clock, shifted back by the output latency so the lit dot lands on
/// the click you actually hear rather than leading it.
///
/// Three transport states, two clocks. **Stopped → playing → paused**: pausing freezes the
/// session and silences the click but keeps it resumable; stopping zeroes everything. A
/// **wall-clock** session timer (`elapsed`, accumulated across pause/resume) is the
/// ephemeral tracker and a tempo change never resets it; the **sample-clock** `phaseOrigin`
/// drives the beat grid and *is* re-anchored on a tempo/signature change (or a resume) so
/// the next downbeat lands cleanly. Lock-screen / Control Center play-pause is wired through
/// the shared `NowPlayingController`, and the `audio` background mode (ADR 0025) keeps the
/// click sounding while the phone is locked. The beat math is the unit-tested
/// `MetronomeBeats` / `TimeSignature`.
@MainActor
@Observable
final class StandaloneMetronomeEngine {

    /// Where the transport is. `playing` and `paused` both hold a live session; only
    /// `stopped` has a zeroed clock.
    enum Transport { case stopped, playing, paused }

    /// Tempo bounds — the same musical range tap-tempo clamps to
    /// (`TempoMath.minTapBPM...maxTapBPM`), so a dialled and a tapped tempo agree.
    static let bpmRange: ClosedRange<Int> = 30...300

    private(set) var transport: Transport = .stopped
    /// Working tempo (absolute BPM). Mutated only through `setBPM`/`adjustBPM` so it stays
    /// clamped; `private(set)` keeps it observable.
    private(set) var bpm = 90
    /// The current meter and its accent pattern.
    private(set) var timeSignature: TimeSignature = .standard

    // Automator (ADR 0043, slice 4) — an optional ramp that climbs the BPM over the
    // sitting. Config is observable for the controls; the live ramp math is the pure
    // `MetronomeAutomator`. When on, the ramp drives `bpm` each tick toward the ceiling.
    // Automator config — read by the views, written through the setters in the
    // `+Automator` split (so they're internal, not `private(set)`, like the click state the
    // `PracticeAudioEngine+Metronome` split drives). Don't set these directly from the UI;
    // go through `setAutomator…` so validation and re-engagement run.
    var automatorEnabled = false
    var automatorStepBPM = 5
    var automatorIntervalCount = 4
    var automatorUnit: MetronomeIntervalUnit = .bars
    var automatorCeiling = 110
    /// The ramp's **floor** — the tempo it started from (captured when armed). The floor is
    /// always the current metronome tempo at the moment you arm; the restart returns here.
    private(set) var automatorStartBPM = 90

    /// The automator's mode for the segmented control — off, or stepping by bars / by time.
    enum AutomatorMode: Hashable { case off, bars, seconds }
    var automatorMode: AutomatorMode {
        guard automatorEnabled else { return .off }
        return automatorUnit == .bars ? .bars : .seconds
    }

    /// Index since the current phase anchor of the most recently *heard* beat (-1 before
    /// the first). The flash lights `currentBeat % timeSignature.beats`; the meter's accent
    /// pattern decides which dots read strong.
    private(set) var currentBeat = -1
    /// Wall-clock seconds of active practice this sitting — accumulated across pause/resume,
    /// frozen while paused, zeroed on stop (ADR 0043). Survives tempo changes. Not persisted.
    private(set) var elapsed: TimeInterval = 0

    /// Convenience for the views: the click is actively sounding.
    var isPlaying: Bool { transport == .playing }

    private let engine = AVAudioEngine()
    private let clickVoice = ClickVoice()
    private let nowPlaying = NowPlayingController()
    private var timer: Timer?

    /// Active-practice time banked before the current play stretch (grows on each pause).
    private var accumulatedSession: TimeInterval = 0
    /// Wall-clock anchor for the *current* play stretch; `elapsed = accumulated + (now − this)`.
    private var sessionStart: CFTimeInterval = 0
    /// Sample-clock anchor for the beat grid (the sample at which beat 0 sounds), or `nil`
    /// until the node has rendered and it can be placed. Re-set on tempo/signature/resume.
    private var phaseOrigin: AVAudioFramePosition?
    /// Index of the last beat handed to `ClickVoice`, so each schedules exactly once.
    private var scheduledThrough = -1
    /// Output latency (frames) between a rendered sample and the speaker — the flash is
    /// shifted back by this so it tracks the heard click, not the rendered one.
    private var latencyFrames: AVAudioFramePosition = 0

    // Automator ramp progress, measured *since the ramp engaged* (independent of the
    // session timer, which a tempo change must not disturb). Both are integrated from the
    // tick delta so they survive the per-step phase re-anchors; bars accrue at the live
    // tempo (`delta · bpm/60 / beatsPerBar`).
    private var automatorBarsElapsed = 0.0
    private var automatorSecondsElapsed = 0.0
    private var lastTickTime: CFTimeInterval = 0

    /// How far ahead (real seconds) clicks are queued each tick. Comfortably larger than the
    /// tick interval so every beat is pinned to its sample well before it sounds.
    private let horizon: TimeInterval = 0.3
    /// Lead before beat 0 when (re)anchoring, so the first click is scheduled just ahead of
    /// the render head rather than in the past.
    private let leadSeconds: TimeInterval = 0.06

    init() {
        clickVoice.attach(to: engine)
    }

    // MARK: - Transport

    /// The primary play/pause/resume control: stopped → play, playing → pause,
    /// paused → resume.
    func toggle() {
        switch transport {
        case .stopped: start()
        case .playing: pause()
        case .paused: resume()
        }
    }

    func start() {
        guard transport == .stopped else { return }
        configureSession()
        startEngineIfNeeded()
        clickVoice.start()
        let session = AVAudioSession.sharedInstance()
        latencyFrames = AVAudioFramePosition((session.outputLatency + session.ioBufferDuration)
                                             * clickVoice.clockSampleRate)
        accumulatedSession = 0
        elapsed = 0
        beginPlayStretch()
        if automatorEnabled { engageAutomator() }
        nowPlaying.activate(onPlay: { [weak self] in self?.resume() },
                            onPause: { [weak self] in self?.pause() },
                            onToggle: { [weak self] in self?.toggle() })
        pushNowPlaying()
    }

    /// Pause the click but keep the session: freeze the timer, silence the voice, and leave
    /// it resumable from the lock screen or the on-screen button.
    func pause() {
        guard transport == .playing else { return }
        accumulatedSession += CACurrentMediaTime() - sessionStart
        elapsed = accumulatedSession
        transport = .paused
        stopTimer()
        clickVoice.stopAll()
        currentBeat = -1
        pushNowPlaying()
    }

    /// Resume from pause: restart the click on a fresh phase anchor (next downbeat lands
    /// cleanly) and continue the session clock.
    func resume() {
        guard transport == .paused else { return }
        clickVoice.start()
        beginPlayStretch()
        pushNowPlaying()
    }

    /// Stop and **reset** the session to zero — the destructive end, distinct from pause.
    func stop() {
        guard transport != .stopped else { return }
        transport = .stopped
        stopTimer()
        clickVoice.stopAll()
        engine.stop()
        nowPlaying.teardown()
        accumulatedSession = 0
        elapsed = 0
        currentBeat = -1
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Enter (or re-enter) the playing state: anchor a fresh play stretch and beat phase and
    /// start the driver.
    private func beginPlayStretch() {
        transport = .playing
        sessionStart = CACurrentMediaTime()
        lastTickTime = sessionStart
        phaseOrigin = nil               // placed on the first tick once the node has rendered
        scheduledThrough = -1
        currentBeat = -1
        startTimer()
    }

    /// Engage the ramp: capture the **current tempo as the floor** and reset the bar/second
    /// progress so the climb begins from here (no tempo jump — the floor *is* where you are).
    /// Internal so the `+Automator` split can call it.
    func engageAutomator() {
        automatorStartBPM = bpm
        automatorBarsElapsed = 0
        automatorSecondsElapsed = 0
        lastTickTime = CACurrentMediaTime()
    }

    /// Quick-restart the ramp: jump the tempo back to the floor and replay the climb. No-op
    /// when the automator is off.
    func restartAutomator() {
        guard automatorEnabled else { return }
        applyTempo(automatorStartBPM)
        automatorBarsElapsed = 0
        automatorSecondsElapsed = 0
        lastTickTime = CACurrentMediaTime()
        pushNowPlaying()
    }

    // MARK: - Tempo & signature

    /// Set the tempo **manually** (steppers / slider / tap), clamped to `bpmRange`. A manual
    /// tempo change **switches the automator off** — you've taken the wheel — so it never
    /// fights you (only pause/resume preserve a running ramp).
    func setBPM(_ value: Int) {
        let wasAutomating = automatorEnabled
        let changed = applyTempo(value)
        if wasAutomating { setAutomatorEnabled(false) }
        if changed || wasAutomating { pushNowPlaying() }
    }

    /// Nudge the tempo by `delta` BPM (the −/+ steppers).
    func adjustBPM(by delta: Int) { setBPM(bpm + delta) }

    /// Apply a tempo and re-anchor the beat phase, clamped — the shared mechanism for both a
    /// manual change and an automator step. Returns whether the tempo actually changed.
    @discardableResult
    private func applyTempo(_ value: Int) -> Bool {
        let clamped = min(Self.bpmRange.upperBound, max(Self.bpmRange.lowerBound, value))
        guard clamped != bpm else { return false }
        bpm = clamped
        reanchorPhase()
        return true
    }

    func setTimeSignature(_ signature: TimeSignature) {
        guard signature != timeSignature else { return }
        timeSignature = signature
        reanchorPhase()
        pushNowPlaying()
    }

    /// The Italian tempo marking for the current tempo (ADR 0043, slice 1).
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(bpm)) }

    // MARK: - Driving

    /// Drop the current beat grid and re-anchor it at the next tick: flush queued clicks
    /// (timed against the old phase/tempo) and refill from a fresh origin. Leaves the
    /// session tracker untouched. No-op unless actively playing.
    private func reanchorPhase() {
        guard transport == .playing else { return }
        clickVoice.stopAll()
        clickVoice.start()
        phaseOrigin = nil
        scheduledThrough = -1
        currentBeat = -1
    }

    private var framesPerBeat: Double { 60.0 / Double(bpm) * clickVoice.clockSampleRate }

    private func beatSample(_ index: Int, origin: AVAudioFramePosition) -> AVAudioFramePosition {
        origin + AVAudioFramePosition((Double(index) * framesPerBeat).rounded())
    }

    /// One driver step (~every 20 ms while playing): advance the session clock, pin any
    /// beats now inside the look-ahead window to absolute sample positions, and flip the
    /// flash to the most recent *heard* beat.
    private func tick() {
        let now = CACurrentMediaTime()
        elapsed = accumulatedSession + max(0, now - sessionStart)

        // Automator: accrue ramp progress at the live tempo and apply the resolved BPM. Done
        // before scheduling so a step's new phase is set up within this same tick.
        if automatorEnabled {
            let delta = max(0, now - lastTickTime)
            automatorSecondsElapsed += delta
            automatorBarsElapsed += delta * (Double(bpm) / 60.0) / Double(max(1, timeSignature.beats))
            let target = automatorRamp.bpm(elapsedBars: Int(automatorBarsElapsed),
                                           elapsedSeconds: automatorSecondsElapsed)
            if applyTempo(target) { pushNowPlaying() }
        }
        lastTickTime = now

        guard let renderSample = clickVoice.renderSampleTime() else { return }
        let perBeat = framesPerBeat
        guard perBeat > 0 else { return }

        // Anchor beat 0 just ahead of the render head the first tick after (re)start.
        let origin: AVAudioFramePosition
        if let existing = phaseOrigin {
            origin = existing
        } else {
            origin = renderSample + AVAudioFramePosition(leadSeconds * clickVoice.clockSampleRate)
            phaseOrigin = origin
        }

        // Audio: schedule every beat whose sample falls within the look-ahead window and
        // hasn't been queued yet — locked to the sample grid, so the spacing never drifts.
        let horizonFrames = AVAudioFramePosition(horizon * clickVoice.clockSampleRate)
        var index = scheduledThrough + 1
        while beatSample(index, origin: origin) <= renderSample + horizonFrames {
            let accented = timeSignature.isAccented(beatInBar: index)
            clickVoice.schedule(atSampleTime: beatSample(index, origin: origin), accented: accented)
            scheduledThrough = index
            index += 1
        }

        // Visual: the most recent beat the listener has actually heard (render head minus
        // output latency), so the lit dot lands on the click rather than leading it.
        let heard = Double(renderSample - latencyFrames - origin)
        if heard >= -perBeat * 1e-6 {
            let reached = max(0, Int(floor(heard / perBeat + 1e-9)))
            if reached != currentBeat { currentBeat = reached }
        }
    }

    /// Push the metronome's state to the lock screen / Control Center. Title is the tool,
    /// the secondary line is the live tempo + meter, and the rate freezes the clock when
    /// paused.
    private func pushNowPlaying() {
        guard transport != .stopped else { return }
        nowPlaying.update(NowPlayingState(
            title: "Metronome",
            artist: "\(bpm) BPM · \(timeSignature.name)",
            duration: 0,
            elapsedTime: elapsed,
            isPlaying: transport == .playing,
            speed: 1))
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
}
