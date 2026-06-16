import SwiftUI

/// State + behaviour for the practice screen (design brief §4.1), extracted from
/// `WaveformPracticeView` so the view stays thin and the gesture/loop handlers
/// have a shared home (cross-file extensions can't reach a view's `private`
/// `@State`). The view observes this model; the handlers live in
/// `WaveformPracticeModel+Actions.swift`. See docs/decisions/0007.
@MainActor
@Observable
final class WaveformPracticeModel {

    let song = WaveformMock.song

    // UI state.
    var speed: Double = 1.0
    var mode: WaveformPracticeView.InteractionMode = .scroll
    var songInfoExpanded = false   // demoted to the scroll area
    var loopsExpanded = true
    var markersExpanded = false

    // Audio engine + the waveform amplitudes it loaded from the sample.
    let engine = PracticeAudioEngine()
    var amplitudes: [Double] = WaveformMock.song.amplitudes

    // Loops/markers are mutable so they can be activated, renamed and deleted.
    var loops = WaveformMock.song.loops
    var markers = WaveformMock.song.markers
    var activeLoopID: WaveformMock.Loop.ID? = WaveformMock.song.loops.first?.id
    var editingLoop: WaveformMock.Loop?
    var editingMarker: WaveformMock.Marker?

    /// Tap mode: the start of the loop being captured (the green forming
    /// region), awaiting its closing tap.
    var pendingStart: Double?
    /// The captured loop awaiting confirmation (drives the ConfirmBar). Bounds
    /// are mutable so Fine handles drag them live; `fromFine` shows the blue
    /// handles; a non-nil `editingLoopID` means we're adjusting an existing
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
    var activeLoop: WaveformMock.Loop? { loops.first { $0.id == activeLoopID } }

    /// Live playhead as a fraction of the song (0...1), driven by the engine.
    var playheadFraction: Double {
        engine.duration > 0 ? engine.currentTime / engine.duration : 0
    }

    /// Effective song length — the engine's once loaded, else the mock's.
    var duration: TimeInterval {
        engine.duration > 0 ? engine.duration : song.duration
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
    var isRangeEditing: Bool { capture?.editingLoopID != nil }

    /// The confirm pill shows while a region is captured but not yet being named.
    var showConfirm: Bool { capture != nil && namingDraft == nil }

    var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Generate the dev sample and hand it to the engine (skipped in previews).
    func loadSample() async {
        guard !isPreview, engine.duration == 0 else { return }
        guard let sample = try? SampleToneGenerator.makeSample(duration: song.duration) else { return }
        amplitudes = sample.amplitudes
        try? engine.load(url: sample.url)
        engine.setRate(speed)
    }
}
