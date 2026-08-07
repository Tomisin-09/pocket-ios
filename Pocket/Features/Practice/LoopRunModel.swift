import AVFoundation
import Foundation
import Observation

/// Drives a **loop training run** (ADR 0046, Phase B): the audio counterpart of the metronome
/// `StandaloneMetronomeEngine.run(ramp:)` that powers `ExerciseRunView`. It owns a private
/// `PracticeAudioEngine`, loops the song region, and steps the loop's playback **rate** through a
/// command-anchored `CommandRamp` — warm up → dwell → reach → back off — exactly as an exercise
/// climbs its click tempo, but in `×`-of-original (the ramp's plateaus are integer
/// percent-of-original, mapped here back to a rate).
///
/// The ramp's intervals are **seconds** (a loop has no metronome bars), so the run advances by
/// wall-clock elapsed *while playing* — what the player actually experiences — pausing the clock
/// with the transport. Owning its own engine keeps a Practice run independent of the waveform
/// screen's engine, mirroring `ExerciseRunView`'s isolation.
@MainActor
@Observable
final class LoopRunModel {

    enum Transport { case stopped, playing, paused }

    let loop: Loop
    private let engine = PracticeAudioEngine()

    private(set) var transport: Transport = .stopped
    /// Completed loop passes this run — the ramp's interval clock (one pass = one step). Read from
    /// the engine's rate-independent `loopIteration`, so a plateau holds a fixed number of *reps*
    /// regardless of the tempo it plays at.
    private(set) var elapsedReps = 0
    /// The current playback speed as integer percent-of-original (the ramp's live plateau value).
    private(set) var currentPercent = 100
    /// Whether the song audio is still resolving/loading (imported file or demo sample).
    private(set) var isLoading = false
    /// True when the audio could not be opened — the bookmark no longer resolves (file
    /// moved/deleted, access revoked) or the file failed to read. The run screen says so
    /// and disables Start instead of offering a silent dead run (audit 2026-07-05).
    private(set) var loadFailed = false

    private var ramp: CommandRamp?
    private var timer: Timer?
    private var fileAccess: SecurityScopedAccess?
    private var loaded = false

    /// Fired once when the ramp reaches its natural end (the last plateau's final pass), and only
    /// then — a *manual* `stop()` never invokes it. The routine player (ADR 0066, slice 3) hangs
    /// its auto-advance off this. `nil` for a standalone `LoopRunView`. Not persisted.
    var onFinished: (() -> Void)?

    init(loop: Loop) { self.loop = loop }

    var isRunning: Bool { transport != .stopped }

    /// The live playback speed as a fraction of original (× of original tempo).
    var currentSpeed: Double { Self.rate(forPercent: currentPercent) }

    /// The plateau the run is currently holding — the staircase highlight cursor. `nil` when not
    /// running (the stopped preview reads at one even weight). Driven by loop passes (the ramp's
    /// `.bars` interval reinterpreted as reps, ADR 0046 Phase B).
    func currentPlateau(in ramp: CommandRamp) -> Int? {
        guard isRunning else { return nil }
        return ramp.currentPlateauIndex(elapsedBars: elapsedReps, elapsedSeconds: 0)
    }

    /// Percent (of original) → time-stretch rate, clamped to the engine's playback bounds. The
    /// pure seam the run driver applies each tick — unit-tested rather than the audio itself.
    static func rate(forPercent percent: Int) -> Double {
        (Double(percent) / 100).clamped(to: TempoMath.minSpeed...TempoMath.maxSpeed)
    }

    // MARK: - Audio loading

    /// Resolve the song's audio and arm the loop region. Imported songs resolve their
    /// security-scoped bookmark (held open for the run via `fileAccess`); the demo song renders
    /// the dev sample — mirroring `WaveformPracticeModel.loadAudio`. Skipped in previews and once
    /// loaded.
    func loadIfNeeded() async {
        guard !loaded, !isPreview else { return }
        isLoading = true
        defer { isLoading = false }
        if let song = loop.song, song.hasImportedAudio {
            await loadImportedFile(song: song)
        } else {
            await loadDemoSample()
        }
        armRegion()
        loaded = true
    }

