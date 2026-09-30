import SwiftData
import SwiftUI

/// **Map the song** (ADR 0232): the song's loops laid out as pieces, section by section, on a chords
/// lane and a notes lane. Opened full screen from Song details (D1).
///
/// Nothing here is stored: the board is drawn from the loops, their pieces and the markers each time,
/// by `SongMapLayout`, so it can't drift from them. Tapping a piece opens its tab; holding it offers the
/// tab and the modes it can open in (D2). A section heading or a pin opens its marker, where **Starts a
/// section** lives (D6). **Pieces | Tab** are two views of the one layout (D10): the Tab view draws the
/// song's chart from the same pieces, and tapping one of its rows comes back here, to the pieces that
/// drew it.
///
/// **It adds, and never deletes** (D17). A piece made in a gap, or copied (D16), can be taken back with
/// Undo while it's new; a loop made on the waveform can't be removed from here. **Put it together** (D11)
/// picks pieces to make a routine of, opened for review (`SongMapView+Together`).
struct SongMapView: View {
    let song: Song
    /// Pause whatever else is playing before a piece opens: the practice screen's waveform, when the
    /// map was reached from there. Ear training plays the loop itself.
    var onOpenNestedAudio: () -> Void = {}
    /// Close the map and go to the song's waveform, where the tempo and the 1 are set (D7). `nil` where
    /// there's no way there, and the Tab view just says what's missing.
    var onShowWaveform: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @State private var mode: Mode = .pieces
    /// Pieces just reached from a row of the Tab view, drawn heavier for a moment.
    @State var highlighted: Set<UUID> = []
    /// The board row to scroll to once the board is back in place of the tab.
    @State var scrollTarget: SongMapAnchor?
    /// The loop being opened, and in which mode. By uid, never the model (ADR 0090).
    @State private var opening: Opening?
    /// The loop whose tab is showing.
    @State private var viewing: StableRef<Loop>?
    /// A mode picked on the tab sheet, opened once the sheet has gone: a push can't start under a sheet.
    @State private var openAfterSheet: Opening?
    @State private var editingMarker: StableRef<Marker>?
    /// The gap *Make a piece here* is being offered for (D9).
    @State var makingPiece: SongMap.Gap?
    /// *Use your markers as sections?* (D7): the list is open, or the offer was just answered here.
    @State private var choosingSections = false
    @State var sectionOfferAnswered = false
    /// The piece *Copy to…* is finding places for (D16). By uid, never the model (ADR 0090).
    @State var copying: CopySource?
    /// *Copy to…* picked on the tab sheet, opened once the sheet has gone.
    @State private var copyAfterSheet: UUID?
    /// What the map just made, which Undo takes back (D17), until the player does something else.
    @State var made: Made?
    /// Picking pieces to put together (D11): the ones picked, or `nil` when not picking.
    @State var selection: Set<UUID>?
    /// The command tempos Put it together is asking for (D11).
    @State var askingCommands: TogetherAsk?
    /// What was asked, begun once the sheet has gone.
    @State var beginAfterSheet: TogetherBegin?
    /// The routine Put it together made, open for review (D11).
    @State var reviewing: TogetherReview?
    @Environment(\.isPro) var isPro
    @Environment(\.presentPaywall) var presentPaywall

    struct Opening: Equatable {
        let uid: UUID
        let mode: LoopRunMode
    }

    struct CopySource: Identifiable {
        let uid: UUID
        var id: UUID { uid }
    }

    struct Made: Equatable {
        let id = UUID()
        let message: String
        let uids: Set<UUID>
    }

    enum Mode: Hashable { case pieces, tab }

