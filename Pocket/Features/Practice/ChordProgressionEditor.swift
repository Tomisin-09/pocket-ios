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
    /// The owning drill's neck (ADR 0164) — passed to the picker so a bass drill is offered bass
    /// shapes. The rows themselves need no instrument: a diagram draws whatever neck its voicing
    /// carries, so a progression authored on either instrument renders correctly on its own.
    var instrument: Instrument = .guitar
    /// Beats in the drill's bar — what *1 bar* means to *Use a progression*, and what the hold labels
    /// count bars in. Defaults to 4/4, the only bar this editor assumed before ADR 0218.
    var beatsPerBar: Int = 4

    /// Both sheets this editor presents, as one `item:` route at the body root. See `Route` for why
    /// that is not a tidiness choice.
    @State private var route: Route?

    @Environment(\.modelContext) private var modelContext
    /// The player's saved custom chords — read only to de-dupe when the custom placer saves one (the
    /// picker surfaces the library itself). Sorted by a primitive column (never an optional `#Predicate`
    /// — `docs/swiftdata-gotchas.md`).
    @Query(sort: \SavedChord.name) private var savedChords: [SavedChord]

    /// Which slot the chord picker writes into — a new chord (`.add`) or a swap of an existing one
    /// (`.replace`). The picker emits a plain `ChordVoicing`, whatever the source (library, saved,
    /// movable grip, or the custom placer).
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

    /// The sheets this editor presents, as one `item:` route at the body root.
    ///
    /// *Use a progression* used to hang off its own button so it wouldn't share a presentation point
    /// with the chord picker's. That cost the picker sheet its state: this editor's rows are a `VStack`
    /// inside a **single `Form` row** at all four call sites, so when saving a progression writes to the
    /// context and the row rebuilds, iOS 18 takes the sheet attached to the button down with it —
    /// `ProgressionPickerSheet` came back reinitialised, on the default four-chord loop rather than the
    /// progression just written (CI, Xcode 16.4 / iOS 18.5; iOS 26 keeps the state, which is why this
    /// only ever failed on CI).
    ///
    /// `ProgressionPickerSheet.Route` already made this same move for its own sub-sheets and left the
    /// reasoning behind; the fix was applied one level down and not here. A sheet presented from the
    /// body root has no row to lose.
    private enum Route: Identifiable {
        case picker(ChordSlot)
        case progression

        var id: String {
            switch self {
            case .picker(let slot): return "picker-\(slot.id)"
            case .progression: return "progression"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Identity is the **index**, so a reorder redraws the rows in place rather than
            // animating one past another. That is deliberate: the alternative is a stable id on
            // `ChordChange`, and `ChordChange` is `Equatable` inside a `Codable` blob that
            // `ExerciseShapeSheet.commitChords()` diffs against a *freshly decoded* copy to decide
            // whether to write. A per-decode `UUID` would make that diff always report "changed",
            // so every Done would write. A missing animation is the cheaper of the two.
            ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                changeRow(index: index, change: change)
                if index < progression.changeCount - 1 { Divider() }
            }
            addButton
            useProgressionButton
        }
        .padding(.vertical, 4)
        .sheet(item: $route) { route in
            switch route {
            case .picker(let target):
                ChordPickerSheet(onInsert: { apply($0, to: target) },
                                 onSave: save,
                                 title: target.isReplace ? "Swap chord" : "Add a chord",
                                 instrument: instrument)
            case .progression:
                ProgressionPickerSheet(existingCount: progression.changeCount, instrument: instrument,
                                       beatsPerBar: beatsPerBar,
                                       onInsert: { progression = progression.inserting($0, mode: $1) },
                                       onSaveChord: save)
            }
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
            nudgeButtons(index: index, name: change.voicing.name)
            Button(role: .destructive) {
                progression = progression.removingChange(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(progression.changeCount <= 1)
        }
    }

    /// Move this chord up or down the progression. Two plain buttons rather than a drag handle:
    /// the rows are a `VStack` inside a *single* `Form` row at all four call sites, and SwiftUI's
    /// `.onMove` — what the routine editor's blocks use — only reaches a `ForEach` that is a direct
    /// child of a `List`. Restructuring for it would break the shared strum + chords layout, and a
    /// hand-rolled drag inside a `Form` fights the scroll it sits in.
    ///
    /// Always visible rather than behind an edit mode: reordering a progression is a *repair* — you
    /// notice the F should have come first — and a repair wants the control already there.
    private func nudgeButtons(index: Int, name: String) -> some View {
        VStack(spacing: 2) {
            nudgeButton(index: index, by: -1, systemImage: "chevron.up",
                        label: "Move \(name) up")
            nudgeButton(index: index, by: 1, systemImage: "chevron.down",
                        label: "Move \(name) down")
        }
        // The whole pair goes when there's nothing to reorder, rather than sitting there dimmed:
        // a one-chord progression can't be ordered at all, so the control has no meaning yet.
        .opacity(progression.changeCount > 1 ? 1 : 0)
        .disabled(progression.changeCount <= 1)
        .accessibilityHidden(progression.changeCount <= 1)
    }

    private func nudgeButton(index: Int, by offset: Int,
                             systemImage: String, label: String) -> some View {
        // `.borderless` for the sibling-button reason in the file header: without it a tap in a
        // `Form` row fires every button in the row, and this row now holds five.
        Button {
            progression = progression.movingChange(at: index, by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 18)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(PocketColor.practice)
        .disabled(!progression.changes.indices.contains(index + offset))
        .accessibilityLabel(label)
    }

    /// The chord's name, tapped to open the picker on this slot for a swap (ADR 0103). The chevron reads
    /// as "this opens a chooser".
    private func voicingButton(index: Int, current: ChordVoicing) -> some View {
        Button {
            route = .picker(.replace(index))
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
            route = .picker(.add)
        } label: {
            Label("Add chord", systemImage: "plus.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
    }

    /// Opens *Use a progression* (ADR 0218). The sheet is presented from the body root, not from here —
    /// see `Route`.
    private var useProgressionButton: some View {
        Button {
            route = .progression
        } label: {
            Label("Use a progression", systemImage: "list.bullet")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("progression.use")
    }

    /// "4 beats" — or "4 beats · 1 bar" when the hold is a whole number of the drill's bars, the way
    /// players count changes. One beat is "1 beat".
    private func beatsLabel(_ beats: Int) -> String {
        let bar = max(1, beatsPerBar)
        let beatText = beats == 1 ? "1 beat" : "\(beats) beats"
        guard beats % bar == 0 else { return beatText }
        let bars = beats / bar
        return "\(beatText) · \(bars) bar\(bars == 1 ? "" : "s")"
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
