import SwiftData
import SwiftUI

/// State + behaviour for the practice screen (design brief §4.1), extracted from
/// `WaveformPracticeView` so the view stays thin and the gesture/loop handlers have
/// a shared home. Bound to a persisted `Song`: `loops`/`markers` are its SwiftData
/// relationships, created/edited/deleted through `context`. The view observes this
/// model; handlers live in `WaveformPracticeModel+Actions.swift`. See ADRs 0007 & 0011.
@MainActor
@Observable
final class WaveformPracticeModel {

    /// The persisted song being practised, and the context its data lives in.
    let song: Song
    let context: ModelContext

    // UI state.
    var speed: Double = 1.0
    var mode: WaveformPracticeView.InteractionMode = .navigate
    var songInfoExpanded = false   // demoted to the scroll area
    var loopsExpanded = true
    var markersExpanded = false

    /// Pinch-to-zoom: the fraction of the song the detail waveform shows (`1` =
    /// whole song). The visible window tracks the playhead — see `viewport`.
    var zoomSpan: Double = 1

    // Audio engine + the waveform amplitudes it's showing.
    let engine = PracticeAudioEngine()
    var amplitudes: [Double]

    /// True while the song's audio is being opened/prepared, so the view can show a
    /// loading overlay instead of an apparently-frozen surface (the file open and the
    /// demo-sample render both run off the main actor).
    private(set) var isLoadingAudio = false

    /// Holds the imported file's security scope open while it plays (the engine reads
    /// lazily); released automatically when this model — and so this property — is
    /// deallocated. `nil` for the generated demo sample.
    private var fileAccess: SecurityScopedAccess?

    /// The active loop, tracked by its stable `Loop.uid`.
    var activeLoopID: UUID?
    var editingLoop: Loop?
    var editingMarker: Marker?
    /// A freshly-dropped marker awaiting a name (drives the name-only sheet). It's a
    /// detached `@Model` — persisted only on save; cancelling drops it.
    var namingMarker: Marker?
    /// The loop whose automator (speed ramp) is being set up (drives the sheet, ADR 0013).
    var editingAutomatorLoop: Loop?

    init(song: Song, context: ModelContext) {
        self.song = song
        self.context = context
        self.amplitudes = song.amplitudes
        self.activeLoopID = song.loopsByStart.first?.uid
    }

    /// The song's loops/markers in a stable display order (SwiftData relationships).
    var loops: [Loop] { song.loopsByStart }
    var markers: [Marker] { song.markersByTime }

    /// Tap mode: the start of the loop being captured (the green forming
    /// region), awaiting its closing tap.
    var pendingStart: Double?
    /// The captured loop awaiting confirmation (drives the ConfirmBar). Bounds
    /// are mutable so Fine handles drag them live; `fromFine` shows the blue
    /// handles; a non-nil `editingLoop` means we're adjusting an existing
    /// loop's range rather than creating one.
    var capture: CaptureDraft?
    /// The confirmed loop awaiting a name (drives the naming sheet).
    var namingDraft: NamingDraft?

    /// Read-only BPM display: round(songBPM × speed) — brief §4.1 speed bar.
    /// `nil` when the song has no known tempo (see ADR 0004); the speed
    /// multiplier still works regardless.
    var displayedBPM: Int? {
        song.bpm.map { Int((Double($0) * speed).rounded()) }
    }

    /// The loop currently loaded into the transport/waveform, if any.
    var activeLoop: Loop? { loops.first { $0.uid == activeLoopID } }

    // MARK: - Automator (per-loop speed ramp, ADR 0013)

    /// Apply the active loop's speed ramp at a new loop iteration (driven by the engine's
    /// `loopIteration`). No-op unless that loop's automator is enabled and it's playing.
    /// Sets `speed`, which the view feeds to the engine via its existing `onChange`. Once
    /// the ramp has played its last automated pass (`totalLoops`), playback **stops** and
    /// rewinds to the loop start so the ramp can be replayed from the top (ADR 0013).
    func automatorAdvance(toLoopIteration iteration: Int) {
        guard let loop = activeLoop, loop.automatorEnabled, engine.isPlaying else { return }
        let config = loop.automator
        if iteration >= config.totalLoops {
            engine.pause()
            engine.seek(toSeconds: loop.startSeconds)   // rewind (resets the wrap counter) so a replay starts fresh
            return
        }
        let target = config.speed(atLoopIteration: iteration)
        if abs(target - speed) > 0.0001 { speed = target }
    }

