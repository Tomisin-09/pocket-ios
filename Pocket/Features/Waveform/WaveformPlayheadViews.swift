import SwiftUI

// The playhead moves once per display frame (`DisplayLinkTicker` → `PracticeAudioEngine
// .currentTime`), so *any* body that reads it is re-executed at 60–120 Hz. These three leaves
// exist to own that dependency on behalf of the practice screen: the watcher for the page-mode
// side effect, and the two wrappers for the only views that actually draw a moving playhead.
//
// The rule they enforce: nothing that reads the playhead may also carry sheet presentations,
// derived collections, or sibling controls. `MetronomeView` learned this first — `BeatIndicator`
// is a separate struct there because rebuilding its parent on every beat dismissed an open menu.

/// Owns the practice screen's per-frame playhead dependency so it invalidates *this* struct
/// rather than `WaveformPracticeView`'s root body — which carries seven sheet/cover
/// presentations, and would otherwise re-evaluate every one of their content closures at
/// display rate. That is what made opening song or loop settings during playback feel heavy,
/// and what fought the keyboard when the BPM sheet switched from Tap to Manual.
///
/// Draws nothing: it's attached as a background and exists only for its `onChange`.
struct PlayheadWatcher: View {
    let model: WaveformPracticeModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            // Page-mode (ADR 0010): as the playhead advances, hold the window still until it
            // sweeps to ~90%, then page forward. Only re-anchors at page edges. Also refresh
            // the lock-screen clock (throttled) so a seek shows up there.
            .onChange(of: model.playheadFraction) { _, _ in
                model.advancePageIfNeeded()
                model.refreshNowPlaying()
            }
    }
}

/// The detail waveform plus its zoom-reset overlay. Reads the playhead and the transport clock
/// itself; everything whose derivation costs something — the sorted loops, the mapped markers,
/// the beat grid — arrives as a parameter, computed by `PracticeCockpit`'s body, which no longer
/// runs per frame. Threading them through rather than reading `model` here is the whole point:
/// `model.loops` sorts a SwiftData relationship and `model.beatGrid` builds an array covering
/// the entire song, and neither belongs on a 120 Hz path.
struct PlayheadWaveform: View {
    let model: WaveformPracticeModel
    let loops: [Loop]
    let activeLoop: Loop?
    let markers: [WaveformMarker]
    let beats: [BeatGrid.Beat]
    let landscape: Bool
    let showsMarkerLabels: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WaveformView(amplitudes: model.amplitudes,
                     detailBars: model.detailBars,
                     playheadFraction: model.playheadFraction,
                     loop: activeLoop,
                     loops: loops,
                     markers: markers,
                     beats: beats,
                     showsGrid: model.song.showsGridlines,
                     formingStart: model.formingMarker,
                     tapSelection: model.greenSpan,
                     abSelection: model.isDragSelecting ? nil : model.abSpan.bounds,
                     playheadLabel: timecode(model.engine.currentTime),
                     onSeek: model.seekSnapping,
                     onScrub: model.seekToFraction,
                     onMoveABHandle: model.moveABHandle,
                     onMoveABHandleEnded: model.endABHandle,
                     onSnapSuspended: { haptic(.medium) },
                     onSelectBegan: model.beginDragSelection,
                     onSelectChanged: model.updateDragSelection,
                     onSelectEnded: model.endDragSelection,
                     onSelectCancelled: model.cancelDragSelection,
                     viewport: model.viewport,
                     onSetZoom: model.setZoom,
                     downbeatDraft: model.downbeatDraft,
                     onDownbeatMove: model.moveDownbeatDraft,
                     onDownbeatEnded: model.endDownbeatDrag,
                     onTouchBegan: model.beginWaveformTouch,
                     onTouchEnded: model.endWaveformTouch,
                     fillsHeight: landscape,
                     showsMarkerLabels: showsMarkerLabels)
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
}

/// The full-song minimap strip. Same split as `PlayheadWaveform`: the playhead is read here,
/// the sorted markers arrive as a parameter.
struct PlayheadMinimap: View {
    let model: WaveformPracticeModel
    let activeLoop: Loop?
    let markers: [Marker]

    var body: some View {
        Minimap(song: model.song,
                activeLoop: activeLoop,
                samples: model.amplitudes,
                markers: markers,
                fineSelection: model.abSpan.bounds,
                playheadFraction: model.playheadFraction,
                viewport: model.viewport,
                onSeek: model.seekToFraction,
                onSeekEnded: model.seekMinimapSnapping)
    }
}
