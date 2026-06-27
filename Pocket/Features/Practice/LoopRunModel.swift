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
    /// Elapsed run seconds (accumulated only while playing) — the ramp's interval clock.
    private(set) var elapsedSeconds: TimeInterval = 0
    /// The current playback speed as integer percent-of-original (the ramp's live plateau value).
    private(set) var currentPercent = 100
    /// Whether the song audio is still resolving/loading (imported file or demo sample).
    private(set) var isLoading = false

    private var ramp: CommandRamp?
    private var timer: Timer?
    private var lastTick: Date?
    private var fileAccess: SecurityScopedAccess?
    private var loaded = false

    init(loop: Loop) { self.loop = loop }

    var isRunning: Bool { transport != .stopped }

    /// The live playback speed as a fraction of original (× of original tempo).
    var currentSpeed: Double { Self.rate(forPercent: currentPercent) }

    /// The plateau the run is currently holding — the staircase highlight cursor. `nil` when not
    /// running (the stopped preview reads at one even weight).
    func currentPlateau(in ramp: CommandRamp) -> Int? {
        guard isRunning else { return nil }
        return ramp.currentPlateauIndex(elapsedBars: 0, elapsedSeconds: elapsedSeconds)
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
        if let bookmark = loop.song?.ref.bookmark {
            await loadImportedFile(bookmark: bookmark)
        } else {
            await loadDemoSample()
        }
        armRegion()
        loaded = true
    }

    private func loadImportedFile(bookmark: Data) async {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              let access = SecurityScopedAccess(url) else { return }
        fileAccess = access
        try? await engine.load(url: url)
    }

    private func loadDemoSample() async {
        let duration = loop.song?.duration ?? 0
        guard let sample = try? await Self.makeDemoSample(duration: duration) else { return }
        try? await engine.load(url: sample.url)
    }

    private static func makeDemoSample(duration: TimeInterval) async throws -> SampleToneGenerator.Sample {
        try await Task.detached(priority: .userInitiated) {
            try SampleToneGenerator.makeSample(duration: duration)
        }.value
    }

    /// Loop the engine on this loop's region, in seconds, against the loaded file's duration.
    private func armRegion() {
        guard engine.duration > 0 else { return }
        engine.setLoop(start: loop.start * engine.duration, end: loop.end * engine.duration)
    }

    // MARK: - Transport

    /// Start the run: arm the ramp, seed the rate at its warm-up floor, and play the looping
    /// region. The ramp drives the rate from here via the tick clock.
    func start(ramp: CommandRamp) {
        self.ramp = ramp
        elapsedSeconds = 0
        lastTick = nil
        applyRate(forElapsed: 0, ramp: ramp)
        engine.play()
        transport = .playing
        startTimer()
    }

    /// Pause / resume the run and its interval clock together.
    func toggle() {
        switch transport {
        case .playing:
            engine.pause()
            transport = .paused
            lastTick = nil          // freeze the clock; the next resume starts a fresh delta
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
        elapsedSeconds = 0
        lastTick = nil
        ramp = nil
        stopTimer()
    }

    // MARK: - Tick

    private func tick() {
        guard transport == .playing, let ramp else { return }
        let now = Date()
        if let last = lastTick { elapsedSeconds += now.timeIntervalSince(last) }
        lastTick = now
        applyRate(forElapsed: elapsedSeconds, ramp: ramp)
        if ramp.isFinished(elapsedBars: 0, elapsedSeconds: elapsedSeconds) { stop() }
    }

    /// Read the ramp's plateau at `elapsed` and push it to the engine when it changes.
    private func applyRate(forElapsed elapsed: TimeInterval, ramp: CommandRamp) {
        let percent = ramp.bpm(elapsedBars: 0, elapsedSeconds: elapsed)
        guard percent != currentPercent || elapsed == 0 else { return }
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
