import SwiftUI

// Portrait and landscape (ADR 0042) compose the same two pieces — the fixed practice
// cockpit and the loops/markers reference list — so the layout lives here as shared views
// rather than duplicated inline in `WaveformPracticeView`.

/// The fixed practice cockpit (brief items 3–8): a header slot (the song strip in portrait,
/// a compact back/title/menu bar in landscape), speed bar, the mode/AB status line, the
/// waveform, ruler, minimap, and transport. `landscape` tightens the rhythm, slims the
/// speed + transport bars, and lets the waveform flex to fill the leftover height so the
/// transport always pins to the bottom (ADR 0042).
struct PracticeCockpit<Header: View>: View {
    @Bindable var model: WaveformPracticeModel
    var landscape: Bool = false
    @ViewBuilder var header: () -> Header
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// P1c — hide the full-song minimap strip when the user turns it off (default on).
    @AppStorage(AppSettings.Key.waveformMinimapVisible)
    private var minimapVisible = AppSettings.waveformMinimapVisibleDefault
    /// P2 — float a marker's label over the timeline as the playhead nears it (default on).
    @AppStorage(AppSettings.Key.waveformMarkerLabels)
    private var markerLabelsVisible = AppSettings.waveformMarkerLabelsDefault

    var body: some View {
        // Derived once per *real* change, not once per display frame. `loops` and `markers`
        // each sort a SwiftData relationship (`Song.loopsByStart` / `markersByTime`); the
        // marker map allocates. None of that may sit on the playhead's path, so the playhead
        // is read only inside `PlayheadWaveform` / `PlayheadMinimap` and these are handed down.
        let loops = model.loops
        let activeLoop = model.activeLoop
        let markers = model.markers
        let waveformMarkers = markers.map {
            WaveformMarker(fraction: $0.seconds / model.duration, label: $0.label)
        }

        return VStack(spacing: landscape ? 8 : 16) {
            header()                                                    // 1
            SpeedBar(speed: $model.speed, displayedBPM: model.displayedBPM, // 3
                     onSetBPM: model.setBPM, onUserAdjust: model.userAdjustedSpeed,
                     metronomeOn: model.metronomeOn,
                     canUseMetronome: model.canUseMetronome,
                     onToggleMetronome: model.toggleMetronome,
                     repeatsSong: model.repeatsSong,
                     canRepeat: model.canRepeatSong,
                     onToggleRepeat: model.toggleRepeatsSong,
                     compact: landscape)
            // 4. Mode instructions — replaced by the AB / downbeat bar while active.
            statusLine
            PlayheadWaveform(model: model,                               // 5
                             loops: loops,
                             activeLoop: activeLoop,
                             markers: waveformMarkers,
                             beats: model.beatGrid,
                             landscape: landscape,
                             showsMarkerLabels: markerLabelsVisible)
            TimeRuler(start: model.viewport.start * model.duration,      // 6
                      end: model.viewport.end * model.duration)
            if minimapVisible {
                PlayheadMinimap(model: model,                            // 7
                                activeLoop: activeLoop,
                                markers: markers)
            }
            transport                                                   // 8
        }
    }

    private var statusLine: some View {
        ZStack {
            if model.isSettingDownbeat {
                DownbeatBar(isPlaying: model.engine.isPlaying,
                            onTogglePlay: model.engine.togglePlay,
                            onCapture: model.captureDownbeatAtPlayhead,
                            onConfirm: model.confirmDownbeat,
                            onCancel: model.cancelSetDownbeat,
                            hasAnchor: model.song.downbeatSeconds != nil,
                            correctionCount: model.song.extraDownbeatSeconds.count,
                            onMove: model.moveDownbeat,
                            onClearCorrections: model.clearDownbeatCorrections)
                    .transition(.opacity)
            } else if model.abActive && !model.isDragSelecting {
                ABSpanBar(isPlaying: model.engine.isPlaying,
                          isSet: model.abSpan.isSet,
                          isEditing: model.isEditingSpan,
                          label: model.abSpanLabel,
                          onAudition: model.auditionABSpan,
                          onSave: model.saveABSpan,
                          onClear: model.clearABSpan)
                    .transition(.opacity)
            } else {
                ModeDescriptionLine(gridAvailable: model.gridAvailable,
                                    gridOn: model.song.showsGridlines,
                                    onToggleGrid: model.toggleGridlines,
                                    needsDownbeat: model.needsDownbeat,
                                    onSetDownbeat: { model.beginSetDownbeat() },
                                    onOpenPlayerSettings: { model.showingPlayerSettings = true })
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.abActive)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isSettingDownbeat)
    }

    private var transport: some View {
        // Greyed + locked only while placing the downbeat (ADR 0024); A/B creation keeps
        // the transport live (ADR 0041).
        TransportBar(isPlaying: model.engine.isPlaying,
                     onPlayPause: model.engine.togglePlay,
                     onRestart: model.transportRestart,
                     onPrevious: model.transportPrevious,
                     onNext: model.transportNext,
                     hasPrevious: model.hasPreviousTarget,
                     hasNext: model.hasNextTarget,
                     onSkip: model.transportSkip(bySeconds:),
                     loop: model.activeLoop,
                     loopColor: model.activeLoopColor,
                     onClearLoop: model.clearActiveLoop,
                     onDropMarker: model.dropMarkerAtPlayhead,
                     onPunch: model.tapAB,
                     isPunchActive: model.abActive,
                     compact: landscape)
            .opacity(model.isSettingDownbeat ? 0.35 : 1)
            .disabled(model.isSettingDownbeat)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isSettingDownbeat)
    }
}

/// The scrollable reference list — loops then markers. Song info was removed here (it lives
/// in the song-details sheet, reached by holding the title) when landscape landed (ADR 0042).
/// Dimmed + disabled while adjusting a loop's range, to focus the waveform.
struct PracticeReference: View {
    @Bindable var model: WaveformPracticeModel
    /// Landscape drawer: render the loop rows in their tighter form (ADR 0042).
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // The selection bar is pinned **outside** the scroll view (ADR 0125): select a
            // row near the bottom of a long list and Delete must still be where it was, not
            // a scroll away back at the top.
            if model.loopSelection.isActive {
                LoopSelectionBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if model.markerSelection.isActive {
                MarkerSelectionBar(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            ScrollView {
                VStack(spacing: 16) {
                    LoopsPanel(loops: model.loops, expanded: $model.loopsExpanded,     // 10
                               activeLoopID: model.activeLoopID, isPlaying: model.engine.isPlaying,
                               onActivate: model.activate, onEdit: model.editLoop,
                               onDelete: model.deleteLoop,
                               onAdjustRange: { model.startRangeEdit($0) },
                               onAutomator: { model.editingAutomatorLoop = StableRef(value: $0) },
                               selection: model.loopSelectionSeam,               // ADR 0125
                               compact: compact)
                    MarkersPanel(markers: model.markers, expanded: $model.markersExpanded, // 11
                                 onSeek: model.seekToMarker, onEdit: { model.editingMarker = StableRef(value: $0) },
                                 onDelete: model.deleteMarker,
                                 selection: model.markerSelectionSeam)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .opacity(model.isRangeEditing ? 0.25 : 1)
        .disabled(model.isRangeEditing)
        .animation(.easeOut(duration: 0.2), value: model.isRangeEditing)
    }
}
