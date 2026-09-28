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
}

/// **Name the notes** (ADR 0225, reworked by ADR 0227): the taps of one pass as a strip of numbered chips.
/// Tap a chip to hear a slice of the real recording from just before it, then say what it was, on the
/// neck or by ear. The player compares by playing it on their own instrument; the app never sounds an
/// answer (0227 D8) and never says whether it's right.
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
            neckTarget = Self.fret(of: labels[active]) ?? neckTarget
        }
        .sheet(isPresented: $showingInstrument) {
            NamingInstrumentSheet(current: tuning, placed: NamingTuning.placed(in: labels)) { next in
                labels = tuning.carrying(labels, to: next)
                tuning = next
            }
        }
        .onDisappear { player.stopSlice() }
    }

    /// A chord loop is tapped once per chord, and calls them chords.
    var noun: String { loopType == .chords ? "chord" : "note" }

    private var subtitle: String {
        let count = request.taps.count
        let what = request.source == .saved ? "Your saved piece" : "This pass"
        return "\(what) · \(count) \(noun)\(count == 1 ? "" : "s"). Tap a \(noun) to hear just that moment."
    }

    // MARK: - Strip

    /// One row of chips that scrolls sideways and keeps the current one in the middle (0227 D2), so the
    /// picker below stays put for 7 notes or 65, and switching sheets never loses the place.
    private var strip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(noun.capitalized) \(active + 1) of \(labels.count)")
                    .font(.futura(.footnote, weight: .bold))
                    .monospacedDigit()
                Spacer()
                let unnamed = labels.filter { $0 == nil }.count
                Text(unnamed == 0 ? "All named" : "\(unnamed) to name")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(labels.indices, id: \.self) { index in
                            // A join sits between the two chips it joins, on the neck's sheet.
                            if mode == .fret, let join = NeckJoin.symbol(into: index, of: labels) {
                                Text(join)
                                    .font(.pocketMono(.caption))
                                    .fontWeight(.bold)
                                    .foregroundStyle(PocketColor.practice)
                                    .padding(.horizontal, -3)
                                    .accessibilityHidden(true)
                            }
                            chip(index)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 1)
                }
                .mask(stripFade)
                .onAppear { proxy.scrollTo(active, anchor: .center) }
                .onChange(of: active) {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(active, anchor: .center) }
                }
            }
        }
    }

    /// The strip fades out at both ends, so a chip cut off by the edge reads as "more this way".
    private var stripFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 18)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 18)
        }
    }

    private func chip(_ index: Int) -> some View {
        let shown = chipText(index)
        let isActive = index == active
        return Button {
            select(index)
        } label: {
            VStack(spacing: 0) {
                Text("\(index + 1)")
                    .font(.futura(.caption2))
                    .monospacedDigit()
                Text(shown.text ?? "?")
                    .font(.futura(.subheadline, weight: shown.text == nil || shown.dim ? nil : .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? PocketColor.background
                             : shown.text == nil || shown.dim ? PocketColor.textSecondary : PocketColor.textPrimary)
            .padding(.horizontal, 8)
            .frame(minWidth: 46, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? PocketColor.practice : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(noun.capitalized) \(index + 1), \(shown.text ?? "not named")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// What a chip shows. On Fret & string a placed note is its string and fret ("B8"), and a name given
    /// by ear shows dimmed: it can't be drawn there. On By ear every answer is its name, a placed note
    /// read as the note it sounds (0227 D7).
    private func chipText(_ index: Int) -> (text: String?, dim: Bool) {
        guard let label = labels[index] else { return (nil, false) }
        if mode == .fret {
            // A chord of four notes or more is too long to spell out on a chip; its name says it.
            if label.frettedNotes.count > 3 {
                return (label.name(openMidi: tuning.openMidi, spelling: spelling), false)
            }
            if label.isOnTheNeck { return (fretText(label.frettedNotes), false) }
            return (label.name(openMidi: tuning.openMidi, spelling: spelling), true)
        }
        // On By ear a shape that spells no chord shows its interval or notes, dimmed: nothing to name.
        let unread = label.isOnTheNeck && label.earReading(openMidi: tuning.openMidi) == nil
        return (label.name(openMidi: tuning.openMidi, spelling: spelling), unread)
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

    /// The slice for the active chip: the real recording, from just before the tap.
    func hearSlice() {
        player.playSlice(at: request.taps[active].seconds)
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
