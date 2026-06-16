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
        SongStrip(song: WaveformMock.song).padding()
    }
}

#Preview("Song info — expanded") {
    @Previewable @State var expanded = true
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SongInfoPanel(song: WaveformMock.song, expanded: $expanded).padding()
    }
}

#Preview("Song info — collapsed") {
    @Previewable @State var expanded = false
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SongInfoPanel(song: WaveformMock.song, expanded: $expanded).padding()
    }
}

#Preview("Speed bar") {
    @Previewable @State var speed = 0.90
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SpeedBar(speed: $speed, displayedBPM: Int((76 * speed).rounded()),
                 onSetBPM: {}).padding()
    }
}

#Preview("Speed bar — no BPM") {
    @Previewable @State var speed = 0.90
    ZStack {
        PocketColor.background.ignoresSafeArea()
        SpeedBar(speed: $speed, displayedBPM: nil, onSetBPM: {}).padding()
    }
}

#Preview("Waveform — Scroll") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: WaveformMock.song.amplitudes,
                     playheadFraction: WaveformMock.song.playheadFraction,
                     loop: WaveformMock.song.activeLoop,
                     mode: .scroll, formingStart: nil, fineSelection: nil,
                     tapSelection: nil,
                     playheadLabel: "0:10",
                     onSeek: { _ in }, onDropMarker: { _ in }, onTapPunch: {},
                     onScrub: { _ in }, onMoveHandle: { _, _ in }).padding()
    }
}

#Preview("Waveform — Fine handles") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        WaveformView(amplitudes: WaveformMock.song.amplitudes,
                     playheadFraction: WaveformMock.song.playheadFraction,
                     loop: nil,
                     mode: .fine, formingStart: nil, fineSelection: (0.30, 0.62),
                     tapSelection: nil,
                     playheadLabel: "0:10",
                     onSeek: { _ in }, onDropMarker: { _ in }, onTapPunch: {},
                     onScrub: { _ in }, onMoveHandle: { _, _ in }).padding()
    }
}

#Preview("Minimap") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        Minimap(song: WaveformMock.song,
                activeLoop: WaveformMock.song.activeLoop,
                markers: WaveformMock.song.markers,
                fineSelection: nil,
                playheadFraction: WaveformMock.song.playheadFraction,
                onSeek: { _ in }).padding()
    }
}

#Preview("Transport bar") {
    @Previewable @State var repeatOn = true
    @Previewable @State var mode = WaveformPracticeView.InteractionMode.scroll
    ZStack {
        PocketColor.background.ignoresSafeArea()
        TransportBar(isPlaying: false, onPlayPause: {}, repeatOn: $repeatOn, mode: $mode,
                     currentTime: WaveformMock.song.playheadSeconds,
                     loop: WaveformMock.song.activeLoop,
                     onClearLoop: {}).padding()
    }
}

#Preview("Confirm popup") {
    ZStack {
        PocketColor.background.ignoresSafeArea()
        ConfirmPopup(isEditing: false, onConfirm: {}, onCancel: {})
    }
}

#Preview("Loop name sheet") {
    LoopNameSheet(range: "0:42–1:08", onSave: { _ in })
}

#Preview("Loops + Markers") {
    @Previewable @State var loopsExpanded = true
    @Previewable @State var markersExpanded = true
    let song = WaveformMock.song
    ZStack {
        PocketColor.background.ignoresSafeArea()
        VStack(spacing: 16) {
            LoopsPanel(loops: song.loops, expanded: $loopsExpanded,
                       activeLoopID: song.loops.first?.id, isPlaying: false,
                       onActivate: { _ in }, onEdit: { _ in })
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
                   onActivate: { _ in }, onEdit: { _ in }).padding()
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
    LoopEditSheet(loop: WaveformMock.song.loops[0], onSave: { _ in }, onDelete: {},
                  onAdjustRange: {})
}