    private func loadImportedFile(song: Song) async {
        guard let resolved = SongAudioResolver.resolve(song) else {
            AudioPlumbing.log.error("Loop run: song audio could not be located — unavailable")
            loadFailed = true
            return
        }
        fileAccess = resolved.access
        SongAudioResolver.adoptIfNeeded(song, resolved: resolved)
        do {
            try await engine.load(url: resolved.url)
        } catch {
            AudioPlumbing.log.error("Loop run: song audio failed to load: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    private func loadDemoSample() async {
        let duration = loop.song?.duration ?? 0
        guard let sample = try? await SampleToneGenerator.makeDemoSample(duration: duration) else {
            AudioPlumbing.log.error("Loop run: demo sample render failed — audio unavailable")
            loadFailed = true
            return
        }
        do {
            try await engine.load(url: sample.url)
        } catch {
            AudioPlumbing.log.error("Loop run: demo sample failed to load: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    /// Loop the engine on this loop's region, in seconds, against the loaded file's duration.
    private func armRegion() {
        guard engine.duration > 0 else { return }
        engine.setLoop(start: loop.start * engine.duration, end: loop.end * engine.duration)
    }

    // MARK: - Transport

    /// Start the run: arm the ramp, seed the rate at its warm-up floor, and play the looping
    /// region. The ramp advances by completed loop passes, polled on the tick clock.
    func start(ramp: CommandRamp) {
        self.ramp = ramp
        elapsedReps = 0
        applyRate(forReps: 0, ramp: ramp)
        engine.play()
        transport = .playing
        startTimer()
    }

    /// Audition the looping region at a **fixed** rate for a pre-start preview (ADR 0071 R4b) — no
    /// ramp, no rep clock, so you *hear* the loop before running it. Reuses the loaded region; the
    /// caller (a `LoopAudioPreviewPlayer`) auto-stops it after a few seconds. No-op unless stopped and
    /// the audio actually loaded, so a failed load never plays silence.
    func startAudition(percent: Int) {
        guard transport == .stopped, loaded, !loadFailed else { return }
        currentPercent = percent
        engine.setRate(Self.rate(forPercent: percent))
        engine.play()
        transport = .playing
    }

    /// Adjust the audition playback rate **live** — the ear-training tempo control (ADR 0104). Stores
    /// the percent (so a next `startAudition` could seed from it) and, while sounding, pushes the new
    /// rate to the engine so slowing/speeding takes effect mid-listen. No-op semantics outside an
    /// audition are fine: it just records the value.
    func setAuditionPercent(_ percent: Int) {
        currentPercent = percent
        guard transport == .playing else { return }
        engine.setRate(Self.rate(forPercent: percent))
    }

    /// Pause / resume the run. The rep counter rides the engine's render position, so it freezes on
    /// pause and resumes on play with no extra bookkeeping.
    func toggle() {
        switch transport {
        case .playing:
            engine.pause()
            transport = .paused
            stopTimer()
        case .paused:
            engine.play()
            transport = .playing
            startTimer()
        case .stopped:
            break
        }
    }

    /// End the run: stop the audio, release the session, and reset to setup.
    func stop() {
        engine.stop()
        transport = .stopped
        elapsedReps = 0
        ramp = nil
        stopTimer()
    }

    // MARK: - Tick

    private func tick() {
        guard transport == .playing, let ramp else { return }
        elapsedReps = engine.loopIteration
        applyRate(forReps: elapsedReps, ramp: ramp)
        if ramp.isFinished(elapsedBars: elapsedReps, elapsedSeconds: 0) {
            stop()
            // Natural end of the ramp — let an observing session player advance. After `stop()`
            // (which clears the ramp) and never in `stop()` itself, so a manual stop stays silent.
            onFinished?()
        }
    }

    /// Read the ramp's plateau at `reps` and push it to the engine when it changes.
    private func applyRate(forReps reps: Int, ramp: CommandRamp) {
        let percent = ramp.bpm(elapsedBars: reps, elapsedSeconds: 0)
        guard percent != currentPercent || reps == 0 else { return }
        currentPercent = percent
        engine.setRate(Self.rate(forPercent: percent))
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
