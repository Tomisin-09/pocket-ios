import SwiftData
import SwiftUI

/// The **chord picker** (ADR 0103) — a search-first sheet that replaced the flat insert `Menu` in
/// `ChordProgressionEditor`. A live search field filters an **Insert** grid of mini chord diagrams,
/// grouped **My chords → Movable shapes → Triads → Open shapes → Sus, 6ths & 9ths**; the **Build**
/// segment is a single action that opens `CustomChordSheet` directly (ADR 0122 — every movable shape is
/// now browsable under Insert, so the old two-card Build pane had one card left). Additive over the shipped substrates —
/// it reads `ChordVoicing.library`, the `SavedChord` `@Query`, and generated `ChordGrip`s (browse
/// pictures via `ChordGrip.browseVoicing`); no new model, renderer untouched.
///
/// A **root row** sits over the grid (ADR 0297). With a root chosen, every movable chip is drawn *as the
/// chord it makes there* — "Cm7" at its real frets — and a tap inserts it; the fixed chips (My chords,
/// open shapes) narrow to that root. With **Any**, the movable chips are root-agnostic pictures of a
/// shape again, and tapping one opens a compact root menu (ADR 0103 D4). *Add* opens on Any. A **swap**
/// opens on the root of the chord it replaces, with that chord's shape marked and scrolled to, so
/// another shape at the same root is one tap and the same shape at another root is two.
///
/// Picking any chip inserts and dismisses; managing saved chords lives in the Toolkit hub, not here
/// (ADR 0103 D5). The chips themselves are in `ChordPickerSheet+Chips.swift`.
struct ChordPickerSheet: View {
    /// Called with the chosen / generated voicing. The caller routes it to the add or swap slot.
    let onInsert: (ChordVoicing) -> Void
    /// Persist a voicing built in the custom placer to "My chords" (passed through to `CustomChordSheet`).
    let onSave: (ChordVoicing) -> Void
    /// Sheet title — "Add a chord" when appending, "Swap chord" when replacing an existing slot.
    let title: String
    /// The neck being authored for (ADR 0164). On bass the guitar sections stand down entirely —
    /// barres, triads and open shapes are six-string geometry and there is no honest four-string
    /// reading of them — and `BassChordShape`'s dyads and shells take their place.
    let instrument: Instrument
    /// What a swap is replacing (ADR 0297) — its root and the shape to mark. `nil` on *Add*.
    let current: ChordPickerCurrent?

    /// - Parameter current: the chord a swap replaces. The sheet opens on its root, with its shape
    ///   marked; leave it out for *Add*, which opens on **Any**.
    init(onInsert: @escaping (ChordVoicing) -> Void, onSave: @escaping (ChordVoicing) -> Void,
         title: String = "Add a chord", instrument: Instrument = .guitar, current: ChordVoicing? = nil) {
        self.onInsert = onInsert
        self.onSave = onSave
        self.title = title
        self.instrument = instrument
        let found = current.map(ChordPickerCurrent.init)
        self.current = found
        _root = State(initialValue: found?.rootPitchClass)
        // The Tier-2 section starts folded (ADR 0122) — unless the chord being swapped is in it, which
        // would hide the very chip the sheet opened to show.
        let swapsATier2Shape = found?.grip.map { ChordGrip.tier2.contains($0) } ?? false
        _collapsedSections = State(initialValue: swapsATier2Shape ? [] : [Self.tier2Title])
    }

    @Environment(\.dismiss) private var dismiss

    /// Newest first — the just-saved chord is at the top of My chords (ADR 0095).
    @Query(sort: \SavedChord.createdAt, order: .reverse) private var savedChords: [SavedChord]

    @State private var query = ""
    @State var showCustomBuilder = false
    /// Insert section headers the player has collapsed (ADR 0109) — tapping a header toggles it. Ignored
    /// while searching (a query force-expands every section so a match can't hide in a collapsed one).
    @State private var collapsedSections: Set<String>
    /// The root the grid is drawn at (ADR 0297), or `nil` for **Any**.
    @State var root: Int?