    /// "Set ramp" on the automator sheet: arm the loop's ramp, make it the active loop,
    /// and start playing it from the top at the ramp's start speed (ADR 0013).
    func startAutomator(for loop: Loop) {
        speed = loop.automator.speed(atLoopIteration: 0)   // begin at the ramp start
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// "Turn off ramp" on the automator sheet: the sheet has already written
    /// `enabled = false`, so the next loop wrap's `automatorAdvance` simply no-ops and the
    /// speed stops changing. Nothing else to do — kept as a named hook for the view.
    func turnOffAutomator(for loop: Loop) {}

    /// The user grabbed the speed slider — hand control back by disabling the active
    /// loop's ramp, so it stops fighting the manual setting.
    func userAdjustedSpeed() {
        activeLoop?.automatorEnabled = false
    }

    /// Live playhead as a fraction of the song (0...1), driven by the engine.
    var playheadFraction: Double {
        engine.duration > 0 ? engine.currentTime / engine.duration : 0
    }

    /// Effective song length — the engine's once loaded, else the mock's.
    var duration: TimeInterval {
        engine.duration > 0 ? engine.duration : song.duration
    }

    /// The visible window of the song (song fractions), centred on the playhead at
    /// the current `zoomSpan`. Drives both the waveform render and the minimap box.
    var viewport: (start: Double, end: Double) {
        WaveformGesture.viewport(center: playheadFraction, span: zoomSpan)
    }

    /// The Fine-mode selection to render (blue handles), if one is being defined.
    var fineSelection: (start: Double, end: Double)? {
        guard let capture, capture.fromFine else { return nil }
        return (capture.start, capture.end)
    }

    /// The Tap-mode captured region to keep highlighted green while confirming.
    var tapSelection: (start: Double, end: Double)? {
        guard let capture, !capture.fromFine else { return nil }
        return (capture.start, capture.end)
    }

    /// True while adjusting an existing loop's range — the reference area dims to
    /// focus the waveform.
    var isRangeEditing: Bool { capture?.editingLoop != nil }

    /// The confirm pill shows while a region is captured but not yet being named.
    var showConfirm: Bool { capture != nil && namingDraft == nil }

    var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Hand the song's audio to the engine: the resolved real file for an imported
    /// song, or the generated dev sample for the demo (`bookmark == nil`). Skipped
    /// in previews.
    func loadAudio() async {
        guard !isPreview, engine.duration == 0 else { return }
        isLoadingAudio = true
        defer { isLoadingAudio = false }
        if let bookmark = song.ref.bookmark {
            await loadImportedFile(bookmark: bookmark)
        } else {
            await loadDemoSample()
        }
        engine.setRate(speed)
    }

    /// Resolve the security-scoped bookmark and load the real file. Access is held
    /// open (`fileAccess`) for the engine's lazy reads, released on deinit. The
    /// engine opens the file off the main actor; `amplitudes` already holds the
    /// waveform extracted at import (set in `init`).
    private func loadImportedFile(bookmark: Data) async {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              let access = SecurityScopedAccess(url) else { return }
        fileAccess = access
        await refreshWaveformIfOutdated(url: url)
        try? await engine.load(url: url)
    }

    /// Re-extract the stored waveform when it predates the current reduction (ADR
    /// 0017). A bucket count other than `WaveformExtractor.defaultBuckets` means the
    /// song was imported under the old peak-based envelope, so we re-reduce from the
    /// file and persist — self-healing without a separate schema-version field. The
    /// decode runs off the main actor; a failure leaves the old waveform in place.
    private func refreshWaveformIfOutdated(url: URL) async {
        guard song.amplitudes.count != WaveformExtractor.defaultBuckets else { return }
        guard let extracted = try? await Task.detached(priority: .utility, operation: {
            try WaveformExtractor.extract(from: url)
        }).value else { return }
        song.amplitudes = extracted.amplitudes
        amplitudes = extracted.amplitudes
        try? context.save()
    }

    /// Generate the dev arpeggio off the main actor and hand it to the engine (the
    /// demo sample). The render writes a WAV, so it's kept off the main thread too.
    private func loadDemoSample() async {
        guard let sample = try? await Self.makeDemoSample(duration: song.duration) else { return }
        amplitudes = sample.amplitudes
        try? await engine.load(url: sample.url)
    }

    private static func makeDemoSample(duration: TimeInterval) async throws -> SampleToneGenerator.Sample {
        try await Task.detached(priority: .userInitiated) {
            try SampleToneGenerator.makeSample(duration: duration)
        }.value
    }
}

/// Holds a security-scoped resource open for its lifetime, releasing it on dealloc.
/// Lets a `@MainActor` owner release access implicitly via property teardown, with
/// no nonisolated `deinit` reaching into actor-isolated state (Swift 6).
private final class SecurityScopedAccess {
    private let url: URL
    init?(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        self.url = url
    }
    deinit { url.stopAccessingSecurityScopedResource() }
}
