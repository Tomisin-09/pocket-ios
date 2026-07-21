import SwiftData
import SwiftUI

/// The **chord picker** (ADR 0103) — a search-first sheet that replaced the flat insert `Menu` in
/// `ChordProgressionEditor`. A live search field filters an **Insert** grid of mini chord diagrams,
/// grouped **My chords → Movable shapes → Open shapes**; a **Build** segment carries the two authoring
/// actions (`MovableChordSheet` / `CustomChordSheet`) as cards. Additive over the shipped substrates —
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

    @Environment(\.dismiss) private var dismiss

    /// Newest first — the just-saved chord is at the top of My chords (ADR 0095).
    @Query(sort: \SavedChord.createdAt, order: .reverse) private var savedChords: [SavedChord]

    @State private var query = ""
    @State private var mode: Mode = .insert
    @State private var showMovableBuilder = false
    @State private var showCustomBuilder = false

    private enum Mode: String, CaseIterable, Identifiable {
        case insert, build
        var id: String { rawValue }
        var label: String { self == .insert ? "Insert" : "Build" }
    }

    /// Root menu order C … B (pitch class 0 … 11), the way a key is spoken.
    private let rootNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 3)

    // MARK: - Filtered groups

    private var filteredSaved: [SavedChord] {
        savedChords.filter { ChordPicker.matches(query: query, in: $0.name) }
    }
    private var filteredMovable: [ChordGrip] {
        ChordPicker.insertMovableGrips.filter {
            ChordPicker.matches(query: query, in: ChordPicker.movableSearchText($0))
        }
    }
    private var filteredOpen: [ChordVoicing] {
        ChordVoicing.library.filter { ChordPicker.matches(query: query, in: $0.name) }
    }
    private var insertIsEmpty: Bool {
        filteredSaved.isEmpty && filteredMovable.isEmpty && filteredOpen.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if mode == .insert { searchField }
                modePicker
                Divider().overlay(PocketColor.surfaceBorder)
                Group {
                    if mode == .insert { insertPane } else { buildPane }
                }
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
        .sheet(isPresented: $showMovableBuilder) {
            MovableChordSheet { insert($0) }
        }
        .fullScreenCover(isPresented: $showCustomBuilder) {
            CustomChordSheet(onInsert: { insert($0) }, onSave: onSave)
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
        Picker("Chord source", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, mode == .insert ? 0 : 12)
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
                if !filteredMovable.isEmpty {
                    group(title: "Movable shapes", count: filteredMovable.count, slide: true) {
                        ForEach(Array(filteredMovable.enumerated()), id: \.offset) { _, grip in
                            movableChip(grip)
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
                if insertIsEmpty { emptyState }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func group<Content: View>(title: String, count: Int, slide: Bool,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
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
            LazyVGrid(columns: columns, spacing: 9) { content() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No chords match")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Button("Build one instead") { mode = .build }
                .font(.futura(.subheadline, weight: .semibold))
                .tint(PocketColor.practice)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    // MARK: - Chips

    private func chip(voicing: ChordVoicing, title: String, subtitle: String?, saved: Bool,
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
    private func movableChip(_ grip: ChordGrip) -> some View {
        Menu {
            ForEach(rootNames.indices, id: \.self) { pitchClass in
                Button(rootNames[pitchClass]) { insert(grip.voicing(rootPitchClass: pitchClass)) }
            }
        } label: {
            chipBody(voicing: grip.browseVoicing, title: grip.quality.displayName,
                     subtitle: ChordPicker.movableSubtitle(grip), saved: false)
        }
        .accessibilityLabel("\(grip.quality.displayName) \(grip.name) barre, choose a root")
    }

    private func chipBody(voicing: ChordVoicing, title: String, subtitle: String?,
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

    // MARK: - Build pane

    private var buildPane: some View {
        ChordBuildPane(onMovable: { showMovableBuilder = true },
                       onCustom: { showCustomBuilder = true })
    }
}

/// The **Build** segment (ADR 0103 D2) — the two authoring actions as description cards. Split out so the
/// picker's own struct body stays within bounds; it's pure presentation over two callbacks.
private struct ChordBuildPane: View {
    let onMovable: () -> Void
    let onCustom: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                card(icon: "arrow.left.and.right", title: "Movable shape",
                     subtitle: "Any grip to any root, auto-named. "
                     + "Common barre shapes also live under Insert.", action: onMovable)
                card(icon: "square.and.pencil", title: "Custom chord",
                     subtitle: "Place each string yourself, then name it.", action: onCustom)
            }
            .padding(16)
        }
    }

    private func card(icon: String, title: String, subtitle: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11).fill(PocketColor.practiceCardWash))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.futura(.body, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.surfaceSubtle))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Chord picker — populated") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SavedChord.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    for chord in [ChordVoicing("Aadd9", frets: [0, 0, 2, 4, 2, nil]),
                  ChordVoicing("Cm9", frets: [3, 4, 3, 5, 6, nil])] {
        container.mainContext.insert(SavedChord(chord))
    }
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            ChordPickerSheet(onInsert: { _ in }, onSave: { _ in })
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
}
