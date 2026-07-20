import SwiftData
import SwiftUI

/// The **chord-progression authoring editor** (ADR 0065): build the sequence of chords the drill
/// changes through and how long each is held. A thin skin over the pure `ChordProgression` editing
/// helpers (append / replace / re-beat / remove, T5) — every control just calls one and writes the
/// result back through the binding, so there's no editing state to keep in sync.
///
/// Each row shows the voicing's diagram, a menu to swap it for any library shape, a stepper for its
/// hold in beats, and a remove control (never below one chord). "Add chord" appends from the same
/// library. Buttons carry `.borderless` so a tap hits only its own control, not every button in the
/// Form row (the sibling-button gotcha, learned on the fretboard editors).
struct ChordProgressionEditor: View {
    @Binding var progression: ChordProgression

    /// Which slot a presented authoring sheet writes into — a new chord, or a swap of an existing one.
    /// Both the movable grip (M2) and the custom placer (M4) emit a plain `ChordVoicing` mixed inline
    /// with the open-shape library.
    @State private var movableTarget: ChordSlot?
    @State private var customTarget: ChordSlot?

    /// Which slot a pick from the "My chords" manager writes into (ADR 0095 S4).
    @State private var savedChordsTarget: ChordSlot?

    @Environment(\.modelContext) private var modelContext
    /// The player's saved custom chords, offered for one-tap reuse in the menus. Sorted by a primitive
    /// column (never an optional `#Predicate` — `docs/swiftdata-gotchas.md`).
    @Query(sort: \SavedChord.name) private var savedChords: [SavedChord]

    private enum ChordSlot: Identifiable {
        case add
        case replace(Int)
        var id: String {
            switch self {
            case .add: return "add"
            case .replace(let index): return "replace-\(index)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                changeRow(index: index, change: change)
                if index < progression.changeCount - 1 { Divider() }
            }
            addMenu
        }
        .padding(.vertical, 4)
        .sheet(item: $movableTarget) { target in
            MovableChordSheet { voicing in apply(voicing, to: target) }
        }
        .fullScreenCover(item: $customTarget) { target in
            CustomChordSheet(onInsert: { voicing in apply(voicing, to: target) },
                             onSave: save)
        }
        .sheet(item: $savedChordsTarget) { target in
            SavedChordsSheet { voicing in apply(voicing, to: target) }
        }
    }

    /// Persist an authored voicing to the "My chords" library, de-duping identical shapes (ADR 0095 S3).
    private func save(_ voicing: ChordVoicing) {
        guard !SavedChord.isAlreadySaved(voicing, among: savedChords.map(\.voicing)) else { return }
        modelContext.insert(SavedChord(voicing))
    }

    /// Route a generated or placed voicing to the slot the sheet was opened for.
    private func apply(_ voicing: ChordVoicing, to target: ChordSlot) {
        switch target {
        case .add:
            progression = progression.appending(voicing)
        case .replace(let index):
            progression = progression.replacingVoicing(at: index, with: voicing)
        }
    }

    private func changeRow(index: Int, change: ChordChange) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ChordDiagramView(voicing: change.voicing, tint: PocketColor.practice)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 8) {
                voicingMenu(index: index, current: change.voicing)
                // The reverse-lookup "Looks like …" caption was removed here (user-testing note 10,
                // 2026-07-20): it crowded the row and its reading is still available on the movable
                // sheet (`ChordIdentityCaption` in `MovableChordSheet`) and the identifier panel.
                beatsStepper(index: index, change: change)
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                progression = progression.removingChange(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(progression.changeCount <= 1)
        }
    }

    private func voicingMenu(index: Int, current: ChordVoicing) -> some View {
        Menu {
            Button {
                movableTarget = .replace(index)
            } label: {
                Label("Movable shape…", systemImage: "arrow.left.and.right")
            }
            Button {
                customTarget = .replace(index)
            } label: {
                Label("Custom chord…", systemImage: "square.and.pencil")
            }
            Divider()
            savedChordsSection(
                insert: { progression = progression.replacingVoicing(at: index, with: $0) },
                manageTarget: .replace(index)
            )
            ForEach(ChordVoicing.library) { voicing in
                Button(voicing.name) {
                    progression = progression.replacingVoicing(at: index, with: voicing)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(current.name).font(.futura(.subheadline, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
    }

    private func beatsStepper(index: Int, change: ChordChange) -> some View {
        Stepper(value: Binding(
            get: { change.beats },
            set: { progression = progression.settingBeats(at: index, to: $0) }
        ), in: 1...16) {
            Text(beatsLabel(change.beats))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                movableTarget = .add
            } label: {
                Label("Movable shape…", systemImage: "arrow.left.and.right")
            }
            Button {
                customTarget = .add
            } label: {
                Label("Custom chord…", systemImage: "square.and.pencil")
            }
            Divider()
            savedChordsSection(
                insert: { progression = progression.appending($0) },
                manageTarget: .add
            )
            ForEach(ChordVoicing.library) { voicing in
                Button(voicing.name) { progression = progression.appending(voicing) }
            }
        } label: {
            Label("Add chord", systemImage: "plus.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
    }

    /// The **My chords** section shared by the Add + swap menus (ADR 0095 S4) — one-tap insert of each
    /// saved voicing above the curated library, plus a **Manage…** item opening the swipe-to-delete list.
    /// Shown only when the library is non-empty.
    @ViewBuilder
    private func savedChordsSection(insert: @escaping (ChordVoicing) -> Void,
                                    manageTarget: ChordSlot) -> some View {
        if !savedChords.isEmpty {
            Section("My chords") {
                ForEach(savedChords) { saved in
                    Button(saved.name) { insert(saved.voicing) }
                }
                Button {
                    savedChordsTarget = manageTarget
                } label: {
                    Label("Manage…", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    /// "4 beats" — or "4 beats · 1 bar" when the hold is a whole number of 4/4 bars, the way players
    /// count changes.
    private func beatsLabel(_ beats: Int) -> String {
        guard beats % 4 == 0 else { return "\(beats) beats" }
        let bars = beats / 4
        return "\(beats) beats · \(bars) bar\(bars == 1 ? "" : "s")"
    }
}

#Preview("Chord progression editor") {
    struct Harness: View {
        @State private var progression = ChordProgression.gMajorPop
        var body: some View {
            Form {
                Section("Chord progression") {
                    ChordProgressionEditor(progression: $progression)
                        .listRowBackground(Color.clear)
                }
            }
            .tint(PocketColor.practice)
        }
    }
    return Harness()
        .modelContainer(for: SavedChord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
