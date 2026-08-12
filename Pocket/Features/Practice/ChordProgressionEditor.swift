import SwiftData
import SwiftUI

/// The **chord-progression authoring editor** (ADR 0065): build the sequence of chords the drill
/// changes through and how long each is held. A thin skin over the pure `ChordProgression` editing
/// helpers (append / replace / re-beat / remove, T5) — every control just calls one and writes the
/// result back through the binding, so there's no editing state to keep in sync.
///
/// Each row shows the voicing's diagram, a button to swap it (opening the `ChordPickerSheet`), a stepper
/// for its hold in beats, and a remove control (never below one chord). "Add chord" appends via the same
/// picker. Buttons carry `.borderless` so a tap hits only its own control, not every button in the Form
/// row (the sibling-button gotcha, learned on the fretboard editors).
///
/// The flat insert `Menu` this used to carry was replaced by the search-first picker (ADR 0103) — both
/// the Add button and a row's chord-name button now present `ChordPickerSheet`, which owns the Insert
/// grid + the Movable / Custom authoring sub-sheets.
struct ChordProgressionEditor: View {
    @Binding var progression: ChordProgression
    /// The owning drill's neck (ADR 0163) — passed to the picker so a bass drill is offered bass
    /// shapes. The rows themselves need no instrument: a diagram draws whatever neck its voicing
    /// carries, so a progression authored on either instrument renders correctly on its own.
    var instrument: Instrument = .guitar

    /// Which slot the picker writes into — a new chord (`.add`) or a swap of an existing one
    /// (`.replace`). The picker emits a plain `ChordVoicing`, whatever the source (library, saved,
    /// movable grip, or the custom placer).
    @State private var pickerTarget: ChordSlot?

    @Environment(\.modelContext) private var modelContext
    /// The player's saved custom chords — read only to de-dupe when the custom placer saves one (the
    /// picker surfaces the library itself). Sorted by a primitive column (never an optional `#Predicate`
    /// — `docs/swiftdata-gotchas.md`).
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
        var isReplace: Bool { if case .replace = self { return true } else { return false } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                changeRow(index: index, change: change)
                if index < progression.changeCount - 1 { Divider() }
            }
            addButton
        }
        .padding(.vertical, 4)
        .sheet(item: $pickerTarget) { target in
            ChordPickerSheet(onInsert: { apply($0, to: target) },
                             onSave: save,
                             title: target.isReplace ? "Swap chord" : "Add a chord",
                             instrument: instrument)
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
                voicingButton(index: index, current: change.voicing)
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

    /// The chord's name, tapped to open the picker on this slot for a swap (ADR 0103). The chevron reads
    /// as "this opens a chooser".
    private func voicingButton(index: Int, current: ChordVoicing) -> some View {
        Button {
            pickerTarget = .replace(index)
        } label: {
            HStack(spacing: 4) {
                Text(current.name).font(.futura(.subheadline, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Swap chord \(current.name)")
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

    private var addButton: some View {
        Button {
            pickerTarget = .add
        } label: {
            Label("Add chord", systemImage: "plus.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
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
