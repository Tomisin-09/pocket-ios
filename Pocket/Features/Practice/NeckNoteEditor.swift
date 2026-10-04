import SwiftUI

/// **The neck you place notes on** (ADR 0227 D3–D5, 0230, 0234 D3–D4), shared by *Name the notes* and the
/// tab writer (ADR 0235 D9) so the two can't drift apart. The draw-your-own board with every spot carrying
/// its note name faintly, the note being worked on bold on the practice tint, the three notes before it
/// filled and the three after it ringed, each numbered, and the other placed notes in ink; then *Chords*,
/// *Into it*, *Bend* and *Vibrato* under it.
///
/// It holds no state of its own. The answers come in as `labels` and go back through `write`, one step of
/// the owner's history each; where the neck is comes in as `cursor`; and a tap on the neck goes to `onPlace`,
/// since placing means something different to each owner: Name the notes names the note it's on, the writer
/// fills its + with a new note. The rules themselves are `NeckEditing`'s. What it says that differs between
/// hearing and writing is `voice`. The instrument row's right-hand end is the owner's (`trailing`).
struct NeckNoteEditor<Trailing: View>: View {
    /// One per note, `nil` where there's none. For the writer, its + is an empty note here.
    let answers: [PieceLabel?]
    @Binding var cursor: NeckCursor
    let tuning: NamingTuning
    let spelling: NoteSpelling
    /// *note* or *chord*, as the owner counts them.
    let noun: String
    let voice: NeckEditorVoice
    /// The fret the board scrolls to, which the owner sets when its note changes rather than on every tap,
    /// so placing a note never slides the board out from under the finger.
    let scrollTarget: Int?
    /// While the owner plays, the note being heard, which glows moving the way it was played.
    var hearing: Int?
    /// New answers, as one step of the owner's history.
    let write: ([PieceLabel?]) -> Void
    /// A tap on the neck.
    let onPlace: (_ string: Int, _ fret: Int) -> Void
    /// *Guitar · Standard ›* tapped: the owner opens its instrument sheet.
    let onInstrument: () -> Void
    /// What the owner puts at the right of the instrument row: Name the notes' ↶ ↷ (ADR 0252 D3). The tab
    /// writer's sit above the neck already, so it passes nothing.
    let trailing: Trailing
    /// Name the notes' practice teal, unless the owner sets another (`neckAccent`).
    @Environment(\.neckAccent) var accent

