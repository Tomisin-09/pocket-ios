import SwiftData
import SwiftUI

/// **Use a progression** (ADR 0218) — the second way into a chord drill, beside *Add chord*. Choose a
/// built-in progression and a key, or a two-chord change; set how long each chord is held; tap any chord
/// in the preview to swap it; add. A thin skin over `ProgressionInsert` and `ProgressionResolver`, which
/// decide every chord it shows.
///
/// Opt-in on purpose: a drill still opens empty (ADR 0086 C1), and nothing is added until the player asks.
/// Everything this adds is an ordinary `ChordChange`, so the editor, the run screen and the export never
/// learn where a chord came from.
struct ProgressionPickerSheet: View {
    /// How many chords the drill already holds. When it holds any, *Add* asks whether to replace them.
    let existingCount: Int
    /// The drill's neck (ADR 0164) — bass resolves bass shapes and has no curated guitar pairs.
    var instrument: Instrument = .guitar
    /// The drill's bar, so a one-bar hold is the drill's own bar.
    var beatsPerBar: Int = 4
    /// Called with the chords and where they land; the caller writes them into its progression.
    let onInsert: ([ChordChange], ChordProgression.InsertMode) -> Void
    /// Keeps a chord built in the custom placer while swapping — passed through to the chord picker.
    let onSaveChord: (ChordVoicing) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The player's saved chords, for *Use my chords where they fit* (ADR 0218 D6).
    @Query(sort: \SavedChord.createdAt, order: .reverse) var savedChords: [SavedChord]
    /// The progressions the player wrote — *Your progressions*, newest first (ADR 0218 D10).
    @Query(sort: \SavedProgression.createdAt, order: .reverse) var savedProgressions: [SavedProgression]

    /// Key names and chord names follow the key first and this preference only where the key is silent
    /// (ADR 0123).
    @AppStorage(AppSettings.Key.accidentalPreference) var accidentalRaw = NoteSpelling.default.rawValue

    @State var tab: Tab = .progressions
    /// Opens on G — the key the four-chord loop is most often learned in.
    @State var tonic = 7
    /// Opens on the four-chord loop, so the sheet shows what it does before anything is tapped.
    @State var source: Source? = .template("one-five-six-four")
    @State var hold: ProgressionHold = .bar
    @State var useMyChords = false
    /// Chords swapped by hand in the preview, by slot. Cleared whenever the selection or key changes — a
    /// swap made for G has no business surviving a move to A.
    @State var swaps: [Int: ChordVoicing] = [:]
    /// The two chords of *Pick your own two*.
    @State var ownPair: [ChordVoicing?] = [nil, nil]
    @State var pickerSlot: PickerSlot?
    @State var writingProgression = false
    @State private var confirmingInsert = false

    enum Tab: String, CaseIterable, Identifiable {
        case progressions, pairs
        var id: String { rawValue }
        var label: String { self == .progressions ? "Progressions" : "Two chords" }
    }

    /// What is selected — one thing at a time, across both tabs.
    enum Source: Hashable {
        case template(String)
        case saved(UUID)
        case pair(String)
        case ownPair
    }

    /// Which slot the chord picker writes into.
    enum PickerSlot: Identifiable {
        case swap(Int)
        case own(Int)

        var id: String {
            switch self {
            case .swap(let index): return "swap-\(index)"
            case .own(let index): return "own-\(index)"
            }
        }

        var title: String {
            switch self {
            case .swap: return "Swap chord"
            case .own: return "Choose a chord"
            }
        }
    }

    var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    // MARK: - The selection, resolved

    var selectedTemplate: ProgressionTemplate? {
        guard case .template(let id) = source else { return nil }
        return ProgressionTemplate.catalog.first { $0.id == id }
    }

    /// The steps of the selected progression, built-in or the player's.
    var selectedSteps: [ProgressionStep]? {
        switch source {
        case .template?: return selectedTemplate?.steps
        case .saved?: return selectedSavedProgression?.steps
        default: return nil
        }
    }

    /// The chords the selection would insert — empty until something complete is chosen.
    var preview: [ProgressionInsert.Chord] {
        switch source {
        case .template?:
            guard let template = selectedTemplate else { return [] }
            return ProgressionInsert.chords(for: template.steps, fixedLengths: template.hasFixedLengths,
                                            placement: placement, swaps: swaps)
        case .saved?:
            guard let steps = selectedSavedProgression?.steps else { return [] }
            return ProgressionInsert.chords(for: steps, fixedLengths: false, placement: placement, swaps: swaps)
        case .pair(let id)?:
            guard let pair = ChordPair.curated.first(where: { $0.id == id }) else { return [] }
            return ProgressionInsert.chords(for: [pair.first, pair.second], hold: hold, beatsPerBar: beatsPerBar)
        case .ownPair?:
            let chosen = ownPair.compactMap { $0 }
            guard chosen.count == 2 else { return [] }
            return ProgressionInsert.chords(for: chosen, hold: hold, beatsPerBar: beatsPerBar)
        case nil:
            return []
        }
    }

