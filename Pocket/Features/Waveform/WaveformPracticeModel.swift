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
    /// whole song). Paired with `viewportStart` to form the `viewport` window.
    var zoomSpan: Double = 1

    /// Page-mode (ADR 0010): the **anchored** left edge of the visible window (a song
    /// fraction). Owned state — not derived from the playhead — so the window holds
    /// still while the playhead sweeps across it, then pages forward (see
    /// `advancePageIfNeeded`). `0` with `zoomSpan == 1` is the whole song.
    var viewportStart: Double = 0

    // Audio engine + the waveform amplitudes it's showing.
    let engine = PracticeAudioEngine()
    var amplitudes: [Double]

    /// Crisp deep-zoom (ADR 0020): a re-downsample of just the visible window, read
    /// from the source file at full detail, with the song range it covers. `nil` when
    /// zoomed out (the stored `amplitudes` already cover the whole song) or while a
    /// read is in flight — the view falls back to stretching `amplitudes`.
    var detailBars: WaveformDetailBars?

    /// The resolved source file (imported file or demo sample) crisp deep-zoom reads
    /// windowed slices from. Held for the model's lifetime alongside `fileAccess`.
    private(set) var sourceURL: URL?

    /// Debounced windowed-read task and a small insertion-ordered window cache so
    /// paging back and forth reuses prior reads instead of hitting the file again.
    @ObservationIgnored var detailRefreshTask: Task<Void, Never>?
    @ObservationIgnored var detailCache: [String: [Double]] = [:]
    @ObservationIgnored var detailCacheOrder: [String] = []

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

    /// Long-press-drag select (ADR 0005 round 5): the anchor fraction where the
    /// hold fired. The drag extends from here; cleared on commit/cancel.
    @ObservationIgnored var dragSelectAnchor: Double?
    /// True *while* a long-press-drag is being painted, before release. The
    /// `capture` is live (so the green region renders) but the edit toolbar and
    /// transport lock are held back until the drag commits — see `showConfirm`.
    var isDragSelecting = false

    /// A transient "Deleted X · Undo" toast after a destructive action (ADR 0019).
    /// Auto-dismisses after a few seconds; tapping Undo runs its closure.
    var undoToast: UndoToast?
    /// The pending auto-dismiss for `undoToast`, cancelled when it's replaced or acted
    /// on. Internal (not `private`) so the `+Actions` extension in its own file can
    /// manage it; `@ObservationIgnored` so the timer handle isn't observed.
    @ObservationIgnored var undoDismiss: Task<Void, Never>?

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

    /// The visible window of the song (song fractions): the owned `viewportStart`
    /// plus `zoomSpan`, clamped inside `0...1`. Drives both the waveform render and
    /// the minimap box. Paged (not playhead-centred) — see `advancePageIfNeeded`.
    var viewport: (start: Double, end: Double) {
        let span = zoomSpan.clamped(to: 0...1)
        let start = viewportStart.clamped(to: 0...max(0, 1 - span))
        return (start, start + span)
    }

    /// True when zoomed in (showing less than the whole song) — drives the Fit/1×
    /// reset affordance.
    var isZoomed: Bool { zoomSpan < 0.999 }

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

    /// The confirm pill (edit toolbar + transport lock) shows while a region is
    /// captured — but *not* mid-drag-select, where the region is still being
    /// painted and the transport should stay live until release.
    var showConfirm: Bool { capture != nil && !isDragSelecting }

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
        sourceURL = url
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
        sourceURL = sample.url
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
