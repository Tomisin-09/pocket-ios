import SwiftData
import SwiftUI

/// **Map the song** (ADR 0232): the song's loops laid out as pieces, section by section, on a chords
/// lane and a notes lane. Opened full screen from Song details (D1).
///
/// Nothing here is stored: the board is drawn from the loops, their pieces and the markers each time,
/// by `SongMapLayout`, so it can't drift from them. Tapping a piece opens its tab; holding it offers the
/// tab and the modes it can open in (D2). A section heading or a pin opens its marker, where **Starts a
/// section** lives (D6).
struct SongMapView: View {
    let song: Song
    /// Pause whatever else is playing before a piece opens: the practice screen's waveform, when the
    /// map was reached from there. Ear training plays the loop itself.
    var onOpenNestedAudio: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    /// The loop being opened, and in which mode. By uid, never the model (ADR 0090).
    @State private var opening: Opening?
    /// The loop whose tab is showing.
    @State private var viewing: StableRef<Loop>?
    /// A mode picked on the tab sheet, opened once the sheet has gone: a push can't start under a sheet.
    @State private var openAfterSheet: Opening?
    @State private var editingMarker: StableRef<Marker>?

    struct Opening: Equatable {
        let uid: UUID
        let mode: LoopRunMode
    }

    var body: some View {
        let map = SongMapLayout.build(SongMapInput(song: song))
        let loops = Dictionary(song.loops.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header(map)
                    ForEach(map.sections) { section in
                        SongMapSectionView(section: section, map: map, loops: loops,
                                           actions: SongMapActions(view: view, open: open,
                                                                   openMarker: openMarker))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PocketColor.background)
            .navigationTitle(song.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(isPresented: Binding(get: { opening != nil },
                                                        set: { if !$0 { opening = nil } })) {
                if let opening, let loop = loops[opening.uid] {
                    JournalOwnerDestinationView(route: .loop(loop, opening.mode))
                }
            }
        }
        // At the root, never on a row: a presentation raised from a row can lose its write (iOS 18).
        .sheet(item: $editingMarker) { ref in
            MarkerEditSheet(marker: ref.value, onDelete: nil)
        }
        .sheet(item: $viewing, onDismiss: openPicked) { ref in
            if let piece = map.pieces[ref.value.uid] {
                SongMapPieceSheet(loop: ref.value, piece: piece, place: place(of: piece, in: map),
                                  onOpen: { mode in
                                      openAfterSheet = Opening(uid: ref.value.uid, mode: mode)
                                      viewing = nil
                                  })
            }
        }
    }

    // MARK: - Pieces

    private func header(_ map: SongMap) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(facts(map))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                Spacer(minLength: 0)
                barsChip
            }
            Text(map.pieces.isEmpty
                 ? "No loops yet. Every loop you make on this song appears here, where it plays."
                 : "Each loop sits where it plays. Tap one for its tab, or hold it to work on it.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// The artist, and what the rows are measured in.
    private func facts(_ map: SongMap) -> String {
        var parts = [song.artist].filter { !$0.isEmpty }
        switch map.scale {
        case .bars:
            if let bpm = song.bpm { parts.append("\(bpm) BPM") }
            parts.append("\(song.beatsPerBar)/\(song.noteValue)")
        case .seconds:
            parts.append(SongMapInput.hasGrid(song) ? "In seconds, bars hidden" : "In seconds, no tempo set")
        }
        return parts.joined(separator: " · ")
    }

    private func view(_ uid: UUID) {
        guard let loop = song.loops.first(where: { $0.uid == uid }) else { return }
        viewing = StableRef(value: loop)
    }

    private func open(_ uid: UUID, in mode: LoopRunMode) {
        guard let loop = song.loops.first(where: { $0.uid == uid }), LoopModeAccess.allows(mode, loop) else { return }
        onOpenNestedAudio()
        opening = Opening(uid: uid, mode: mode)
    }

    private func openPicked() {
        guard let picked = openAfterSheet else { return }
        openAfterSheet = nil
        open(picked.uid, in: picked.mode)
    }

    /// *Notes · Bars 9–11*, or *Notes · 0:23–0:45* in seconds scale.
    private func place(of piece: SongMap.Piece, in map: SongMap) -> String {
        let span: String
        if let bars = map.bars(of: piece) {
            span = bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
        } else {
            span = "\(timecode(piece.start))–\(timecode(piece.end))"
        }
        return "\(SongMapStyle.name(piece.layer)) · \(span)"
    }

    private func openMarker(_ uid: UUID) {
        guard let marker = song.markers.first(where: { $0.uid == uid }) else { return }
        editingMarker = StableRef(value: marker)
    }

    /// Bars come from the song's grid, and the switch is the song's own (D5), so hiding them here hides
    /// the waveform's gridlines too: the same chip as the waveform's **Grid**. Offered only when there's
    /// a grid to show.
    @ViewBuilder private var barsChip: some View {
        if SongMapInput.hasGrid(song) {
            ToggleChip(isOn: song.showsGridlines, tint: PocketColor.active,
                       action: { song.showsGridlines.toggle() }, content: {
                Label("Bars", systemImage: "grid")
                    .font(.futura(.footnote, weight: .medium))
            })
            .accessibilityLabel(song.showsGridlines ? "Show seconds" : "Show bars")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
    }
}

/// What the board's controls do, handed down to every row rather than three closures apiece.
struct SongMapActions {
    /// Tap a piece: its tab.
    let view: (UUID) -> Void
    /// A mode picked from a piece's hold menu.
    let open: (UUID, LoopRunMode) -> Void
    /// Tap a section heading or a pin.
    let openMarker: (UUID) -> Void
}

/// The colours of the two layers (ADR 0232 D2): Indigo for chords, Teal for notes. Lane colours only,
/// never a status (D4).
enum SongMapStyle {
    static func tint(_ layer: SongMap.Layer) -> Color {
        switch layer {
        case .chords: PocketColor.toolkit
        case .notes: PocketColor.practice
        }
    }

    static func name(_ layer: SongMap.Layer) -> String {
        switch layer {
        case .chords: "Chords"
        case .notes: "Notes"
        }
    }
}

#Preview("Map the song") {
    SongMapView(song: SongMapPreview.song())
        .modelContainer(for: Song.self, inMemory: true)
}
