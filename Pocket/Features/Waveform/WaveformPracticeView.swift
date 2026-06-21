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
            case .navigate: "Tap seek · drag scrub · hold-drag to select a loop · pinch zoom"
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
                        if model.isSettingDownbeat {
                            DownbeatBar(onConfirm: model.confirmDownbeat,
                                        onCancel: model.cancelSetDownbeat)
                                .transition(.opacity)
                        } else if model.showConfirm {
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
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isSettingDownbeat)
                    WaveformView(amplitudes: model.amplitudes,                   // 5
                                 detailBars: model.detailBars,
                                 playheadFraction: model.playheadFraction,
                                 loop: model.activeLoop,
                                 loops: model.loops,
                                 markerFractions: model.markers.map { $0.seconds / model.duration },
                                 beats: model.beatGrid,
                                 mode: model.mode,
                                 formingStart: model.pendingStart,
                                 fineSelection: model.fineSelection,
                                 tapSelection: model.tapSelection,
                                 playheadLabel: timecode(model.engine.currentTime),
                                 onSeek: model.seekSnapping,
                                 onScrub: model.seekToFraction,
                                 onMoveHandle: model.moveFineHandle,
                                 onMoveHandleEnded: model.endMoveHandle,
                                 onSelectBegan: model.beginDragSelection,
                                 onSelectChanged: model.updateDragSelection,
                                 onSelectEnded: model.endDragSelection,
                                 onSelectCancelled: model.cancelDragSelection,
                                 viewport: model.viewport,
                                 onSetZoomSpan: model.setZoomSpan,
                                 downbeatDraft: model.downbeatDraft,
                                 onDownbeatMove: model.moveDownbeatDraft,
                                 onDownbeatEnded: model.endDownbeatDrag)
                        // Fit / 1× reset — only while zoomed; sits above the
                        //    waveform's gestures so its tap wins (ADR 0010). Pinned
                        //    bottom-trailing so it clears the top-pinned time bubble,
                        //    which slides along the top edge toward the song's end.
                        .overlay(alignment: .bottomTrailing) {
                            if model.isZoomed {
                                ZoomResetButton(action: model.resetZoom)
                                    .padding(8)
                                    .transition(.opacity)
                            }
                        }
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isZoomed)
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
                        .opacity(model.showConfirm || model.isSettingDownbeat ? 0.35 : 1)
                        .disabled(model.showConfirm || model.isSettingDownbeat)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.showConfirm)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isSettingDownbeat)
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
        .overlay(alignment: .bottom) {
            if let toast = model.undoToast {
                UndoToastView(message: toast.message, onUndo: model.performUndo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
        .sheet(item: $model.editingAutomatorLoop) { loop in
            AutomatorSheet(loop: loop, song: model.song,
                           onSet: { model.startAutomator(for: loop) },
                           onTurnOff: { model.turnOffAutomator(for: loop) })
        }
        .sheet(isPresented: $model.settingBPM) {
            BPMSheet(engine: model.engine, currentBPM: model.song.tempoBPM,
                     onCommit: model.commitTempo,
                     onSetOnWaveform: { bpm in
                         model.commitTempo(bpm: bpm, downbeat: nil)
                         model.beginSetDownbeat()
                     },
                     onEstimate: {
                         await model.estimateTempoFromAudio().map { ($0.bpm, $0.downbeatSeconds) }
                     })
        }
        .task { await model.loadAudio(); model.beginPlaybackSession() }
        // Stop-on-exit (ADR 0025): halt playback and remove the lock-screen command
        // targets when leaving the screen, so audio stops and nothing keeps the
        // engine alive via the global command center.
        .onDisappear { model.endPlaybackSession() }
        // Page-mode (ADR 0010): as the playhead advances, hold the window still until
        // it sweeps to ~90%, then page forward. Only re-anchors at page edges. Also
        // refresh the lock-screen clock (throttled) so a seek shows up there.
        .onChange(of: model.playheadFraction) { _, _ in
            model.advancePageIfNeeded()
            model.refreshNowPlaying()
        }
        // Crisp deep-zoom (ADR 0020): re-downsample the visible window when the
        // viewport changes. `viewport` is derived purely from these two, both Equatable.
        .onChange(of: model.zoomSpan) { _, _ in model.scheduleDetailRefresh() }
        .onChange(of: model.viewportStart) { _, _ in model.scheduleDetailRefresh() }
        .onChange(of: model.speed) { _, newValue in
            model.engine.setRate(newValue)
            model.refreshNowPlaying(force: true)   // rate change re-anchors the lock-screen clock
        }
        .onChange(of: model.mode) { _, newMode in model.modeChanged(to: newMode) }
        // Per-loop automator: step the speed as the active loop wraps, and snap to the
        // ramp's current step when playback (re)starts (ADR 0013).
        .onChange(of: model.engine.loopIteration) { _, iteration in
            model.automatorAdvance(toLoopIteration: iteration)
        }
        .onChange(of: model.engine.isPlaying) { _, playing in
            if playing { model.automatorAdvance(toLoopIteration: model.engine.loopIteration) }
            model.refreshNowPlaying(force: true)   // play/pause flips the lock-screen control + clock
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
