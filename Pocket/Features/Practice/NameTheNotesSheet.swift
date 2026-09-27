import SwiftUI

/// How the player names what they heard (ADR 0225). One label type underneath, so a piece named one way
/// and a piece named another are read the same way later.
enum NamingMode: String, CaseIterable, Identifiable {
    case note, fret, chord

    var id: String { rawValue }

    var label: String {
        switch self {
        case .note: return "Note name"
        case .fret: return "Fret & string"
        case .chord: return "Chord"
        }
    }

    /// Where the sheet opens: the kind of the first name already given, else chords for a chord loop and
    /// note names for everything else.
    static func opening(for labels: [PieceLabel?], loopType: LoopType) -> NamingMode {
        switch labels.compactMap({ $0 }).first {
        case .pitchClass: return .note
        case .fretted: return .fret
        case .chord: return .chord
        case nil: return loopType == .chords ? .chord : .note
        }
    }
}

/// The strings Name the notes places frets on, what to call them, and which register a bare name sounds in.
struct NamingTuning {
    let openMidi: [Int]
    let label: String
    let instrument: Instrument
}

/// **Name the notes** (ADR 0225): the taps of one pass as numbered chips. Tap a chip to hear a slice of
/// the real recording from just before it, then say what it was. **Hear it, then mine** plays the slice
/// and then your answer, and you judge whether they match (ADR 0094 T2b). The app never says.
///
/// Opened with the loop already stopped, so a slice never plays over it. Presented from
/// `EarTrainingView`'s body root, never from a row (memory: a `.sheet` on a List row loses its write).
struct NameTheNotesSheet: View {
    let request: NamingRequest
    let player: ContinuousLoopPlayer
    let spelling: NoteSpelling
    let loopType: LoopType
    let onDone: (NamingResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State var labels: [PieceLabel?]
    @State var active = 0
    @State var mode: NamingMode
    /// The string and fret the fret picker shows before the current chip has one.
    @State var fretDraft = TabLine.Note(string: 2, fret: 5)
    /// The chord quality the root grid applies before the current chip has one.
    @State var chordSuffixDraft = ""
    let tuning: NamingTuning

    init(request: NamingRequest, player: ContinuousLoopPlayer, spelling: NoteSpelling, loopType: LoopType,
         onDone: @escaping (NamingResult) -> Void) {
        self.request = request
        self.player = player
        self.spelling = spelling
        self.loopType = loopType
        self.onDone = onDone
        let labels = request.taps.map(\.label)
        _labels = State(initialValue: labels)
        _mode = State(initialValue: NamingMode.opening(for: labels, loopType: loopType))
        let tuner = CountTheNotesModel.tunerTuning()
        let openMidi = request.openMidi ?? tuner.openMidi
        // A four-string piece is a bass piece, whatever the tuner says now; it sounds in bass register.
        let instrument: Instrument = openMidi.count == Instrument.bass.stringCount ? .bass : .guitar
        tuning = NamingTuning(openMidi: openMidi, label: request.tuningLabel ?? tuner.label,
                              instrument: instrument)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(subtitle)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Picker("How to name them", selection: $mode) {
                        ForEach(NamingMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chips
                    picker
                    hearButtons
                    NamingResultView(labels: labels, openMidi: tuning.openMidi, spelling: spelling,
                                     mode: mode, tuningLabel: tuning.label)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Name the notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(NamingResult(labels: labels, openMidi: tuning.openMidi, tuningLabel: tuning.label))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(labels != request.taps.map(\.label))
        .onDisappear {
            player.stopSlice()
            ToneEngine.shared.stop()
        }
    }

    /// The noun follows the mode: a chord loop is tapped once per chord, and calls them chords.
    private var subtitle: String {
        let count = request.taps.count
        let what = request.source == .saved ? "Your saved piece" : "This pass"
        let noun = mode == .chord ? "chord" : "note"
        return "\(what) · \(count) \(noun)\(count == 1 ? "" : "s"). Tap a \(noun) to hear just that moment."
    }

    // MARK: - Chips

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 6)], spacing: 6) {
            ForEach(request.taps.indices, id: \.self) { index in
                chip(index)
            }
        }
    }

    private func chip(_ index: Int) -> some View {
        let name = chipText(index)
        let isActive = index == active
        return Button {
            active = index
            hearSlice()
        } label: {
            VStack(spacing: 0) {
                Text("\(index + 1)")
                    .font(.futura(.caption2))
                    .monospacedDigit()
                Text(name ?? "?")
                    .font(.futura(.subheadline, weight: name == nil ? nil : .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(isActive ? PocketColor.background
                             : name == nil ? PocketColor.textSecondary : PocketColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? PocketColor.practice : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Note \(index + 1), \(name ?? "not named")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// What a chip shows: a fret as its string and fret ("B8") in fret mode, else the name.
    private func chipText(_ index: Int) -> String? {
        guard let label = labels[index] else { return nil }
        if mode == .fret, case .fretted(let string, let fret) = label {
            let names = TabLine.stringNames(openMidi: tuning.openMidi)
            let stringName = names.indices.contains(string)
                ? names[string].trimmingCharacters(in: .whitespaces) : "?"
            return "\(stringName)\(fret)"
        }
        return label.name(openMidi: tuning.openMidi, spelling: spelling)
    }

    // MARK: - Hearing

    private var hearButtons: some View {
        HStack(spacing: 10) {
            Button("Hear it again") { hearSlice() }
                .buttonStyle(.bordered)
            Button("Hear it, then mine") { hearSliceThenMine() }
                .buttonStyle(.borderedProminent)
                .disabled(labels[active] == nil)
        }
        .font(.futura(.subheadline))
        .tint(PocketColor.practice)
    }

    /// The slice for the active chip: the real recording, from just before the tap.
    func hearSlice() {
        ToneEngine.shared.stop()
        player.playSlice(at: request.taps[active].seconds)
    }

    /// The slice, then the player's own answer, a beat apart. Call and response (ADR 0094 T2b): two
    /// sounds, and the player's ear decides.
    private func hearSliceThenMine() {
        guard let label = labels[active] else { return }
        let notes = label.midiNotes(openMidi: tuning.openMidi, lowestMidi: lowestMidi)
        ToneEngine.shared.stop()
        player.playSlice(at: request.taps[active].seconds) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                Self.sound(notes)
            }
        }
    }

    /// Sound a label the moment it's picked, so the answer is heard as it's given.
    func soundLabel(_ label: PieceLabel) {
        player.stopSlice()
        ToneEngine.shared.stop()
        Self.sound(label.midiNotes(openMidi: tuning.openMidi, lowestMidi: lowestMidi))
    }

    @MainActor private static func sound(_ notes: [Int]) {
        guard !notes.isEmpty else { return }
        if notes.count == 1 {
            ToneEngine.shared.sequence(notes.map { Optional($0) }, noteDuration: 0.6)
        } else {
            ToneEngine.shared.sound(notes, sustain: 1.2)
        }
    }

    /// Where a bare note name sounds: A below middle C for guitar, an octave down for bass.
    private var lowestMidi: Int { tuning.instrument == .bass ? 45 : 57 }

    /// Move to the next chip, if there is one.
    func advance() {
        if active < request.taps.count - 1 { active += 1 }
    }
}
