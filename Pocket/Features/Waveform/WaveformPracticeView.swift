import SwiftData
import SwiftUI

/// The core practice screen (design brief §4.1): a fixed practice cockpit over a
/// scrollable reference area, driven (for now) by mock song data plus a generated
/// dev audio sample. Real playback runs through `PracticeAudioEngine`; the three
/// transport modes are live as a gesture engine (Scroll/Tap/Fine — ADRs 0003,
/// 0005). Loop capture is a keyboard-free confirm step then a naming sheet.
///
/// State + handlers live in `WaveformPracticeModel` (ADR 0007); this view is the
/// thin body that observes and binds to it. Sections live in
/// `WaveformSections.swift`; shared chrome in `WaveformChrome.swift`.
struct WaveformPracticeView: View {

    /// Transport interaction modes — pills in the transport bar (brief §4.1).
    enum InteractionMode: String {
        case navigate = "Navigate"
        case fine = "Fine"

        /// One-line hint shown under the speed bar (when not editing a capture).
        var blurb: String {
            switch self {
            case .navigate: "Tap to seek · drag to scrub · pinch to zoom"
            case .fine: "Drag the blue handles to set the loop bounds"
            }
        }
    }

    @State private var model: WaveformPracticeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(song: Song, context: ModelContext) {
        _model = State(initialValue: WaveformPracticeModel(song: song, context: context))
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed practice surface — the controls you touch constantly,
                // pinned so they never scroll away (brief items 1, 3–8).
                VStack(spacing: 16) {
                    SongStrip(song: model.song)                                  // 1
                    SpeedBar(speed: $model.speed, displayedBPM: model.displayedBPM, // 3
                             onSetBPM: model.setBPM, onUserAdjust: model.userAdjustedSpeed)
                    // 4. Mode instructions — replaced by the edit toolbar (audition
                    //    + state label + Y/N) while a loop is captured.
                    ZStack {
                        if model.showConfirm {
                            EditToolbar(isPlaying: model.engine.isPlaying,
                                        isEditingExisting: model.capture?.editingLoop != nil,
                                        onPlayPause: model.auditionCapture,
                                        onConfirm: model.confirmCapture,
                                        onCancel: model.cancelCapture)
                                .transition(.opacity)
                        } else {
                            ModeDescriptionLine(mode: model.mode)
                                .transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.showConfirm)
                    WaveformView(amplitudes: model.amplitudes,                   // 5
                                 playheadFraction: model.playheadFraction,
                                 loop: model.activeLoop,
                                 loops: model.loops,
                                 markerFractions: model.markers.map { $0.seconds / model.duration },
                                 mode: model.mode,
                                 formingStart: model.pendingStart,
                                 fineSelection: model.fineSelection,
                                 tapSelection: model.tapSelection,
                                 playheadLabel: timecode(model.engine.currentTime),
                                 onSeek: model.seekToFraction,
                                 onScrub: model.seekToFraction,
                                 onMoveHandle: model.moveFineHandle,
                                 onMoveHandleEnded: model.previewCapture,
                                 viewport: model.viewport,
                                 onSetZoomSpan: model.setZoomSpan)
                    TimeRuler(start: model.viewport.start * model.duration,      // 6
                              end: model.viewport.end * model.duration)
                    Minimap(song: model.song, activeLoop: model.activeLoop,     // 7
                            markers: model.markers,
                            fineSelection: model.fineSelection,
                            playheadFraction: model.playheadFraction,
                            viewport: model.viewport,
                            onSeek: model.seekToFraction)
                    // Greyed + locked while editing — controls move to the edit
                    //    toolbar (you leave edit mode via Y/N, not the mode pills).
                    TransportBar(isPlaying: model.engine.isPlaying,             // 8
                                 onPlayPause: model.engine.togglePlay,
                                 mode: $model.mode,
                                 currentTime: model.engine.currentTime,
                                 loop: model.activeLoop,
                                 onClearLoop: model.clearActiveLoop,
                                 onDropMarker: model.dropMarkerAtPlayhead,
                                 onPunch: model.tapPunch,
                                 isPunchActive: model.pendingStart != nil)
                        .opacity(model.showConfirm ? 0.35 : 1)
                        .disabled(model.showConfirm)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.showConfirm)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Hairline boundary between the fixed surface and the scroll area.
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                // Scrollable reference — loops, markers, then song info (demoted
                // to the bottom, collapsed by default). Dimmed + disabled while
                // adjusting a loop's range, to focus the waveform.
                ScrollView {
                    VStack(spacing: 16) {
                        LoopsPanel(loops: model.loops, expanded: $model.loopsExpanded,     // 10
                                   activeLoopID: model.activeLoopID, isPlaying: model.engine.isPlaying,
                                   onActivate: model.activate, onEdit: { model.editingLoop = $0 },
                                   onAutomator: { model.editingAutomatorLoop = $0 })
                        MarkersPanel(markers: model.markers, expanded: $model.markersExpanded, // 11
                                     onSeek: model.seekToMarker, onEdit: { model.editingMarker = $0 })
                        SongInfoPanel(song: model.song, expanded: $model.songInfoExpanded) // 2
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .opacity(model.isRangeEditing ? 0.25 : 1)
                .disabled(model.isRangeEditing)
                .animation(.easeOut(duration: 0.2), value: model.isRangeEditing)
            }

            // Dim + spinner while the audio opens, so a slow file read reads as
            // "loading" rather than "frozen" (and blocks taps on half-ready controls).
            if model.isLoadingAudio {
                AudioLoadingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isLoadingAudio)
        .preferredColorScheme(.dark)
        .sheet(item: $model.editingLoop) { loop in
            LoopEditSheet(loop: loop, onDelete: { model.deleteLoop(loop) },
                          onAdjustRange: { model.startRangeEdit(loop) })
        }
        .sheet(item: $model.editingMarker) { marker in
            MarkerEditSheet(marker: marker, onDelete: { model.deleteMarker(marker) })
        }
        .sheet(item: $model.namingMarker) { _ in
            MarkerNameSheet(onSave: model.saveMarkerName)
        }
        .sheet(item: $model.namingDraft, onDismiss: model.namingDismissed) { _ in
            LoopNameSheet(onSave: model.saveNamed)
        }
        .sheet(item: $model.editingAutomatorLoop) { loop in
            AutomatorSheet(loop: loop, song: model.song,
                           onSet: { model.startAutomator(for: loop) },
                           onTurnOff: { model.turnOffAutomator(for: loop) })
        }
        .task { await model.loadAudio() }
        .onChange(of: model.speed) { _, newValue in model.engine.setRate(newValue) }
        .onChange(of: model.mode) { _, newMode in model.modeChanged(to: newMode) }
        // Per-loop automator: step the speed as the active loop wraps, and snap to the
        // ramp's current step when playback (re)starts (ADR 0013).
        .onChange(of: model.engine.loopIteration) { _, iteration in
            model.automatorAdvance(toLoopIteration: iteration)
        }
        .onChange(of: model.engine.isPlaying) { _, playing in
            if playing { model.automatorAdvance(toLoopIteration: model.engine.loopIteration) }
        }
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    container.mainContext.insert(song)
    return WaveformPracticeView(song: song, context: container.mainContext)
        .modelContainer(container)
}
