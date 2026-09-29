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
struct SongMapView: View {
    let song: Song
    /// Pause whatever else is playing before a piece opens: the practice screen's waveform, when the
    /// map was reached from there. Ear training plays the loop itself.
    var onOpenNestedAudio: () -> Void = {}
    /// Close the map and go to the song's waveform, where the tempo and the 1 are set (D7). `nil` where
    /// there's no way there, and the Tab view just says what's missing.
    var onShowWaveform: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var mode: Mode = .pieces
    /// Pieces just reached from a row of the Tab view, drawn heavier for a moment.
    @State private var highlighted: Set<UUID> = []
    /// The board row to scroll to once the board is back in place of the tab.
    @State private var scrollTarget: SongMapAnchor?
    /// The loop being opened, and in which mode. By uid, never the model (ADR 0090).
    @State private var opening: Opening?
    /// The loop whose tab is showing.
    @State private var viewing: StableRef<Loop>?
    /// A mode picked on the tab sheet, opened once the sheet has gone: a push can't start under a sheet.
    @State private var openAfterSheet: Opening?
    @State private var editingMarker: StableRef<Marker>?
    /// The gap *Make a piece here* is being offered for (D9).
    @State private var makingPiece: SongMap.Gap?
    /// *Use your markers as sections?* (D7): the list is open, or the offer was just answered here.
    @State private var choosingSections = false
    @State private var sectionOfferAnswered = false

    struct Opening: Equatable {
        let uid: UUID
        let mode: LoopRunMode
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
                                                                           makePiece: { makingPiece = $0 }),
                                                   highlighted: highlighted)
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
        } message: { gap in
            Text("A new loop \(span(of: gap, in: map)), on the \(gap.layer.name) lane. Count it in Train "
                 + "your ear and it fills in here.")
        }
        .sheet(item: $viewing, onDismiss: openPicked) { ref in
            if let piece = map.pieces[ref.value.uid] {
                SongMapPieceSheet(loop: ref.value, piece: piece, place: place(of: piece, in: map),
                                  onOpen: { mode in
                                      openAfterSheet = Opening(uid: ref.value.uid, mode: mode)
                                      viewing = nil
                                  }, inSections: map.hasSections)
            }
        }
        .task(id: highlighted) {
            guard !highlighted.isEmpty else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            withAnimation(.easeOut(duration: 0.4)) { highlighted = [] }
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
        let boardRow = map.sections.flatMap(\.rows).last { $0.start <= row.start + SongMapLayout.tolerance }
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

    private func guidance(_ map: SongMap, tab: SongTab?) -> String {
        guard let tab else {
            return map.pieces.isEmpty
                ? "No loops yet. Tap + in a lane to make one there. Every loop on this song appears here, "
                    + "where it plays."
                : "Each loop sits where it plays. Tap one for its tab, hold it to work on it, or tap + to "
                    + "make one in a gap."
        }
        return tab.isEmpty
            ? "Nothing counted yet. Count a loop in Train your ear and it's drawn here, where it plays."
            : "Drawn from your pieces, where they play. Tap a row to see the pieces that drew it."
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

    // MARK: - Sections and repeats

    /// *as Verse 1*: to the section it names, on whichever view is showing.
    private func showSection(_ start: TimeInterval) {
        scrollTarget = .section(start)
    }

    /// *Repeats to the end of the section* (D14), from a piece's hold menu.
    private func setRepeats(_ uid: UUID, _ isOn: Bool) {
        song.loops.first { $0.uid == uid }?.repeatsToSectionEnd = isOn
    }

    /// Offered once per song (D7): it has markers, none of them starts a section, and the offer hasn't
    /// been answered.
    private func offersSections(_ input: SongMapInput) -> Bool {
        !sectionOfferAnswered && SectionWords.shouldOffer(input.markers, duration: input.duration)
            && !AppSettings.sectionOfferMade(for: song.sourceID)
    }

    /// *Not now*, or the markers used: either way it's been answered, and isn't offered again.
    private func answerSectionOffer() {
        AppSettings.recordSectionOffer(for: song.sourceID)
        withAnimation { sectionOfferAnswered = true }
    }

    /// *Make a piece here* (D9): a loop that fills the gap exactly, named after its section and lane and
    /// typed *Chords* on the chords lane, so it lands where it was asked for. It's drawn heavier for a
    /// moment, so you can see where it went.
    private func make(_ gap: SongMap.Gap) {
        guard song.duration > 0 else { return }
        let loop = Loop(name: SongMapLayout.unusedName(gap.name, among: song.loops.map(\.name)),
                        start: gap.start / song.duration, end: gap.end / song.duration, speed: 1, repeats: 4)
        if gap.layer == .chords { loop.loopType = .chords }
        modelContext.insert(loop)
        Analytics.send(.loopCreated)
        loop.song = song
        highlighted = [loop.uid]
    }

    /// *from bar 9 to bar 12*, or *from 0:32 to 0:48* in seconds scale.
    private func span(of gap: SongMap.Gap, in map: SongMap) -> String {
        if let grid = map.grid, let bars = SongMapLayout.barRange(from: gap.start, to: gap.end, in: grid) {
            return bars.count == 1 ? "in bar \(bars.lowerBound)"
                : "from bar \(bars.lowerBound) to bar \(bars.upperBound)"
        }
        return "from \(timecode(gap.start)) to \(timecode(gap.end))"
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