    var body: some View {
        let input = SongMapInput(song: song)
        let map = SongMapLayout.build(input)
        let loops = Dictionary(song.loops.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let tab = mode == .tab ? SongTabLayout.build(map, spelling: spelling) : nil
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // Not lazy: the Tab view scrolls the board to a row, which has to exist to be found.
                    VStack(alignment: .leading, spacing: 24) {
                        header(map, tab: tab)
                        if offersSections(input) {
                            SongMapSectionOffer(onChoose: { choosingSections = true },
                                                onNotNow: answerSectionOffer)
                        }
                        if let tab {
                            SongTabView(tab: tab, openMarker: openMarker, showSection: showSection,
                                        onShowPieces: { showPieces(of: $0, in: map) })
                        } else {
                            ForEach(map.sections) { section in
                                SongMapSectionView(section: section, map: map, loops: loops,
                                                   actions: SongMapActions(view: view, open: open,
                                                                           openMarker: openMarker,
                                                                           showSection: showSection,
                                                                           setRepeats: setRepeats,
                                                                           makePiece: offerPiece,
                                                                           copy: startCopy,
                                                                           putTogether: startTogether,
                                                                           toggle: toggleSelected),
                                                   highlighted: highlighted, selected: selection)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    // Next turn of the run loop, once the board has been laid out in the tab's place.
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                        scrollTarget = nil
                    }
                }
            }
            .background(PocketColor.background)
            .overlay(alignment: .bottom) { undoBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { pickingBar(map) }
            .safeAreaInset(edge: .top, spacing: 0) { modePicker }
            .navigationTitle(song.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(isPresented: Binding(get: { opening != nil },
                                                        set: { if !$0 { opening = nil } })) {
                if let opening, let loop = loops[opening.uid] {
                    JournalOwnerDestinationView(route: .loop(loop, opening.mode))
                }
            }
            .navigationDestination(isPresented: Binding(get: { reviewing != nil },
                                                        set: { if !$0 { finishReview() } })) { togetherReview }
        }
        // At the root, never on a row: a presentation raised from a row can lose its write (iOS 18).
        .sheet(item: $editingMarker) { ref in
            MarkerEditSheet(marker: ref.value, onDelete: nil)
        }
        .sheet(isPresented: $choosingSections) {
            SongMapSectionsSheet(markers: song.markers, duration: song.duration, onUse: answerSectionOffer)
        }
        .confirmationDialog(makingPiece?.name ?? "", isPresented: Binding(get: { makingPiece != nil },
                                                                          set: { if !$0 { makingPiece = nil } }),
                            titleVisibility: .visible, presenting: makingPiece) { gap in
            Button("Make a piece here") { make(gap) }
            // Or start from a piece already counted on this lane (D16).
            ForEach(SongMapCopy.sources(for: gap, in: map), id: \.uid) { source in
                Button("Copy \(source.name) here") {
                    copy(source.uid, into: [SongMapCopy.target(for: gap)], grid: map.grid)
                }
            }
        } message: { gap in
            Text("A new loop \(span(of: gap, in: map)), on the \(gap.layer.name) lane. "
                 + (SongMapCopy.sources(for: gap, in: map).isEmpty
                    ? "Count it in Train your ear and it fills in here."
                    : "Count it in Train your ear, or start from a copy of a piece you've counted."))
        }
        .sheet(item: $viewing, onDismiss: openPicked) { ref in
            if let piece = map.pieces[ref.value.uid] {
                SongMapPieceSheet(loop: ref.value, piece: piece, place: place(of: piece, in: map),
                                  onOpen: { mode in
                                      openAfterSheet = Opening(uid: ref.value.uid, mode: mode)
                                      viewing = nil
                                  }, repeatLine: map.repeatLine(for: piece),
                                  onCopy: piece.canCopy ? {
                                      copyAfterSheet = ref.value.uid
                                      viewing = nil
                                  } : nil)
            }
        }
        .sheet(item: $askingCommands, onDismiss: beginAfterAsking) { ask in
            SongMapCommandSheet(rows: ask.rows) { commands in
                beginAfterSheet = TogetherBegin(plan: ask.plan, commands: commands)
                askingCommands = nil
            }
        }
        .onChange(of: mode) { selection = nil }
        .sheet(item: $copying) { source in
            if let piece = map.pieces[source.uid] {
                SongMapCopySheet(piece: piece, map: map) { copy(source.uid, into: $0, grid: map.grid) }
            }
        }
        .task(id: highlighted) {
            guard !highlighted.isEmpty else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            withAnimation(.easeOut(duration: 0.4)) { highlighted = [] }
        }
        .task(id: made?.id) {
            guard made != nil else { return }
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            withAnimation(.easeOut(duration: 0.2)) { made = nil }
        }
    }

    /// The song's key spells its names, as it does everywhere a piece is read (ADR 0123).
    private var spelling: NoteSpelling {
        NoteSpelling.forMusicalKey(song.musicalKey) ?? AppSettings.accidentalPreference
    }

    // MARK: - Pieces | Tab

    /// Pinned under the title, so either view is one tap away wherever you've scrolled to (D13).
    private var modePicker: some View {
        Picker("View", selection: $mode) {
            Text("Pieces").tag(Mode.pieces)
            Text("Tab").tag(Mode.tab)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PocketColor.background)
    }

    /// A row of the tab, back on the board (D10): the board row it starts in, with the pieces that drew it
    /// drawn heavier for a moment.
    private func showPieces(of row: SongTab.Row, in map: SongMap) {
        // A row written out from the section it's the same as goes to that section, where its pieces are (D19).
        let start = row.sourceStart ?? row.start
        let boardRow = map.sections.flatMap(\.rows).last { $0.start <= start + SongMapLayout.tolerance }
        highlighted = Set(row.pieces)
        mode = .pieces
        scrollTarget = boardRow.map { SongMapAnchor.row($0.start) }
    }

    // MARK: - Pieces

    private func header(_ map: SongMap, tab: SongTab?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(facts(map))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                Spacer(minLength: 0)
                barsChip
            }
            Text(guidance(map, tab: tab))
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
            if tab != nil, !SongMapInput.hasGrid(song) { setTheOne.padding(.top, 4) }
        }
    }

