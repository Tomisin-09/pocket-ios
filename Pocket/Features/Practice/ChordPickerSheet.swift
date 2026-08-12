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
/// Movable chips are root-agnostic pictures of a shape: tapping one opens a compact **root menu**, and
/// choosing a root places the grip there (`ChordGrip.voicing(rootPitchClass:)`) and inserts it (ADR 0103
/// D4). Picking any chip inserts and dismisses; managing saved chords lives in the Toolkit hub, not here
/// (ADR 0103 D5).
struct ChordPickerSheet: View {
    /// Called with the chosen / generated voicing. The caller routes it to the add or swap slot.
    let onInsert: (ChordVoicing) -> Void
    /// Persist a voicing built in the custom placer to "My chords" (passed through to `CustomChordSheet`).
    let onSave: (ChordVoicing) -> Void
    /// Sheet title — "Add a chord" when appending, "Swap chord" when replacing an existing slot.
    var title: String = "Add a chord"
    /// The neck being authored for (ADR 0164). On bass the guitar sections stand down entirely —
    /// barres, triads and open shapes are six-string geometry and there is no honest four-string
    /// reading of them — and `BassChordShape`'s dyads and shells take their place.
    var instrument: Instrument = .guitar

    @Environment(\.dismiss) private var dismiss

    /// Newest first — the just-saved chord is at the top of My chords (ADR 0095).
    @Query(sort: \SavedChord.createdAt, order: .reverse) private var savedChords: [SavedChord]

    @State private var query = ""
    @State private var showCustomBuilder = false
    /// Insert section headers the player has collapsed (ADR 0109) — tapping a header toggles it. Ignored
    /// while searching (a query force-expands every section so a match can't hide in a collapsed one).
    /// Seeded with the Tier-2 section so the advanced shapes start folded away (ADR 0122).
    @State private var collapsedSections: Set<String> = [ChordPickerSheet.tier2Title]

    /// The segmented control's two positions. **Insert** is the only state the sheet ever rests in;
    /// **Build** is a spring-loaded action (see `modeSelection`), which is why nothing stores a `Mode`.
    private enum Mode: String, CaseIterable, Identifiable {
        case insert, build
        var id: String { rawValue }
        var label: String { self == .insert ? "Insert" : "Build a chord" }
    }

    /// The Tier-2 section's title — needed as a constant because it seeds `collapsedSections`.
    private static let tier2Title = "Sus, 6ths & 9ths"

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

    private var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    /// Root menu order C … B (pitch class 0 … 11), the way a key is spoken.
    private var rootNames: [String] { (0..<12).map { spelling.name(pitchClass: $0) } }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    // MARK: - Filtered groups

