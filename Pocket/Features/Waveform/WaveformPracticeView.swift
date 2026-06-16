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
    enum InteractionMode: String, CaseIterable, Identifiable {
        case scroll = "Scroll"
        case tap = "Tap"
        case fine = "Fine"
        var id: String { rawValue }

        /// One-line description shown under the speed bar.
        var blurb: String {
            switch self {
            case .scroll: "Tap to set the playhead · hold to drop a marker"
            case .tap: "Drag to scrub · tap to set loop start, tap again to close"
            case .fine: "Drag the blue handles to fine-tune the loop bounds"
            }
        }
    }

    @State private var model = WaveformPracticeModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                             onSetBPM: model.setBPM)
                    // 4. Mode instructions + the confirm pill (trailing) once captured.
                    HStack(spacing: 8) {
                        ModeDescriptionLine(mode: model.mode)
                        if model.showConfirm {
                            ConfirmPopup(isEditing: model.capture?.editingLoopID != nil,
                                         onConfirm: model.confirmCapture,
                                         onCancel: model.cancelCapture)
                                .transition(reduceMotion ? .opacity
                                            : .scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    WaveformView(amplitudes: model.amplitudes,                   // 5
                                 playheadFraction: model.playheadFraction,
                                 loop: model.activeLoop,
                                 mode: model.mode,
                                 formingStart: model.pendingStart,
                                 fineSelection: model.fineSelection,
                                 tapSelection: model.tapSelection,
                                 playheadLabel: timecode(model.engine.currentTime),
                                 onSeek: model.seekToFraction,
                                 onDropMarker: model.dropMarker,
                                 onTapPunch: model.tapPunch,
                                 onScrub: model.seekToFraction,
                                 onMoveHandle: model.moveFineHandle)
                    TimeRuler(duration: model.duration)                         // 6
                    Minimap(song: model.song, activeLoop: model.activeLoop,     // 7
                            markers: model.markers,
                            fineSelection: model.fineSelection,
                            playheadFraction: model.playheadFraction,
                            onSeek: model.seekToFraction)
                    TransportBar(isPlaying: model.engine.isPlaying,             // 8
                                 onPlayPause: model.engine.togglePlay,
                                 mode: $model.mode,
                                 currentTime: model.engine.currentTime,
                                 loop: model.activeLoop,
                                 onClearLoop: model.clearActiveLoop)
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
                                   onActivate: model.activate, onEdit: { model.editingLoop = $0 })
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
        }
        .preferredColorScheme(.dark)
        .sheet(item: $model.editingLoop) { loop in
            LoopEditSheet(loop: loop, onSave: model.updateLoop, onDelete: { model.deleteLoop(loop) },
                          onAdjustRange: { model.startRangeEdit(loop) })
        }
        .sheet(item: $model.editingMarker) { marker in
            MarkerEditSheet(marker: marker, onSave: model.updateMarker, onDelete: { model.deleteMarker(marker) })
        }
        .sheet(item: $model.namingDraft, onDismiss: model.namingDismissed) { draft in
            LoopNameSheet(range: model.rangeString(draft.start, draft.end), onSave: model.saveNamed)
        }
        .task { await model.loadSample() }
        .onChange(of: model.speed) { _, newValue in model.engine.setRate(newValue) }
        .onChange(of: model.mode) { _, newMode in model.modeChanged(to: newMode) }
    }
}

#Preview {
    WaveformPracticeView()
}