    /// Without a grid the tab is in seconds, and says so once (D7). The map has no tempo flow of its own:
    /// this goes to the waveform, where **Set the 1** already lives, and is drawn the way it's drawn there.
    @ViewBuilder private var setTheOne: some View {
        let label = Label("Set the tempo and the 1 to see bars", systemImage: "1.circle")
            .font(.futura(.footnote, weight: .medium))
        if let onShowWaveform {
            Button(action: onShowWaveform) { label.foregroundStyle(PocketColor.active) }
                .buttonStyle(.plain)
                .accessibilityHint("Closes the map and opens the song's waveform")
        } else {
            label.foregroundStyle(PocketColor.textSecondary)
        }
    }

    private func view(_ uid: UUID) {
        guard let loop = song.loops.first(where: { $0.uid == uid }) else { return }
        made = nil
        viewing = StableRef(value: loop)
    }

    private func open(_ uid: UUID, in mode: LoopRunMode) {
        guard let loop = song.loops.first(where: { $0.uid == uid }), LoopModeAccess.allows(mode, loop) else { return }
        made = nil
        onOpenNestedAudio()
        opening = Opening(uid: uid, mode: mode)
    }

    /// A mode or *Copy to…* picked on the tab sheet, once the sheet has gone.
    private func openPicked() {
        if let uid = copyAfterSheet {
            copyAfterSheet = nil
            copying = CopySource(uid: uid)
        }
        guard let picked = openAfterSheet else { return }
        openAfterSheet = nil
        open(picked.uid, in: picked.mode)
    }

    private func openMarker(_ uid: UUID) {
        guard let marker = song.markers.first(where: { $0.uid == uid }) else { return }
        made = nil
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

#Preview("Map the song") {
    SongMapView(song: SongMapPreview.song())
        .modelContainer(for: Song.self, inMemory: true)
}
