import AVFoundation
import Foundation
import Observation

/// Drives a **song-block play-along** in a routine (ADR 0066 / 0071): the audio-only counterpart of
/// `LoopRunModel`, but for a whole-song run-through rather than a looped region. A song block is an
/// open jam, so there is **no ramp** (ADR 0071) — one fixed play-along speed you set, applied to the
/// time-stretched audio and adjustable live. It owns a private `PracticeAudioEngine`, keeping a
/// Practice song run independent of the waveform screen, exactly as the loop run does.
///
/// **Completion is settings-driven.** By default the song **loops** (replays from the top when it
/// reaches the end) and only a Skip advances the routine — the "open jam" default. With *Loop song
/// blocks* off (`AppSettings.routineSongLoop`) it plays through once and then advances like any other
/// block via `onFinished`. Whole-song looping is done by **replaying on the natural end**, not by the
/// engine's crossfaded loop buffer — that buffer holds the whole region in memory, which is fine for a
/// short loop but hundreds of MB for a full song. A brief seam at the song boundary is natural for a
/// jam loop.
///
/// **No evaluation surface (ADR 0070):** it plays and reports position, nothing about how well.
@MainActor
@Observable
final class SongPlayAlongModel {

    enum Transport { case stopped, playing, paused }

    let song: Song
    private let engine = PracticeAudioEngine()

    private(set) var transport: Transport = .stopped
    /// Whether the song audio is still resolving/loading (imported file or demo sample).
    private(set) var isLoading = false
    /// True when the audio could not be opened — the bookmark no longer resolves or the file failed
    /// to read. The view says so and disables Start rather than offering a silent dead run.
    private(set) var loadFailed = false

    /// The fixed play-along speed as integer percent of original — set on Start and adjustable live;
    /// no ramp (ADR 0071).
    private(set) var percent = 100

    /// Whether the whole song loops (jam) vs plays through once — read from settings on Start.
    private var looping = true

    /// Fired once when a **non-looping** song reaches its natural end — the routine player hangs its
    /// auto-advance off this (a looping song never fires it; a Skip advances instead). `nil` standalone.
    var onFinished: (() -> Void)?

    private var fileAccess: SecurityScopedAccess?
    private var loaded = false

    init(song: Song) { self.song = song }

    var isRunning: Bool { transport != .stopped }
    /// Live playhead / total, in seconds — passthrough to the engine (observed through it).
    var currentTime: TimeInterval { engine.currentTime }
    var duration: TimeInterval { engine.duration }

    /// Playback-speed bounds as integer percent — `TempoMath`'s axis, one ceiling for every speed
    /// surface (ADR 0124).
    static let percentRange = TempoMath.percentRange

    /// Percent (of original) → time-stretch rate, clamped to the engine's playback bounds.
    static func rate(forPercent percent: Int) -> Double {
        (Double(percent) / 100).clamped(to: TempoMath.minSpeed...TempoMath.maxSpeed)
    }

    // MARK: - Audio loading

    /// Resolve the song's audio via `SongAudioResolver` — Pocket's own copy, else the legacy
    /// bookmark (held open for the run via `fileAccess`); the demo song renders the dev sample —
    /// mirroring `LoopRunModel`.
    /// Skipped in previews and once loaded. Seeds the working `percent` from the song's resume speed.
    func loadIfNeeded() async {
        percent = clampPercent(Int((song.resumeSpeed * 100).rounded()))
        guard !loaded, !isPreview else { return }
        isLoading = true
        defer { isLoading = false }
        if song.hasImportedAudio {
            await loadImportedFile()
        } else {
            await loadDemoSample()
        }
        loaded = true
    }

    private func loadImportedFile() async {
        guard let resolved = SongAudioResolver.resolve(song) else {
            AudioPlumbing.log.error("Song play-along: audio could not be located — unavailable")
            loadFailed = true
            return
        }
        fileAccess = resolved.access
        SongAudioResolver.adoptIfNeeded(song, resolved: resolved)
        do {
            try await engine.load(url: resolved.url)
        } catch {
            AudioPlumbing.log.error("Song play-along: audio failed to load: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    private func loadDemoSample() async {
        guard let sample = try? await SampleToneGenerator.makeDemoSample(duration: song.duration) else {
            AudioPlumbing.log.error("Song play-along: demo sample render failed — audio unavailable")
            loadFailed = true
            return
        }
        do {
            try await engine.load(url: sample.url)
        } catch {
            AudioPlumbing.log.error("Song play-along: demo sample failed to load: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    // MARK: - Transport

    /// Start the play-along at the given fixed speed. In loop mode the song replays from the top on
    /// its natural end; otherwise the end advances the routine via `onFinished`.
    func start(percent: Int, loopWholeSong: Bool) {
        self.percent = clampPercent(percent)
        looping = loopWholeSong
        engine.setRate(Self.rate(forPercent: self.percent))
        engine.onReachedEnd = { [weak self] in self?.handleReachedEnd() }
        engine.play()
        transport = .playing
    }

    /// Pause / resume playback.
    func toggle() {
        switch transport {
        case .playing:
            engine.pause()
            transport = .paused
        case .paused:
            engine.play()
            transport = .playing
        case .stopped:
            break
        }
    }

    /// End the run: stop the audio and release the session, back to setup.
    func stop() {
        engine.onReachedEnd = nil
        engine.stop()
        transport = .stopped
    }

    /// Jump the playhead by `seconds` (± ), clamped to the song bounds.
    func skip(by seconds: TimeInterval) {
        engine.seek(toSeconds: (currentTime + seconds).clamped(to: 0...max(0, duration)))
    }

    /// Change the live play-along speed (no ramp) — applies to the engine immediately.
    func setPercent(_ value: Int) {
        percent = clampPercent(value)
        engine.setRate(Self.rate(forPercent: percent))
    }

    /// The song reached its natural end. Loop mode replays from the top (a jam); otherwise advance
    /// the routine. `handleReachedEnd` in the engine has already reset the playhead to 0.
    private func handleReachedEnd() {
        if looping {
            engine.play()
        } else {
            transport = .stopped
            onFinished?()
        }
    }

    private func clampPercent(_ value: Int) -> Int {
        min(Self.percentRange.upperBound, max(Self.percentRange.lowerBound, value))
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