    /// The segmented control's two positions. **Insert** is the only state the sheet ever rests in;
    /// **Build** is a spring-loaded action (see `modeSelection`), which is why nothing stores a `Mode`.
    private enum Mode: String, CaseIterable, Identifiable {
        case insert, build
        var id: String { rawValue }
        var label: String { self == .insert ? "Insert" : "Build a chord" }
    }

    /// The Tier-2 section's title — needed as a constant because it seeds `collapsedSections`.
    private static let tier2Title = "Sus, 6ths & 9ths"
    /// The one chip the sheet scrolls to — the swapped chord's (see `currentChip`).
    nonisolated static let currentChipID = "chordPicker.current"

    /// **Build** is an action, not a tab (ADR 0122): selecting it opens the custom placer and leaves the
    /// segment on Insert, so dismissing the placer returns to the grid rather than to an empty pane.
    private var modeSelection: Binding<Mode> {
        Binding(get: { .insert },
                set: { picked in if picked == .build { showCustomBuilder = true } })
    }

    /// A bare root menu has nothing to spell against, so it follows the accidental preference
    /// (ADR 0123) — replacing the hand-mixed sharps-and-flats list this shipped with.
    @AppStorage(AppSettings.Key.accidentalPreference)
    private var accidentalRaw = NoteSpelling.default.rawValue

    var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    /// Root order C … B (pitch class 0 … 11), the way a key is spoken.
    var rootNames: [String] { (0..<12).map { spelling.name(pitchClass: $0) } }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    // MARK: - Filtered groups

    /// Saved chords **for this neck only**. A six-string shape inserted into a bass drill would draw a
    /// guitar box mid-progression and sound in the wrong octave, and My Chords is a single global
    /// library shared by both (ADR 0095), so the filter belongs here at the point of insertion.
    var filteredSaved: [SavedChord] {
        savedChords.filter {
            $0.voicing.isBass == (instrument == .bass)
                && ChordPicker.matches(query: query, in: $0.name)
                && ChordPicker.fixedChord($0.voicing, isAt: root)
        }
    }
    /// The bass vocabulary — empty on guitar, which is what keeps its section out of the pane.
    private var filteredBass: [BassChordShape] {
        guard instrument == .bass else { return [] }
        return BassChordShape.all.filter {
            let placed = placedBass($0)?.name
            return ChordPicker.matches(query: query, in: [placed, $0.name].compactMap { $0 }.joined(separator: " "))
        }
    }
    private var filteredMovable: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertMovableGrips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.movableSearchText($0, placedName: placed($0)?.name))
        }
    }
    private var filteredTier2: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertTier2Grips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.movableSearchText($0, placedName: placed($0)?.name))
        }
    }
    private var filteredTriads: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertTriadGrips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.triadSearchText($0, placedName: placed($0)?.name))
        }
    }
    var filteredOpen: [ChordVoicing] {
        guard instrument == .guitar else { return [] }
        return ChordVoicing.library.filter {
            ChordPicker.matches(query: query, in: $0.name) && ChordPicker.fixedChord($0, isAt: root)
        }
    }
    private var insertIsEmpty: Bool {
        filteredSaved.isEmpty && filteredMovable.isEmpty && filteredTriads.isEmpty
            && filteredOpen.isEmpty && filteredTier2.isEmpty && filteredBass.isEmpty
    }

    /// A grip as the chord it makes at the chosen root — `nil` on **Any**.
    func placed(_ grip: ChordGrip) -> ChordVoicing? {
        root.map { grip.voicing(rootPitchClass: $0, spelling: spelling) }
    }

    /// A bass shape at the chosen root — `nil` on **Any**, or where the shape can't reach that root.
    func placedBass(_ shape: BassChordShape) -> ChordVoicing? {
        root.flatMap { shape.voicing(rootPitchClass: $0, spelling: spelling) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                modePicker
                rootRow
                Divider().overlay(PocketColor.surfaceBorder)
                insertPane
            }
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(PocketColor.practice)
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showCustomBuilder) {
            CustomChordSheet(onInsert: { insert($0) }, onSave: onSave, instrument: instrument)
        }
    }

    /// Route a chosen voicing to the caller and close — picking a chip is the whole interaction.
    func insert(_ voicing: ChordVoicing) {
        onInsert(voicing)
        dismiss()
    }

}