    /// Saved chords **for this neck only**. A six-string shape inserted into a bass drill would draw a
    /// guitar box mid-progression and sound in the wrong octave, and My Chords is a single global
    /// library shared by both (ADR 0095), so the filter belongs here at the point of insertion.
    private var filteredSaved: [SavedChord] {
        savedChords.filter {
            $0.voicing.isBass == (instrument == .bass)
                && ChordPicker.matches(query: query, in: $0.name)
        }
    }
    /// The bass vocabulary — empty on guitar, which is what keeps its section out of the pane.
    private var filteredBass: [BassChordShape] {
        guard instrument == .bass else { return [] }
        return BassChordShape.all.filter { ChordPicker.matches(query: query, in: $0.name) }
    }
    private var filteredMovable: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertMovableGrips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.movableSearchText($0))
        }
    }
    private var filteredTier2: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertTier2Grips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.movableSearchText($0))
        }
    }
    private var filteredTriads: [ChordGrip] {
        guard instrument == .guitar else { return [] }
        return ChordPicker.insertTriadGrips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.triadSearchText($0))
        }
    }
    private var filteredOpen: [ChordVoicing] {
        guard instrument == .guitar else { return [] }
        return ChordVoicing.library.filter { ChordPicker.matches(query: query, in: $0.name) }
    }
    private var insertIsEmpty: Bool {
        filteredSaved.isEmpty && filteredMovable.isEmpty && filteredTriads.isEmpty
            && filteredOpen.isEmpty && filteredTier2.isEmpty && filteredBass.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                modePicker
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
    private func insert(_ voicing: ChordVoicing) {
        onInsert(voicing)
        dismiss()
    }

    // MARK: - Search + mode

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !filteredSaved.isEmpty {
                    group(title: "My chords", count: filteredSaved.count, slide: false) {
                        ForEach(filteredSaved) { saved in
                            chip(voicing: saved.voicing, title: saved.name, subtitle: nil, saved: true) {
                                insert(saved.voicing)
                            }
                        }
                    }
                }
                if !filteredBass.isEmpty {
                    group(title: "Bass shapes", count: filteredBass.count, slide: true) {
                        ForEach(filteredBass) { shape in
                            bassChip(shape)
                        }
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
                        ForEach(filteredOpen) { voicing in
                            chip(voicing: voicing, title: voicing.name, subtitle: nil, saved: false) {
                                insert(voicing)
                            }
                        }
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
            .padding(16)
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

// MARK: - Chips (split out to keep the picker's struct body within bounds)

private extension ChordPickerSheet {
    func chip(voicing: ChordVoicing, title: String, subtitle: String?, saved: Bool,
              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipBody(voicing: voicing, title: title, subtitle: subtitle, saved: saved)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Insert \(title)")
    }

    /// A movable grip's chip: tap opens a compact root menu, and choosing a root places + inserts the
    /// shape there (ADR 0103 D4). The picture is `browseVoicing` (fret-5 barre); the label is the
    /// quality + family, so the chip stays honestly root-agnostic.
    func movableChip(_ grip: ChordGrip) -> some View {
        gripChip(grip, subtitle: ChordPicker.movableSubtitle(grip),
                 accessibility: "\(grip.quality.displayName) \(ChordPicker.movableSubtitle(grip)), "
                     + "choose a root")
    }

    /// A triad grip's chip (ADR 0109) — same root-menu interaction as a movable shape; subtitle is the
    /// string set it voices.
    func triadChip(_ grip: ChordGrip) -> some View {
        gripChip(grip, subtitle: ChordPicker.triadSubtitle(grip),
                 accessibility: "\(grip.quality.displayName) triad on \(grip.name), choose a root")
    }

    /// A bass shape's chip (ADR 0164) — the same root-menu interaction as a movable grip, because a
    /// dyad is movable in exactly the same sense: the picture is the shape, the root is chosen on tap.
    /// The browse picture is the shape rooted on the low E at fret 5, which is where a hand meets it.
    ///
    /// A root the shape can't reach is **omitted from the menu** rather than offered and silently
    /// dropped — `BassChordShape.voicing` refuses instead of clamping (that's the point of it), so an
    /// unreachable root would otherwise be a button that does nothing.
    func bassChip(_ shape: BassChordShape) -> some View {
        let browse = shape.voicing(rootString: ChordVoicing.bassStringCount - 1, rootFret: 5,
                                   spelling: spelling)
        return Menu {
            ForEach(rootNames.indices, id: \.self) { pitchClass in
                if let voicing = shape.voicing(rootPitchClass: pitchClass, spelling: spelling) {
                    Button(rootNames[pitchClass]) { insert(voicing) }
                }
            }
        } label: {
            chipBody(voicing: browse ?? ChordVoicing(shape.name, frets: [nil, nil, nil, 0]),
                     title: shape.name, subtitle: "bass", saved: false)
        }
        .accessibilityLabel("\(shape.name), choose a root")
    }

    /// Shared chip for any `ChordGrip` browsed by root: a menu of the 12 roots over the grip's browse
    /// picture. Choosing a root places (`voicing(rootPitchClass:)`) and inserts.
    func gripChip(_ grip: ChordGrip, subtitle: String, accessibility: String) -> some View {
        Menu {
            ForEach(rootNames.indices, id: \.self) { pitchClass in
                Button(rootNames[pitchClass]) { insert(grip.voicing(rootPitchClass: pitchClass, spelling: spelling)) }
            }
        } label: {
            chipBody(voicing: grip.browseVoicing, title: grip.quality.displayName,
                     subtitle: subtitle, saved: false)
        }
        .accessibilityLabel(accessibility)
    }

    func chipBody(voicing: ChordVoicing, title: String, subtitle: String?,
                  saved: Bool) -> some View {
        VStack(spacing: 6) {
            ChordDiagramView(voicing: voicing, tint: PocketColor.practice, showsName: false)
                .frame(height: 54)
            Text(title)
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(saved ? PocketColor.practice : PocketColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            // A single reserved line keeps every chip the same height whether or not it has a subtitle.
            Text(subtitle ?? " ")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 13).fill(PocketColor.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(
            saved ? PocketColor.practice.opacity(0.35) : PocketColor.surfaceBorder, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
