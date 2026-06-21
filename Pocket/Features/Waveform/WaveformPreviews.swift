import SwiftUI

// Component-level previews for the waveform practice screen. Each one isolates a
// single section so it can be iterated on its own (brief §5 wants each section's
// states designed, not just the happy-path screen). The full-screen preview
// lives next to the screen in `WaveformPracticeView.swift`.
//
// Tip: in Xcode, "pin" any of these (the pin icon in the canvas) so it stays
// live while files are edited elsewhere.

#Preview("Song strip") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SongStrip(song: Song.sample()).padding()
    }
}

#Preview("Song info — expanded") {
    @Previewable @State var expanded = true
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SongInfoPanel(song: Song.sample(), expanded: $expanded).padding()
    }
}

#Preview("Song info — collapsed") {
    @Previewable @State var expanded = false
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SongInfoPanel(song: Song.sample(), expanded: $expanded).padding()
    }
}

#Preview("Speed bar") {
    @Previewable @State var speed = 0.90
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SpeedBar(speed: $speed, displayedBPM: Int((76 * speed).rounded()),
                 onSetBPM: {}, metronomeOn: true,
                 canUseMetronome: true, onToggleMetronome: {}).padding()
    }
}

#Preview("Speed bar — no BPM") {
    @Previewable @State var speed = 0.90
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SpeedBar(speed: $speed, displayedBPM: nil, onSetBPM: {}).padding()
    }
}

#Preview("BPM sheet — tap-tempo (ADR 0024)") {
    BPMSheet(engine: PracticeAudioEngine(), currentBPM: nil, currentDownbeat: nil,
             onCommit: { _, _ in }, onSetOnWaveform: { _ in }, onEstimate: { (124, 0.5) })
        .preferredColorScheme(.dark)
}

#Preview("BPM sheet — prefilled") {
    BPMSheet(engine: PracticeAudioEngine(), currentBPM: 128, currentDownbeat: 1.5,
             onCommit: { _, _ in }, onSetOnWaveform: { _ in }, onEstimate: { (124, 0.5) })
        .preferredColorScheme(.dark)
}

#Preview("Waveform — Navigate") {
    // Overlapping + nested loops to show lane-stacking (ADR 0018): a wide loop
    // with a tight one nested inside, plus an overlapping third, and two markers.
    let loops = [
        Loop(name: "Whole solo", start: 0.18, end: 0.78, speed: 1.0, repeats: 2),
        Loop(name: "Hard lick", start: 0.40, end: 0.50, speed: 0.6, repeats: 6),
        Loop(name: "Outro", start: 0.70, end: 0.92, speed: 0.9, repeats: 2)
    ]
    return ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: Song.sample().amplitudes,
                     detailBars: nil,
                     playheadFraction: 0.35,
                     loop: loops.first,
                     loops: loops,
                     markerFractions: [0.27, 0.6],
                     beats: BeatGrid.beats(bpm: 76, duration: Song.sample().duration, downbeat: 0.3),
                     mode: .navigate, formingStart: nil, fineSelection: nil,
                     tapSelection: nil,
                     playheadLabel: "0:10",
                     onSeek: { _ in },
                     onScrub: { _ in }, onMoveHandle: { _, _ in }, onMoveHandleEnded: {},
                     onSelectBegan: { _ in }, onSelectChanged: { _ in },
                     onSelectEnded: {}, onSelectCancelled: {},
                     viewport: (0, 1), onSetZoomSpan: { _ in }).padding()
    }
}

#Preview("Waveform — beat grid (zoomed)") {
    // Beat grid (ADR 0022): faint per-beat lines with brighter bar-start downbeats,
    // zoomed in so individual beats and bars are clearly spaced. 96 BPM, downbeat at
    // 0.5 s; viewport on the first few bars.
    ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: Song.sample().amplitudes,
                     detailBars: nil,
                     playheadFraction: 0.12,
                     loop: nil,
                     loops: [],
                     markerFractions: [],
                     beats: BeatGrid.beats(bpm: 96, duration: Song.sample().duration, downbeat: 0.5),
                     mode: .navigate, formingStart: nil, fineSelection: nil,
                     tapSelection: nil,
                     playheadLabel: "0:04",
                     onSeek: { _ in },
                     onScrub: { _ in }, onMoveHandle: { _, _ in }, onMoveHandleEnded: {},
                     onSelectBegan: { _ in }, onSelectChanged: { _ in },
                     onSelectEnded: {}, onSelectCancelled: {},
                     viewport: (0.0, 0.25), onSetZoomSpan: { _ in }).padding()
    }
}

#Preview("Waveform — Fine handles") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: Song.sample().amplitudes,
                     detailBars: nil,
                     playheadFraction: 0.35,
                     loop: nil,
                     loops: Song.sample().loops,
                     markerFractions: [],
                     mode: .fine, formingStart: nil, fineSelection: (0.30, 0.62),
                     tapSelection: nil,
                     playheadLabel: "0:10",
                     onSeek: { _ in },
                     onScrub: { _ in }, onMoveHandle: { _, _ in }, onMoveHandleEnded: {},
                     onSelectBegan: { _ in }, onSelectChanged: { _ in },
                     onSelectEnded: {}, onSelectCancelled: {},
                     viewport: (0.25, 0.65), onSetZoomSpan: { _ in }).padding()
    }
}