    /// Where the sheet's controls place a progression.
    var placement: ProgressionInsert.Placement {
        ProgressionInsert.Placement(tonic: tonic, hold: hold, beatsPerBar: beatsPerBar, instrument: instrument,
                                    myChords: myChordVoicings, preference: spelling)
    }

    /// Saved chords for this neck, when the player asked for them.
    var myChordVoicings: [ChordVoicing] {
        guard useMyChords else { return [] }
        return savedChords.map(\.voicing).filter { $0.isBass == (instrument == .bass) }
    }

    /// Whether the selection reads as minor — the key chips say "Am" rather than "A".
    var readsAsMinor: Bool { selectedSteps?.readsAsMinor ?? false }

    /// The progression sets its own lengths (the blues), so the hold doesn't apply.
    var holdIsFixed: Bool { selectedTemplate?.hasFixedLengths ?? false }

    /// What the confirmation names — "I – V – vi – IV in G", "Am ↔ E".
    var selectionTitle: String {
        switch source {
        case .template?:
            guard let template = selectedTemplate else { return "these chords" }
            let key = ProgressionKey(tonic: tonic, isMinor: template.steps.readsAsMinor)
            return "\(template.displayTitle) in \(key.label(preference: spelling))"
        case .saved?:
            guard let saved = selectedSavedProgression else { return "these chords" }
            let key = ProgressionKey(tonic: tonic, isMinor: saved.steps.readsAsMinor)
            return "\(saved.name) in \(key.label(preference: spelling))"
        case .pair(let id)?:
            return ChordPair.curated.first { $0.id == id }?.title ?? "these chords"
        case .ownPair?:
            return ownPair.compactMap { $0?.name }.joined(separator: " ↔ ")
        case nil:
            return "these chords"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if tab == .progressions {
                    progressionsContent
                } else {
                    pairsContent
                }
                holdSection
                if tab == .progressions { myChordsSection }
            }
            .navigationTitle("Use a progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { addBar }
        }
        .tint(PocketColor.practice)
        .presentationDetents([.large])
        .onChange(of: tab) { source = nil }
        .onChange(of: source) { swaps = [:] }
        .onChange(of: tonic) { swaps = [:] }
        .sheet(item: $pickerSlot) { slot in
            ChordPickerSheet(onInsert: { place($0, in: slot) }, onSave: onSaveChord,
                             title: slot.title, instrument: instrument)
        }
        .confirmationDialog("Add \(selectionTitle)?", isPresented: $confirmingInsert, titleVisibility: .visible) {
            Button("Replace them") { commit(.replace) }
            Button("Add after them") { commit(.append) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(existingCount == 1 ? "This drill already has 1 chord."
                                    : "This drill already has \(existingCount) chords.")
        }
    }

    // MARK: - Shared sections

    private var holdSection: some View {
        Section {
            Picker("Hold each chord", selection: $hold) {
                ForEach(ProgressionHold.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(holdIsFixed)
        } header: {
            Text("Hold each chord")
        } footer: {
            Text(holdIsFixed ? "This progression sets each chord’s length."
                             : "Shorter holds mean faster changes at the same tempo.")
        }
    }

    private var myChordsSection: some View {
        Section {
            Toggle("Use my chords where they fit", isOn: $useMyChords)
                .disabled(savedChords.isEmpty)
        } header: {
            Text("My chords")
        } footer: {
            Text(savedChords.isEmpty
                 ? "Chords you save with Build a chord can stand in here."
                 : "A saved chord with the same root and quality replaces the standard shape, marked yours.")
        }
    }

    private var addBar: some View {
        let count = preview.count
        return Button {
            if existingCount > 0 {
                confirmingInsert = true
            } else {
                commit(.append)
            }
        } label: {
            Text(count == 0 ? "Choose chords to add" : ProgressionInsert.addLabel(count: count))
                .font(.futura(.headline, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(count == 0)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityIdentifier("progression.add")
    }

    // MARK: - Actions

    /// Route a chord from the picker to the slot it was opened for.
    private func place(_ voicing: ChordVoicing, in slot: PickerSlot) {
        switch slot {
        case .swap(let index):
            swaps[index] = voicing
        case .own(let index):
            ownPair[index] = voicing
            source = .ownPair
        }
    }

    private func commit(_ mode: ChordProgression.InsertMode) {
        let chords = preview
        guard !chords.isEmpty else { return }
        onInsert(ProgressionInsert.changes(chords), mode)
        dismiss()
    }
}