    var body: some View {
        let neighbours = NeckNeighbours.marks(labels, active: active)
        return VStack(alignment: .leading, spacing: 10) {
            // The instrument on the left, the owner's on the right. The question over it went (0252 D3):
            // the row says what the strings are, and the neck under it is where you place.
            HStack(spacing: 8) {
                Button {
                    onInstrument()
                } label: {
                    Text("\(tuning.label) \(Image(systemName: "chevron.right"))")
                        .font(.futura(.caption))
                }
                .tint(accent)
                .accessibilityLabel("Instrument and tuning, \(tuning.label)")
                Spacer(minLength: 8)
                trailing
            }
            FretNeckBoard(stringNames: stringNames, maxFret: PieceLabel.maxFret, scrollTarget: scrollTarget,
                          headroom: Self.marksHeadroom) { string, fret in
                neckSpot(string: string, fret: fret, mark: neighbours[NeckSpot(string: string, fret: fret)])
            } marks: {
                // The marks are drawn on the note they go on, which after a placement is the one just placed.
                NeckMarksLayer(notes: labels[marked]?.frettedNotes ?? [],
                               previous: marked > 0 ? labels[marked - 1]?.frettedNotes ?? [] : [],
                               join: NeckJoin.symbol(into: marked, of: labels),
                               stringCount: tuning.openMidi.count, maxFret: PieceLabel.maxFret,
                               headroom: Self.marksHeadroom)
            } beneath: {
                // While the loop or a phrase plays, the note being heard glows, moving the way it was played.
                HeardGlows(motions: hearing.map { HaloMotion.motions(into: $0, of: labels) } ?? [], token: hearing,
                           headroom: Self.marksHeadroom)
            }
            if let byEar = labels[active], !byEar.isOnTheNeck,
               let name = byEar.name(openMidi: tuning.openMidi, spelling: spelling) {
                Text("Named by ear as \(Text(name).bold()). It can’t be drawn here; placing a note replaces it.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let shape = NeckShape.read(labels[active]?.frettedNotes ?? [], openMidi: tuning.openMidi) {
                let name = Text(shape.name(spelling: spelling)).bold().foregroundStyle(accent)
                Text("\(shape.word) · \(name)")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            chordsControls
            marksControls
                .padding(.top, 4)
        }
    }

    /// Room above the top string for a bend's arrow and a vibrato's wave.
    private static var marksHeadroom: CGFloat { 16 }

    /// The strings' names down the left edge, thinnest first, as the tab names them.
    private var stringNames: [String] {
        TabLine.stringNames(openMidi: tuning.openMidi).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// A dot with its note name, spelled for the key (ADR 0123). **A faint name is a map, not a hint:** it
    /// reads the same whatever you heard, so it can't point at the answer. A placed note is drawn by where
    /// it sits in the pass from the note being named (`NeckNeighbours`).
    private func neckSpot(string: Int, fret: Int, mark: NeckNeighbours.Mark?) -> some View {
        let isPlaced = mark?.tier == .current
        // In a shape, the ringed note is the one bend and vibrato go on.
        let markedNotes = labels[marked]?.frettedNotes ?? []
        let isRinged = markedNotes.count > 1 && string == ringed
            && markedNotes.contains { $0.string == string && $0.fret == fret }
        let name = spelling.name(pitchClass: ((tuning.openMidi[string] + fret) % 12 + 12) % 12)
        let style = SpotStyle(mark?.tier, accent: accent)
        // While *Into it* waits for a start, only the frets it could have come from stay bright.
        let dimmed = awaitingStart.map { request in
            !markedNotes.contains { $0.string == string && $0.fret == fret }
                && !NeckJoin.accepts(string: string, fret: fret, asStartOf: markedNotes, for: request)
        } ?? false
        return Button {
            onPlace(string, fret)
        } label: {
            Text(name)
                .font(.futura(size: isPlaced ? 10 : 9, weight: mark == nil ? .regular : .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(style.ink)
                .frame(width: 24, height: 24)
                .background(Circle().fill(style.fill))
                .overlay(Circle().inset(by: style.ringWidth / 2).stroke(style.ring, lineWidth: style.ringWidth))
                .overlay(Circle().inset(by: -3.5).stroke(isRinged ? accent : .clear, lineWidth: 1.5))
                .overlay(alignment: .topTrailing) {
                    if let mark, style.numbered { NeighbourNumber(note: mark.note + 1) }
                }
                .opacity(dimmed ? 0.3 : 1)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(stringNames[string]) string, \(fret == 0 ? "open" : "fret \(fret)"), \(name)"
                            + Self.neighbourWords(mark, noun: noun))
        .accessibilityAddTraits(isPlaced ? .isSelected : [])
        .accessibilityHint(isRinged ? "Ringed. Tap again to take it out." : "")
    }

    /// Write what a rule gave back: the answers as one step of the history (only when they changed), then
    /// where the neck is.
    func apply(_ edit: NeckEditing.Edit) {
        if edit.labels != labels { labels = edit.labels }
        cursor = edit.cursor
    }

    // MARK: - Chords (ADR 0227 D4)

    // The *Chords* switch turns a tap from "replace the note" into "one note per string", the rule the My
    // chords placer already uses, so a double-stop, a triad and a six-string chord are the same gesture.
    var chordsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The ⓘ sits beside the switch, never in its label (`InfoPopoverButton`).
            HStack(spacing: 2) {
                rowTitle("Chords")
                InfoPopoverButton(subject: "Chords", info: voice.chordsInfo)
                    .padding(.vertical, -8)
                Spacer(minLength: 8)
                Toggle("Chords", isOn: $cursor.chordsOn)
                    .labelsHidden()
                    .tint(accent)
            }
            if chordsOn {
                Text("Tap other strings to build a chord, one note per string, as in My chords. Tap a note "
                     + "twice to take it out. Bend and vibrato go on the ringed note.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - What the editor reads, by the names the sheet's code has always used

extension NeckNoteEditor {
    /// The answers, read and written: a write is one step of the owner's history.
    var labels: [PieceLabel?] {
        get { answers }
        nonmutating set { write(newValue) }
    }
    var active: Int {
        get { cursor.active }
        nonmutating set { cursor.active = newValue }
    }
    var placedNote: Int? {
        get { cursor.placedNote }
        nonmutating set { cursor.placedNote = newValue }
    }
    var ringed: Int? {
        get { cursor.ringed }
        nonmutating set { cursor.ringed = newValue }
    }
    var awaitingStart: LeadInRequest? {
        get { cursor.awaitingStart }
        nonmutating set { cursor.awaitingStart = newValue }
    }
    var chordsOn: Bool { cursor.chordsOn }
    /// The note the marks go on: the one just placed while the owner has moved past it, else `active`.
    var marked: Int { cursor.marked(count: labels.count) }

    func hint(_ text: String) -> some View { NamingControls.hint(text) }
    func link(_ title: String, action: @escaping () -> Void) -> some View {
        NamingControls.link(title, tint: accent, action: action)
    }

    /// The title of a control under the neck, *Chords*, *Into it* and *Bend*, one size so they read as
    /// one set.
    func rowTitle(_ text: String) -> some View {
        Text(text)
            .font(.futura(.subheadline))
            .lineLimit(1)
    }

    /// Notes on the neck as tab says them, string then fret then marks, lowest string first: "B8",
    /// "G7b9~".
    func fretText(_ notes: [FrettedNote]) -> String { Self.fretText(notes, openMidi: tuning.openMidi) }

    nonisolated static func fretText(_ notes: [FrettedNote], openMidi: [Int]) -> String {
        let names = TabLine.stringNames(openMidi: openMidi)
        return notes.sorted { $0.string > $1.string }.map { note in
            let name = names.indices.contains(note.string)
                ? names[note.string].trimmingCharacters(in: .whitespaces) : "?"
            return name + TabLine.cell(note)
        }.joined(separator: "·")
    }
}

// MARK: - The notes around the one being named (ADR 0234 D4)

extension NeckNoteEditor {
    /// Where a placed note sits from the one being named, said after the spot: ", note 11, 1 before".
    nonisolated static func neighbourWords(_ mark: NeckNeighbours.Mark?, noun: String) -> String {
        guard let mark else { return "" }
        let note = "\(noun) \(mark.note + 1)"
        switch mark.tier {
        case .before(let steps): return ", \(note), \(steps) before"
        case .after(let steps): return ", \(note), \(steps) after"
        case .current: return ", this \(noun)"
        case .other: return ", \(note)"
        }
    }
}

/// How a spot is drawn for its tier. The note being named is solid; the three before are **filled** and
/// the three after **ringed**, both fading with distance, so they differ in shape as well as colour and
/// read with colour filters on; any other placed note is in ink (0227 D3); an empty spot is faint.
private struct SpotStyle {
    let fill: Color
    let ink: Color
    let ring: Color
    let ringWidth: CGFloat
    /// Neighbours carry their note number, so the line reads in order where it crosses itself.
    let numbered: Bool

    private static let fades: [Double] = [0.64, 0.38, 0.2]
    private static let rings: [Double] = [0.95, 0.6, 0.32]

    init(_ tier: NeckNeighbours.Tier?, accent: Color) {
        switch tier {
        case .current?:
            self.init(fill: accent, ink: PocketColor.background, ring: .clear, ringWidth: 1,
                      numbered: false)
        case .before(let steps)?:
            let fade = Self.fades[min(max(steps, 1), 3) - 1]
            self.init(fill: accent.opacity(fade),
                      ink: steps == 1 ? PocketColor.background : PocketColor.textPrimary,
                      ring: .clear, ringWidth: 1, numbered: true)
        case .after(let steps)?:
            self.init(fill: .clear, ink: accent,
                      ring: accent.opacity(Self.rings[min(max(steps, 1), 3) - 1]), ringWidth: 2,
                      numbered: true)
        case .other?:
            self.init(fill: PocketColor.textPrimary.opacity(0.18), ink: PocketColor.textPrimary, ring: .clear,
                      ringWidth: 1, numbered: false)
        case nil:
            self.init(fill: PocketColor.surfaceSubtle.opacity(0.5), ink: PocketColor.textSecondary.opacity(0.55),
                      ring: PocketColor.surfaceBorder, ringWidth: 1, numbered: false)
        }
    }

    private init(fill: Color, ink: Color, ring: Color, ringWidth: CGFloat, numbered: Bool) {
        self.fill = fill
        self.ink = ink
        self.ring = ring
        self.ringWidth = ringWidth
        self.numbered = numbered
    }
}

/// A neighbour's note number, tucked on its top right corner.
private struct NeighbourNumber: View {
    let note: Int
    @Environment(\.neckAccent) private var accent

    var body: some View {
        Text("\(note)")
            .font(.futura(size: 8, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(accent)
            .padding(.horizontal, 3)
            .frame(minWidth: 14, minHeight: 13)
            .background(Capsule().fill(PocketColor.background))
            .overlay(Capsule().stroke(accent, lineWidth: 1))
            .offset(x: 6, y: -5)
            .accessibilityHidden(true)
    }
}

// MARK: - The accent (ADR 0235 D3)

private struct NeckAccentKey: EnvironmentKey {
    static let defaultValue: Color = PocketColor.practice
}

extension EnvironmentValues {
    /// The neck editor's colour: the current spot, the neighbours, the marks and the switches. Name the
    /// notes' practice teal by default; the tab writer sets Toolkit's indigo, where it lives.
    var neckAccent: Color {
        get { self[NeckAccentKey.self] }
        set { self[NeckAccentKey.self] = newValue }
    }
}
