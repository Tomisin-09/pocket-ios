import SwiftUI

/// The two ways to name a tap (ADR 0227 D1): **where you played it**, or **what you heard**. One label type
/// underneath, so a piece named one way and a piece named another are read the same way later.
enum NamingMode: String, CaseIterable, Identifiable {
    case fret, ear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fret: return "Fret & string"
        case .ear: return "By ear"
        }
    }

    /// Where the sheet opens: the sheet of the first answer already given, else By ear for a chord loop
    /// and Fret & string for everything else.
    static func opening(for labels: [PieceLabel?], loopType: LoopType) -> NamingMode {
        switch labels.compactMap({ $0 }).first {
        case .fretted: return .fret
        case .pitchClass, .chord: return .ear
        case nil: return loopType == .chords ? .ear : .fret
        }
    }

    /// The By ear kind selected when the sheet opens: the first answer named by ear, else major on a chord
    /// loop and one note on anything else.
    static func openingKind(for labels: [PieceLabel?], loopType: LoopType) -> EarKind {
        labels.lazy.compactMap { $0.flatMap(EarKind.init(namedAs:)) }.first
            ?? (loopType == .chords ? .chord(suffix: "") : .note)
    }
}

/// The strip's arithmetic (ADR 0227 D2), apart from the view so it's unit-tested.
enum NamingStrip {
    /// The next tap with no answer after `index`, wrapping round to the start; `nil` when every other tap
    /// is named. The current tap is never "next", even when it's the last gap.
    static func nextUnnamed(after index: Int, in labels: [PieceLabel?]) -> Int? {
        (1..<max(labels.count, 1)).lazy
            .map { (index + $0) % labels.count }
            .first { labels[$0] == nil }
    }

    /// The chip being heard while the loop plays: the last tap at or before where the ear is now, or `nil`
    /// in the gap before a pass's first tap. Taps are song seconds, and so is the heard clock.
    static func heard(_ reading: LoopClockReading, taps: [TimeInterval]) -> Int? {
        guard let now = TapTally.heardPosition(reading) else { return nil }
        let seconds = reading.regionStart + now.within
        return taps.lastIndex { $0 <= seconds }
    }

    // MARK: - A phrase (0227 D2, after the device check)

    /// How many notes a tap can play: the note alone, up to eight, about a bar of quavers. Past that the
    /// strip's play button, the whole loop, is the better listen.
    static let phraseChoices = [1, 2, 3, 4, 6, 8]

    /// The taps a phrase ending on `index` plays: up to `notes` of them, `index` the last. Near the start
    /// of the pass there are fewer before it to take.
    static func phrase(endingAt index: Int, notes: Int) -> ClosedRange<Int> {
        max(0, index - max(1, notes) + 1)...index
    }

    /// The chip being heard while a phrase plays: the last of its taps the ear has reached, or `nil` before
    /// the first. Never a chip outside the phrase, though the slice starts just before its first tap.
    static func heard(_ reading: SliceClockReading, phrase: ClosedRange<Int>, taps: [TimeInterval]) -> Int? {
        guard let second = AudioSlice.heardSecond(reading) else { return nil }
        return phrase.last { taps.indices.contains($0) && taps[$0] <= second }
    }

    /// What the strip's ring follows: the loop, a phrase of more than one note, or nothing. A single note
    /// is the chip already selected, so it isn't ringed.
    enum Following: Equatable {
        case nothing, loop, phrase(ClosedRange<Int>)

        static func now(loopPlaying: Bool, slicePlaying: Bool, phrase: ClosedRange<Int>?) -> Following {
            if loopPlaying { return .loop }
            if slicePlaying, let phrase, phrase.count > 1 { return .phrase(phrase) }
            return .nothing
        }
    }
}