#Preview("Waveform — zoomed + Fit reset") {
    // Page-mode (ADR 0010): a zoomed window with the playhead mid-sweep and the
    // Fit / 1× reset pill in the top-trailing corner.
    ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: Song.sample().amplitudes,
                     // Crisp re-downsample covering just the zoomed window (ADR 0020):
                     // the full envelope mapped into [0.30, 0.50] reads at full density.
                     detailBars: WaveformDetailBars(bars: Song.sample().amplitudes, start: 0.30, end: 0.50),
                     playheadFraction: 0.40,
                     loop: Song.sample().loops.first,
                     loops: Song.sample().loops,
                     markerFractions: [0.42],
                     mode: .navigate, formingStart: nil, fineSelection: nil,
                     tapSelection: nil,
                     playheadLabel: "0:24",
                     onSeek: { _ in },
                     onScrub: { _ in }, onMoveHandle: { _, _ in }, onMoveHandleEnded: {},
                     onSelectBegan: { _ in }, onSelectChanged: { _ in },
                     onSelectEnded: {}, onSelectCancelled: {},
                     viewport: (0.30, 0.50), onSetZoomSpan: { _ in })
            .overlay(alignment: .bottomTrailing) { ZoomResetButton(action: {}).padding(8) }
            .padding()
    }
}

#Preview("Minimap") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        Minimap(song: Song.sample(),
                activeLoop: Song.sample().loops.first,
                markers: Song.sample().markers,
                fineSelection: nil,
                playheadFraction: 0.35,
                viewport: (0.25, 0.65),
                onSeek: { _ in }).padding()
    }
}

#Preview("Transport bar") {
    @Previewable @State var mode = WaveformPracticeView.InteractionMode.navigate
    ZStack {
        PocketColor.background.ignoresSafeArea()
        TransportBar(isPlaying: false, onPlayPause: {}, mode: $mode,
                     currentTime: 10,
                     loop: Song.sample().loops.first, onClearLoop: {},
                     onDropMarker: {}, onPunch: {}, isPunchActive: false).padding()
    }
}

#Preview("Edit toolbar") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        EditToolbar(isPlaying: false, isEditingExisting: false,
                    onPlayPause: {}, onConfirm: {}, onCancel: {}).padding()
    }
}

#Preview("Marker name sheet") {
    MarkerNameSheet(onSave: { _ in })
}

#Preview("Undo toast") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        UndoToastView(message: "Deleted Chorus bend", onUndo: {}).padding()
    }
}

#Preview("Loops + Markers") {
    @Previewable @State var loopsExpanded = true
    @Previewable @State var markersExpanded = true
    let song = Song.sample()
    ZStack {
        PocketColor.background.ignoresSafeArea()
        VStack(spacing: 16) {
            LoopsPanel(loops: song.loops, expanded: $loopsExpanded,
                       activeLoopID: song.loops.first?.uid, isPlaying: false,
                       onActivate: { _ in }, onEdit: { _ in }, onDelete: { _ in }, onAutomator: { _ in })
            MarkersPanel(markers: song.markers, expanded: $markersExpanded,
                         onSeek: { _ in }, onEdit: { _ in })
        }
        .padding()
    }
}

#Preview("Loops — empty") {
    @Previewable @State var expanded = true
    ZStack {
        PocketColor.background.ignoresSafeArea()
        LoopsPanel(loops: [], expanded: $expanded, activeLoopID: nil, isPlaying: false,
                   onActivate: { _ in }, onEdit: { _ in }, onDelete: { _ in },
                   onAutomator: { _ in }).padding()
    }
}

#Preview("Markers — empty") {
    @Previewable @State var expanded = true
    ZStack {
        PocketColor.background.ignoresSafeArea()
        MarkersPanel(markers: [], expanded: $expanded, onSeek: { _ in }, onEdit: { _ in }).padding()
    }
}

#Preview("Edit loop sheet") {
    LoopEditSheet(loop: Song.sample().loops[0], onDelete: {},
                  onAdjustRange: {})
}

#Preview("Automator sheet") {
    let song = Song.sample()
    let loop = song.loops[0]
    loop.automatorEnabled = true   // so the red "Turn off ramp" button renders too
    return AutomatorSheet(loop: loop, song: song, onSet: {}, onTurnOff: {})
}

#Preview("Loading overlay") {
    let song = Song.sample()
    ZStack {
        PocketColor.background.ignoresSafeArea()
        // Faux practice surface underneath, so the dim + card read realistically.
        VStack(spacing: 16) {
            SongStrip(song: song)
            WaveformView(amplitudes: song.amplitudes,
                         detailBars: nil,
                         playheadFraction: 0.35,
                         loop: song.loops.first,
                         loops: song.loops,
                         markerFractions: song.markers.map { $0.seconds / song.duration },
                         mode: .navigate, formingStart: nil, fineSelection: nil,
                         tapSelection: nil,
                         playheadLabel: "0:10",
                         onSeek: { _ in },
                         onScrub: { _ in }, onMoveHandle: { _, _ in }, onMoveHandleEnded: {},
                         onSelectBegan: { _ in }, onSelectChanged: { _ in },
                         onSelectEnded: {}, onSelectCancelled: {},
                         viewport: (0, 1), onSetZoomSpan: { _ in })
            Spacer()
        }
        .padding()
        AudioLoadingOverlay()
    }
    .preferredColorScheme(.dark)
}
