import SwiftUI

/// The **custom-chord placer** (ADR 0084 slice 3, M4) — a full-screen chord authoring sheet for any
/// voicing the curated grips can't express. The tappable board itself lives in `ChordBoardEditor`; this
/// sheet wraps it with a live name, a **Display** menu that captions notes/degrees (shared scale-board
/// preference), a live `ChordIdentifierPanel` suggesting names (ADR 0093), and the confirm/save controls.
/// The player names the result; it lands as a plain `ChordVoicing` mixed inline (M4/M5 — renderer
/// untouched; fingers omitted, like the grips). An optional **Save to My chords** button persists the
/// shape for reuse (ADR 0095).
struct CustomChordSheet: View {
    /// Called with the composed voicing when the player confirms.
    let onInsert: (ChordVoicing) -> Void

    /// Label for the primary confirmation button. Defaults to **Insert** (the progression editor's
    /// "add to this slot" intent); the Toolkit's "Build a chord" flow passes **Save**, where confirming
    /// keeps the shape in My Chords rather than inserting it anywhere (ADR 0096 Slice 1).
    var confirmTitle: String = "Insert"

    /// Optional seam (ADR 0095): when set, a **Save to My chords** button appears and hands the caller the
    /// voicing to persist — kept separate from `onInsert` so saving and inserting are distinct intents.
    var onSave: ((ChordVoicing) -> Void)?

    /// The neck this sheet builds on (ADR 0164) — the owning drill's instrument, or the profile's
    /// preferred one when the sheet is opened from the instrument-free My Chords library. Fixed for
    /// the life of the sheet: the board's string count *is* the shape being authored, so changing it
    /// mid-build would be discarding the player's work, not switching a view.
    var instrument: Instrument = .guitar

    @Environment(\.dismiss) private var dismiss

    /// Last voicing handed to `onSave`, so the button reads "Saved" until the shape changes.
    @State private var lastSaved: ChordVoicing?

    /// Per-string fret, highest string first — `nil` muted, `0` open, `n` fretted. Starts all muted,
    /// sized to the chosen instrument's neck.
    @State private var frets: [Int?]
    @State private var name: String = ""

    init(onInsert: @escaping (ChordVoicing) -> Void,
         confirmTitle: String = "Insert",
         onSave: ((ChordVoicing) -> Void)? = nil,
         instrument: Instrument = .guitar) {
        self.onInsert = onInsert
        self.confirmTitle = confirmTitle
        self.onSave = onSave
        self.instrument = instrument
        _frets = State(initialValue: Array(repeating: nil, count: instrument.stringCount))
    }

    /// Caption mode for sounded strings — shared globally with the scale boards so chords/scales agree.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    /// A hand-built shape declares no key, so its note captions and its suggested names follow the
    /// accidental preference (ADR 0123).
    @AppStorage(AppSettings.Key.accidentalPreference)
    private var accidentalRaw = NoteSpelling.default.rawValue
    private var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var voicing: ChordVoicing { ChordVoicing(trimmedName, frets: frets) }
    private var canInsert: Bool { voicing.isValid && !trimmedName.isEmpty }

    /// The caption for each string under the current Display mode; `nil` hides that string's label.
    private var labels: [String?] {
        switch labelMode {
        case .none: return Array(repeating: nil, count: frets.count)
        case .note: return voicing.noteLabels(spelling: spelling)
        case .interval: return voicing.degreeLabels(relativeTo: chordCandidates.first?.rootPitchClass)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                titleRow
                board
                identifier
                nameField
                saveButton
                hint
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Custom chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        onInsert(voicing)
                        dismiss()
                    }
                    .disabled(!canInsert)
                }
            }
        }
        .tint(PocketColor.practice)
        .hearStopsOnDisappear()
    }

    // MARK: - Title + Display (the live name, plus the label toggle like the scale boards)

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(trimmedName.isEmpty ? "New chord" : trimmedName)
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(trimmedName.isEmpty ? PocketColor.textSecondary : PocketColor.textPrimary)
            Spacer()
            hearButton
            displayMenu
        }
    }

    /// Sound the shape as it's being built (ADR 0097 Slice 2) — a block chord through the shared
    /// `ToneEngine`, gated only on a *soundable* voicing (≥1 sounded string), not on naming: hearing
    /// the intervals is what helps you name it. Sits beside Display, both compact "inspect" controls.
    private var hearButton: some View {
        ChordHearButton(voicing: voicing, style: .compact, tint: PocketColor.practice,
                        gatesOnValidity: true)
    }

    /// Note / Interval / Off, matching the scale editors' control and sharing their global preference.
    private var displayMenu: some View {
        Menu {
            Picker("Labels", selection: $storedLabelMode) {
                ForEach(FretLabelMode.allCases) { mode in
                    Text(mode.pickerLabel).tag(mode.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                Text("Display")
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Display options: labels \(labelMode.pickerLabel)")
    }

    // MARK: - The tappable chord box (extracted into `ChordBoardEditor`)

    private var board: some View {
        ChordBoardEditor(frets: $frets, labels: labels, tint: PocketColor.practice)
    }

    // MARK: - Name + hint

    private var nameField: some View {
        TextField("Name this chord (e.g. Cadd9, F♯7♯9)", text: $name)
            .font(.futura(.body))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
    }

    private var hint: some View {
        Text("Tap a fret to place it — the board scrolls up the neck; inlay dots mark frets 3, 5, 7, 9 "
            + "and 12. Tap ✕ / ○ above a string to mute or open it. Use Display to label notes or degrees.")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Geometry + edit helpers

private extension CustomChordSheet {
    /// Enough distinct notes to name: three name any chord, and **two** name a power chord (root + 5th,
    /// ADR 0106) — but only when they actually spell one, so a mid-build dyad that names nothing still
    /// stays hidden rather than flashing "No common name".
    var canIdentify: Bool {
        let distinct = voicing.pitchClasses.count
        return distinct >= 3 || (distinct == 2 && !chordCandidates.isEmpty)
    }

    /// Live reverse-lookup readings of the shape (ADR 0093 N7), ranked best first — reads geometry only.
    var chordCandidates: [ChordCandidate] {
        ChordNamer.candidates(for: ChordVoicing("", frets: frets), spelling: spelling)
    }

    /// Under the board: the `ChordIdentifierPanel`; tapping a suggestion fills the name field (overridable).
    @ViewBuilder var identifier: some View {
        if canIdentify {
            ChordIdentifierPanel(candidates: chordCandidates) { picked in
                name = picked
                haptic(.light)
            }
        }
    }

    /// Whether the current shape has already been handed to `onSave` (so the button reads "Saved").
    var isSaved: Bool { lastSaved == voicing }

    /// "Save to My chords" — explicit, separate from Insert (ADR 0095 S3); valid+named, flips to "Saved".
    @ViewBuilder var saveButton: some View {
        if let onSave {
            Button {
                onSave(voicing)
                lastSaved = voicing
                haptic(.light)
            } label: {
                Label(isSaved ? "Saved to My chords" : "Save to My chords",
                      systemImage: isSaved ? "checkmark" : "bookmark")
                    .font(.futura(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(PocketColor.practice)
            .disabled(!canInsert || isSaved)
        }
    }
}

#Preview("Custom chord placer") {
    Color.clear.fullScreenCover(isPresented: .constant(true)) {
        CustomChordSheet(onInsert: { _ in }, onSave: { _ in }).preferredColorScheme(.dark)
    }
}