// MARK: - Search, mode and the insert pane

extension ChordPickerSheet {

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PocketColor.textSecondary)
            TextField("Search chords…", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.futura(.subheadline))
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 11).fill(PocketColor.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 11)
            .strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var modePicker: some View {
        Picker("Chord source", selection: modeSelection) {
            ForEach(Mode.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Insert pane

    private var insertPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                insertGroups.padding(16)
            }
            // A swap opens scrolled to the chord it replaces, and keeps it in view as the root changes —
            // the marked chip is where *the same shape, another root* is tapped.
            .onAppear { scrollToCurrent(proxy) }
            .onChange(of: root) { withAnimation { scrollToCurrent(proxy) } }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard currentChip != nil else { return }
        proxy.scrollTo(Self.currentChipID, anchor: .center)
    }

    private var insertGroups: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !filteredSaved.isEmpty {
                group(title: "My chords", count: filteredSaved.count, slide: false) {
                    ForEach(filteredSaved) { savedChip($0) }
                }
            }
            if !filteredBass.isEmpty {
                group(title: "Bass shapes", count: filteredBass.count, slide: true) {
                    ForEach(filteredBass) { bassChip($0) }
                }
            }
            if !filteredMovable.isEmpty {
                group(title: "Movable shapes", count: filteredMovable.count, slide: true) {
                    ForEach(Array(filteredMovable.enumerated()), id: \.offset) { _, grip in
                        movableChip(grip)
                    }
                }
            }
            if !filteredTriads.isEmpty {
                group(title: "Triads", count: filteredTriads.count, slide: true) {
                    ForEach(Array(filteredTriads.enumerated()), id: \.offset) { _, grip in
                        triadChip(grip)
                    }
                }
            }
            if !filteredOpen.isEmpty {
                group(title: "Open shapes", count: filteredOpen.count, slide: false) {
                    ForEach(filteredOpen) { openChip($0) }
                }
            }
            if !filteredTier2.isEmpty {
                group(title: Self.tier2Title, count: filteredTier2.count, slide: true) {
                    ForEach(Array(filteredTier2.enumerated()), id: \.offset) { _, grip in
                        movableChip(grip)
                    }
                }
            }
            if insertIsEmpty { emptyState }
        }
    }

    /// A collapsible Insert section (ADR 0109): the header toggles the grid open/closed so a picker with
    /// four categories isn't a wall of diagrams. A live search force-expands (see `isCollapsed`).
    @ViewBuilder
    private func group<Content: View>(title: String, count: Int, slide: Bool,
                                      @ViewBuilder content: () -> Content) -> some View {
        let isCollapsed = collapsedSections.contains(title) && query.isEmpty
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if collapsedSections.contains(title) {
                    collapsedSections.remove(title)
                } else {
                    collapsedSections.insert(title)
                }
                haptic(.light)
            } label: {
                groupHeader(title: title, count: count, slide: slide, collapsed: isCollapsed)
            }
            .buttonStyle(.plain)
            if !isCollapsed {
                LazyVGrid(columns: columns, spacing: 9) { content() }
            }
        }
    }

    private func groupHeader(title: String, count: Int, slide: Bool, collapsed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Text(title.uppercased())
                .font(.futura(.caption2, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            if slide {
                Text("slide to any root")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.practice)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(PocketColor.practiceCardWash))
            }
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) chords")
        .accessibilityHint(collapsed ? "Collapsed. Tap to expand." : "Expanded. Tap to collapse.")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No chords match")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Button("Build one instead") { showCustomBuilder = true }
                .font(.futura(.subheadline, weight: .semibold))
                .tint(PocketColor.practice)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}