/// **Name the notes** (ADR 0225, reworked by ADR 0227): the taps of one pass as a strip of numbered chips.
/// Tap a chip to hear a slice of the real recording ending on it (the note alone, or with the notes before
/// it), or play the whole loop along the strip, then say what it was, on the neck or by ear. The player
/// compares by playing it on their own instrument; the app never sounds an answer (0227 D8) and never says
/// whether it's right.
///
/// Opened with the loop already stopped, and a chip stops the loop before its slice, so a slice never
/// plays over it. Presented from `EarTrainingView`'s body root, never from a row (memory: a `.sheet` on
/// a List row loses its write).
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
    /// The By ear kind left selected (0227 D6): it stays from tap to tap until another kind is tapped.
    /// An answer already named by ear uses its own (`activeKind`).
    @State var earKind: EarKind
    /// A By ear answer waiting on *Replace* or *Keep it*, because it would overwrite neck work (0227 D7).
    @State var replacing: PieceLabel?
    /// This piece's instrument and tuning (0227 D3), changed from the *Where did you play it?* row.
    @State var tuning: NamingTuning
    @State var showingInstrument = false
    /// The fret the neck scrolls to: the selected chip's note, set when the chip changes rather than on
    /// every tap, so placing a note never slides the board out from under the finger.
    @State var neckTarget: Int?
    /// **Chords** on the neck (0227 D4): one note per string, so a tap adds rather than replaces. Off by
    /// default; on when the piece already holds a shape.
    @State var chordsOn: Bool
    /// The string of the **ringed** note in a shape, the one bend and vibrato go on.
    @State var ringed: Int?
    /// *Into it* waiting for the neck to say where the note started (0227 D5, a lead-in).
    @State var awaitingStart: LeadInRequest?
    /// While the strip plays the loop or a phrase, the chip being heard. Apart from `active`, so the chip
    /// being named never moves under the player's finger.
    @State var hearing: Int?
    /// How many notes a tap plays, ending on the one being named (0227 D2): *Hear 3 notes* in the strip's
    /// header.
    @AppStorage(AppSettings.Key.namingPhraseNotes) var phraseNotes = AppSettings.namingPhraseNotesDefault
    /// The taps of the phrase last played, which the ring follows while it sounds.
    @State var sounding: ClosedRange<Int>?

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
        _earKind = State(initialValue: NamingMode.openingKind(for: labels, loopType: loopType))
        let tuner = CountTheNotesModel.tunerTuning()
        _tuning = State(initialValue: NamingTuning(openMidi: request.openMidi ?? tuner.openMidi,
                                                   label: request.tuningLabel ?? tuner.label))
        _neckTarget = State(initialValue: labels.first.flatMap { Self.fret(of: $0) })
        _chordsOn = State(initialValue: labels.contains { ($0?.frettedNotes.count ?? 0) > 1 })
        _ringed = State(initialValue: labels.first??.frettedNotes.last?.string)
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
                    strip
                    if let replacing { replacePrompt(replacing) }
                    switch mode {
                    case .fret: neckPicker
                    case .ear: earPicker
                    }
                    moveButtons
                    NamingResultView(labels: labels, active: active, openMidi: tuning.openMidi,
                                     spelling: spelling, mode: mode, tuningLabel: tuning.label)
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
        .onChange(of: active) {
            replacing = nil
            awaitingStart = nil
            neckTarget = Self.fret(of: labels[active]) ?? neckTarget
            ringed = labels[active]?.frettedNotes.last?.string
        }
        .onChange(of: labels) {
            // A join lives on the second note; when the first moves, it can stop fitting (0227 D5).
            let tidy = NeckJoin.tidied(labels)
            if tidy != labels { labels = tidy }
        }
        .onChange(of: mode) {
            replacing = nil
            awaitingStart = nil
            neckTarget = Self.fret(of: labels[active]) ?? neckTarget
        }
        .sheet(isPresented: $showingInstrument) {
            NamingInstrumentSheet(current: tuning, placed: NamingTuning.placed(in: labels)) { next in
                labels = tuning.carrying(labels, to: next)
                tuning = next
            }
        }
        .onDisappear { player.stop() }
    }

    /// A chord loop is tapped once per chord, and calls them chords.
    var noun: String { loopType == .chords ? "chord" : "note" }

    private var subtitle: String {
        let count = request.taps.count
        let what = request.source == .saved ? "Your saved piece" : "This pass"
        return "\(what) · \(count) \(noun)\(count == 1 ? "" : "s"). Tap a \(noun) to hear \(tapPlays), "
            + "or play the whole loop."
    }

    /// What a tap plays, in the subtitle's words, so the header's *Hear 3 notes* is said in full once.
    private var tapPlays: String {
        switch max(1, phraseNotes) - 1 {
        case 0: "just that moment"
        case 1: "it with the \(noun) before it"
        case let before: "it with the \(before) \(noun)s before it"
        }
    }

    /// The fret the neck scrolls to for an answer on it: the middle of its frets, bends included.
    nonisolated static func fret(of label: PieceLabel?) -> Int? {
        let frets = (label?.frettedNotes ?? []).map { $0.fret + $0.bend / 2 }
        guard let low = frets.min(), let high = frets.max() else { return nil }
        return (low + high) / 2
    }

    /// Notes on the neck as tab says them, string then fret then marks, lowest string first: "B8",
    /// "G7b9~".
    func fretText(_ notes: [FrettedNote]) -> String {
        let names = TabLine.stringNames(openMidi: tuning.openMidi)
        return notes.sorted { $0.string > $1.string }.map { note in
            let name = names.indices.contains(note.string)
                ? names[note.string].trimmingCharacters(in: .whitespaces) : "?"
            return name + TabLine.cell(note)
        }.joined(separator: "·")
    }

    // MARK: - Moving and hearing

    /// **Hear it again** plays the real recording, the one sound this sheet makes. **Next unnamed** jumps
    /// to the next gap and goes once every tap has an answer.
    private var moveButtons: some View {
        HStack(spacing: 10) {
            Button("Hear it again") { hearSlice() }
                .buttonStyle(.bordered)
            Spacer(minLength: 0)
            if let gap = NamingStrip.nextUnnamed(after: active, in: labels) {
                Button("Next unnamed") { select(gap) }
                    .buttonStyle(.borderless)
            }
            Button("Next \(noun)") { select(active + 1) }
                .buttonStyle(.bordered)
                .disabled(active >= labels.count - 1)
        }
        .font(.futura(.subheadline))
        .tint(PocketColor.practice)
    }

    /// Go to a chip and hear its moment.
    func select(_ index: Int) {
        guard labels.indices.contains(index) else { return }
        active = index
        hearSlice()
    }

    /// The active chip's moment: the real recording, from just before the first tap of its phrase through
    /// the chip's own, so it ends on the note being named. If the strip is playing the loop, it stops
    /// first: a slice never plays over the loop.
    func hearSlice() {
        if player.isPlaying { player.stop() }
        let phrase = NamingStrip.phrase(endingAt: active, notes: phraseNotes)
        sounding = phrase
        player.playSlice(from: request.taps[phrase.lowerBound].seconds, to: request.taps[active].seconds)
    }

    /// Move to the next chip after an answer is saved, if there is one. Silent: the player asks to hear it.
    func advance() {
        if active < labels.count - 1 { active += 1 }
    }

}

// MARK: - Replace or keep

extension NameTheNotesSheet {

    /// Asked only when By ear would overwrite neck work (0227 D7). Every other change is one tap to redo.
    private func replacePrompt(_ label: PieceLabel) -> some View {
        let placed = fretText(labels[active]?.frettedNotes ?? [])
        let named = label.name(openMidi: tuning.openMidi, spelling: spelling) ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            Text("Replace the \(labels[active]?.frettedNotes.count ?? 0 > 1 ? "shape" : "note") you placed on the "
                 + "neck (\(placed)) with \(named)?")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Replace") {
                    labels[active] = label
                    replacing = nil
                }
                .buttonStyle(.borderedProminent)
                Button("Keep it") { replacing = nil }
                    .buttonStyle(.bordered)
            }
            .font(.futura(.subheadline))
            .tint(PocketColor.practice)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.practice.opacity(0.12)))
    }
}
