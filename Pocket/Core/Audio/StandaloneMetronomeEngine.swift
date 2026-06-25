import AVFoundation
import Observation
import QuartzCore

/// The **standalone** metronome's audio engine (ADR 0043, slice 3). Unlike the in-song
/// click (which rides a song's playback clock through `PracticeAudioEngine`), this owns
/// its **own** `AVAudioEngine` and reuses `ClickVoice` + the pure `MetronomeBeats`
/// generator: there is no song to follow, so it generates its own grid from a tempo and
/// a time signature and sounds it on its own wall-clock.
///
/// One wall-clock, two anchors. `sessionStart` drives the ephemeral **session tracker**
/// (`elapsed`) and is set once per sitting — it is *not* disturbed by a tempo change, so
/// nudging the BPM never resets "how long you've practised." `phaseStart` drives the beat
/// grid (audio + the flash indicator) and **is** re-anchored on a tempo/signature change,
/// so the new tempo's downbeat lands cleanly at the moment of the change rather than
/// sounding cramped against the old phase. The audio (look-ahead scheduling) and the
/// on-screen flash (`currentBeat`, look-back) read from the same grid, so they can't drift
/// (ADR 0043). AVFoundation lives here; the timing math is the unit-tested `MetronomeBeats`.
@MainActor
@Observable
final class StandaloneMetronomeEngine {

    /// Tempo bounds for the standalone tool — the same musical range tap-tempo clamps to
    /// (`TempoMath.minTapBPM...maxTapBPM`), so a dialled and a tapped tempo agree.
    static let bpmRange: ClosedRange<Int> = 30...300
    /// Beats-per-bar bounds: 1 (every click a downbeat) through a generous 16.
    static let beatsPerBarRange: ClosedRange<Int> = 1...16

    private(set) var isPlaying = false
    /// Working tempo (absolute BPM). Mutated only through `setBPM`/`adjustBPM` so it stays
    /// clamped; `private(set)` keeps the observable readable by the view.
    private(set) var bpm = 90
    /// Beats per bar — the downbeat grouping and the indicator dot count.
    private(set) var beatsPerBar = 4

    /// Index since the current phase anchor of the most recently *reached* beat (-1 before
    /// the first). The flash indicator lights `currentBeat % beatsPerBar`; beat 0 of each
    /// bar is the accented downbeat.
    private(set) var currentBeat = -1
    /// Wall-clock seconds since play started — the ephemeral session tracker. Resets on
    /// stop, **survives** tempo changes (ADR 0043). Not persisted.
    private(set) var elapsed: TimeInterval = 0

    private let engine = AVAudioEngine()
    private let clickVoice = ClickVoice()
    private var timer: Timer?
    /// Anchor for the session tracker (`elapsed`); set once per sitting.
    private var sessionStart: CFTimeInterval = 0
    /// Anchor for the beat grid; re-set on tempo/signature change.
    private var phaseStart: CFTimeInterval = 0
    /// Index of the last beat handed to `ClickVoice`, so each schedules exactly once across
    /// the overlapping look-ahead windows.
    private var scheduledThrough = -1
    /// How far ahead (real seconds) clicks are queued each tick. Comfortably larger than the
    /// tick interval so every beat is caught well before it sounds.
    private let horizon: TimeInterval = 0.5

    init() {
        clickVoice.attach(to: engine)
    }

    // MARK: - Transport

    func toggle() {
        if isPlaying { stop() } else { start() }
    }

    func start() {
        guard !isPlaying else { return }
        configureSession()
        startEngineIfNeeded()
        clickVoice.start()
        let now = CACurrentMediaTime()
        sessionStart = now
        phaseStart = now
        scheduledThrough = -1
        currentBeat = -1
        elapsed = 0
        isPlaying = true
        startTimer()
        tick()                      // sound the downbeat immediately on play
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        stopTimer()
        clickVoice.stopAll()
        engine.stop()
        currentBeat = -1
        elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Tempo & signature

    /// Set the tempo, clamped to `bpmRange`. Re-anchors the beat phase if playing so the
    /// new tempo's downbeat lands now (the session tracker keeps running).
    func setBPM(_ value: Int) {
        let clamped = min(Self.bpmRange.upperBound, max(Self.bpmRange.lowerBound, value))
        guard clamped != bpm else { return }
        bpm = clamped
        restartPhaseIfPlaying()
    }

    /// Nudge the tempo by `delta` BPM (the −/+ steppers).
    func adjustBPM(by delta: Int) { setBPM(bpm + delta) }

    func setBeatsPerBar(_ value: Int) {
        let clamped = min(Self.beatsPerBarRange.upperBound, max(Self.beatsPerBarRange.lowerBound, value))
        guard clamped != beatsPerBar else { return }
        beatsPerBar = clamped
        restartPhaseIfPlaying()
    }

    /// The Italian tempo marking for the current tempo (ADR 0043, slice 1).
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(bpm)) }

    // MARK: - Driving

    /// Re-anchor the beat grid at the present instant: flush queued clicks (they were timed
    /// against the old phase) and refill from the new one. The session tracker is untouched.
    private func restartPhaseIfPlaying() {
        guard isPlaying else { return }
        clickVoice.stopAll()
        clickVoice.start()
        phaseStart = CACurrentMediaTime()
        scheduledThrough = -1
        currentBeat = -1
        tick()
    }

    /// One driver step (every ~30 ms while playing): advance the session clock and the
    /// flash, and queue any beats now inside the look-ahead window.
    private func tick() {
        let now = CACurrentMediaTime()
        elapsed = max(0, now - sessionStart)

        let interval = 60.0 / Double(bpm)
        guard interval > 0 else { return }
        let phaseNow = now - phaseStart

        // Visual: the most recent beat whose time has passed (look-back).
        if phaseNow >= -interval * 1e-9 {
            let reached = Int(floor(phaseNow / interval + 1e-9))
            if reached != currentBeat { currentBeat = max(0, reached) }
        }

        // Audio: schedule beats in (now, now + horizon] not yet queued (look-ahead).
        let beats = MetronomeBeats.beats(bpm: Double(bpm), beatsPerBar: beatsPerBar,
                                         from: max(0, phaseNow), through: phaseNow + horizon)
        for beat in beats {
            let index = Int((beat.time / interval).rounded())
            if index <= scheduledThrough { continue }
            clickVoice.schedule(delay: max(0, beat.time - phaseNow), accented: beat.isDownbeat)
            scheduledThrough = index
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
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
