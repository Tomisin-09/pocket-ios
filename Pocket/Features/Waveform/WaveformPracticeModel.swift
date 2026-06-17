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
        if let bookmark = song.ref.bookmark {
            loadImportedFile(bookmark: bookmark)
        } else {
            loadDemoSample()
        }
        engine.setRate(speed)
    }

    /// Resolve the security-scoped bookmark and load the real file. Access is held
    /// open (`securityScopedURL`) for the engine's lazy reads, released on deinit.
    /// `amplitudes` already holds the waveform extracted at import (set in `init`).
    private func loadImportedFile(bookmark: Data) {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              let access = SecurityScopedAccess(url) else { return }
        fileAccess = access
        try? engine.load(url: url)
    }

    /// Generate the dev arpeggio and hand it to the engine (the demo sample).
    private func loadDemoSample() {
        guard let sample = try? SampleToneGenerator.makeSample(duration: song.duration) else { return }
        amplitudes = sample.amplitudes
        try? engine.load(url: sample.url)
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
