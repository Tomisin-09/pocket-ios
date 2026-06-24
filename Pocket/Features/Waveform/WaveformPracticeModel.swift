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
    /// True while a finger is down on the waveform (scrub / handle drag). Drives the
    /// swipe-back guard so a scrub near the left edge can't pop the screen (ADR 0030).
    var isScrubbing = false
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

    /// Lock-screen / Control Center bridge (ADR 0025). Owned here because Now
    /// Playing needs both the song's metadata and the engine's transport. Its
    /// command targets are removed in `endPlaybackSession` on screen exit.
    @ObservationIgnored private let nowPlaying = NowPlayingController()
    /// Rate-limits throttled Now Playing pushes (playhead ticks): transport and
    /// rate changes force a push, the 30 Hz playhead does not.
    @ObservationIgnored private var lastNowPlayingPush: Date = .distantPast

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

    /// The active loop, tracked by its stable `Loop.uid`. Starts `nil` on every
    /// screen entry — practice opens on the **full song**, not silently armed to a
    /// saved region (ADR 0029). A loop only arms when you tap its row, punch a new
    /// one, or run an automator.
    var activeLoopID: UUID?
    var editingLoop: Loop?
    var editingMarker: Marker?
    /// The loop whose automator (speed ramp) is being set up (drives the sheet, ADR 0013).
    var editingAutomatorLoop: Loop?
    /// The loop whose practice journal is open (drives the journal sheet, ADR 0038).
    var journalingLoop: Loop?
    /// Drives the tap-tempo / manual BPM sheet (ADR 0024), opened from "Set BPM".
    var settingBPM = false
    /// Drives the read-first `SongDetailsSheet` (Edit → `SongEditSheet`), opened by holding the title.
    var showingSongDetails = false

    /// In-song metronome click (ADR 0026). The click rides `beatGrid` and follows
    /// playback speed; it never alters the song's stored BPM. Only available when the
    /// song has a grid (both tempo and downbeat set).
    var metronomeOn = false

    init(song: Song, context: ModelContext) {
        self.song = song
        self.context = context
        self.amplitudes = song.amplitudes
        // Clean state on entry (ADR 0029): no loop armed — open on the full song.
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

    /// The Fine handle last moved by a drag, so its release can snap *that* edge to a
    /// nearby marker / loop boundary (ADR 0021). Cleared once the release is handled.
    @ObservationIgnored var lastFineHandle: WaveformGesture.Handle?

    /// Long-press-drag select (ADR 0005 round 5): the anchor fraction where the
    /// hold fired. The drag extends from here; cleared on commit/cancel.
    @ObservationIgnored var dragSelectAnchor: Double?
    /// True *while* a long-press-drag is being painted, before release. The
    /// `capture` is live (so the green region renders) but the edit toolbar and
    /// transport lock are held back until the drag commits — see `showConfirm`.
    var isDragSelecting = false

    /// "Set the 1 on the waveform" (ADR 0024): the downbeat fraction being placed by
    /// dragging a handle, snapped to the nearest transient peak on release. Non-nil ⇒
    /// the downbeat-set overlay is active (its own confirm toolbar; the transport locks
    /// like a capture). Confirming writes `Song.downbeatSeconds`; cancelling discards.
    var downbeatDraft: Double?

    /// When the downbeat placement was launched from the BPM sheet ("Set the 1 on the
    /// waveform"), re-present that sheet once the 1 is confirmed/cancelled so the user
    /// lands back in the tempo editor rather than on a bare waveform.
    @ObservationIgnored var resumeBPMSheetAfterDownbeat = false

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

    /// Live **song-time** position (seconds) — what the BPM sheet captures per tap and
    /// when marking the 1. Song-time (not wall-clock) so tapping inside a loop or at a
    /// reduced speed still reads the song's true tempo and phase (ADR 0024).
    var currentSongTime: TimeInterval { engine.currentTime }

    /// The loop currently loaded into the transport/waveform, if any.
    var activeLoop: Loop? { loops.first { $0.uid == activeLoopID } }

    /// The beat grid (ADR 0022): beats + bar-start downbeats as song fractions.
    /// Empty unless the song has **both** a tempo (`bpm`) and a **downbeat anchor**
    /// (`downbeatSeconds`) — BPM fixes the interval, the anchor fixes the phase, and we
    /// don't guess the phase. Drawn faintly on the waveform and fed into the snap
    /// candidates (`snapCandidates`). Assumes 4/4: every 4th beat is a downbeat.
    var beatGrid: [BeatGrid.Beat] {
        guard let bpm = song.tempoBPM, let downbeat = song.downbeatSeconds, duration > 0 else { return [] }
        return BeatGrid.beats(bpm: bpm, duration: duration, downbeat: downbeat)
    }

    // MARK: - Metronome (ADR 0026)

    /// A click can run only when there's a grid — both a tempo and a downbeat anchor.
    /// Drives the transport toggle's enabled state (the button greys out without one).
    var canUseMetronome: Bool { !beatGrid.isEmpty }

    /// Toggle the in-song click. Pushes the current grid to the engine and flips the
    /// click on/off; the engine schedules against the live (rate-following) playhead.
    func toggleMetronome() {
        guard canUseMetronome || metronomeOn else { return }
        metronomeOn.toggle()
        if metronomeOn { pushMetronomeGrid() }
        engine.setMetronome(enabled: metronomeOn)
    }

    /// Hand the engine the beat grid in *source* seconds (fractions × duration). Called
    /// when the click turns on and whenever the grid changes (tempo/downbeat edits).
    func pushMetronomeGrid() {
        let beats = beatGrid.map { (time: $0.fraction * duration, isDownbeat: $0.isDownbeat) }
        engine.setMetronomeBeats(beats)
    }

    // MARK: - Playback lifecycle & Now Playing (ADR 0025)

    /// A snapshot for the lock screen / Control Center, built from the song's
    /// metadata and the engine's live transport.
    private var nowPlayingState: NowPlayingState {
        NowPlayingState(title: song.title, artist: song.artist,
                        duration: duration, elapsedTime: engine.currentTime,
                        isPlaying: engine.isPlaying, speed: speed)
    }

    /// Begin the lock-screen session: wire the remote play/pause commands to the
    /// transport and push the initial metadata. Called once the view appears.
    /// Skipped in previews (no audio session, no command center worth touching).
    func beginPlaybackSession() {
        guard !isPreview else { return }
        nowPlaying.activate(onPlay: { [weak self] in self?.engine.play() },
                            onPause: { [weak self] in self?.engine.pause() },
                            onToggle: { [weak self] in self?.engine.togglePlay() })
        refreshNowPlaying(force: true)
    }

    /// Push current metadata to the lock screen. `force` for transport/rate/seek
    /// events; the un-forced playhead tick is throttled so the 30 Hz timer doesn't
    /// rebuild the info dictionary on every frame (the system extrapolates between
    /// pushes from the elapsed time + reported rate).
    func refreshNowPlaying(force: Bool = false) {
        guard !isPreview else { return }
        let now = Date()
        if !force, now.timeIntervalSince(lastNowPlayingPush) < 0.5 { return }
        lastNowPlayingPush = now
        nowPlaying.update(nowPlayingState)
    }

    /// Stop-on-exit (ADR 0025): remove the remote-command targets, clear the Now
    /// Playing info, and tear the engine down so audio halts immediately as the
    /// screen is dismissed — rather than lingering until the model deallocs (and
    /// the global command center would otherwise keep the engine alive).
    func endPlaybackSession() {
        nowPlaying.teardown()
        engine.stop()
        wipeTransientState()
    }

    /// Wipe-on-exit (ADR 0029): reset the transient practice state so a later entry
    /// can't inherit a stale loop/speed/click. The model is normally recreated per
    /// entry, so this is belt-and-suspenders — but it makes the lifecycle contract
    /// explicit and survives any future model reuse. Persisted song data (BPM,
    /// downbeat, saved loops/markers) is **never** touched — only the session knobs.
    private func wipeTransientState() {
        activeLoopID = nil
        speed = 1.0
        if metronomeOn { metronomeOn = false }
        mode = .navigate
    }

    // MARK: - Derived transport state
    // Automator (per-loop speed ramp, ADR 0013) lives in `+Automator.swift`.

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

    /// True while placing the downbeat on the waveform (ADR 0024) — drives the
    /// downbeat handle, its confirm toolbar, and the transport lock.
    var isSettingDownbeat: Bool { downbeatDraft != nil }

    /// The bars currently drawn on the waveform and the song range they cover: the
    /// crisp zoomed window when present (ADR 0020), else the whole-song envelope. The
    /// downbeat snap searches these, so zooming in sharpens the peaks it can catch.
    var displayedBars: WaveformDetailBars {
        detailBars ?? WaveformDetailBars(bars: amplitudes, start: 0, end: 1)
    }

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
