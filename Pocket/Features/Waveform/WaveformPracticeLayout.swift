import SwiftUI

// Portrait and landscape (ADR 0042) compose the same two pieces — the fixed practice
// cockpit and the loops/markers reference list — so the layout lives here as shared views
// rather than duplicated inline in `WaveformPracticeView`.

/// The fixed practice cockpit (brief items 1, 3–8): song strip, speed bar, the mode/AB
/// status line, the waveform, ruler, minimap, and transport. `spacing` tightens the
/// vertical rhythm in landscape, where height is scarce.
struct PracticeCockpit: View {
    @Bindable var model: WaveformPracticeModel
    var spacing: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: spacing) {
            SongStrip(song: model.song,                                  // 1
                      onHoldTitle: { model.showingSongDetails = true })
            SpeedBar(speed: $model.speed, displayedBPM: model.displayedBPM, // 3
                     onSetBPM: model.setBPM, onUserAdjust: model.userAdjustedSpeed,
                     metronomeOn: model.metronomeOn,
                     canUseMetronome: model.canUseMetronome,
                     onToggleMetronome: model.toggleMetronome)
            // 4. Mode instructions — replaced by the AB / downbeat bar while active.
            statusLine
            waveform                                                    // 5
            TimeRuler(start: model.viewport.start * model.duration,      // 6
                      end: model.viewport.end * model.duration)
            Minimap(song: model.song, activeLoop: model.activeLoop,     // 7
                    markers: model.markers,
                    fineSelection: model.abSpan.bounds,
                    playheadFraction: model.playheadFraction,
                    viewport: model.viewport,
                    onSeek: model.seekToFraction,
                    onSeekEnded: model.seekMinimapSnapping)
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
                            onCancel: model.cancelSetDownbeat)
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
                ModeDescriptionLine()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.abActive)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isSettingDownbeat)
    }

    private var waveform: some View {
        WaveformView(amplitudes: model.amplitudes,
                     detailBars: model.detailBars,
                     playheadFraction: model.playheadFraction,
                     loop: model.activeLoop,
                     loops: model.loops,
                     markerFractions: model.markers.map { $0.seconds / model.duration },
                     beats: model.beatGrid,
                     formingStart: model.formingMarker,
                     tapSelection: model.greenSpan,
                     abSelection: model.isDragSelecting ? nil : model.abSpan.bounds,
                     playheadLabel: timecode(model.engine.currentTime),
                     onSeek: model.seekSnapping,
                     onScrub: model.seekToFraction,
                     onMoveABHandle: model.moveABHandle,
                     onMoveABHandleEnded: model.endABHandle,
                     onLiftLoopEdge: model.liftActiveLoopToSpan,
                     onSelectBegan: model.beginDragSelection,
                     onSelectChanged: model.updateDragSelection,
                     onSelectEnded: model.endDragSelection,
                     onSelectCancelled: model.cancelDragSelection,
                     viewport: model.viewport,
                     onSetZoomSpan: model.setZoomSpan,
                     downbeatDraft: model.downbeatDraft,
                     onDownbeatMove: model.moveDownbeatDraft,
                     onDownbeatEnded: model.endDownbeatDrag,
                     onTouchBegan: model.beginWaveformTouch,
                     onTouchEnded: model.endWaveformTouch)
            // Fit / 1× reset — only while zoomed; sits above the waveform's gestures so
            // its tap wins (ADR 0010). Pinned bottom-trailing, clear of the time bubble.
            .overlay(alignment: .bottomTrailing) {
                if model.isZoomed {
                    ZoomResetButton(action: model.resetZoom)
                        .padding(8)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isZoomed)
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
                     currentTime: model.engine.currentTime,
                     loop: model.activeLoop,
                     loopColor: model.activeLoopColor,
                     onClearLoop: model.clearActiveLoop,
                     onDropMarker: model.dropMarkerAtPlayhead,
                     onPunch: model.tapAB,
                     isPunchActive: model.abActive)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LoopsPanel(loops: model.loops, expanded: $model.loopsExpanded,     // 10
                           activeLoopID: model.activeLoopID, isPlaying: model.engine.isPlaying,
                           onActivate: model.activate, onEdit: { model.editingLoop = $0 },
                           onDelete: model.deleteLoop,
                           onJournal: { model.journalingLoop = $0 },
                           onAutomator: { model.editingAutomatorLoop = $0 })
                MarkersPanel(markers: model.markers, expanded: $model.markersExpanded, // 11
                             onSeek: model.seekToMarker, onEdit: { model.editingMarker = $0 },
                             onDelete: model.deleteMarker)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .opacity(model.isRangeEditing ? 0.25 : 1)
        .disabled(model.isRangeEditing)
        .animation(.easeOut(duration: 0.2), value: model.isRangeEditing)
    }
}
