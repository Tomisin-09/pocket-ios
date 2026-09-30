import SwiftUI

// **Fret & string** on the neck (ADR 0227 D3): where you played it. The draw-your-own board with every
// spot carrying its note name faintly, the note being named bold on the practice tint, the three notes
// before it filled and the three after it ringed, each numbered (ADR 0234 D4), and the pass's other placed
// notes in ink, so the lick's shape is on the neck as well as in the tab. Split out for file length.
extension NameTheNotesSheet {

    var neckPicker: some View {
        let neighbours = NeckNeighbours.marks(labels, active: active)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                pickerLabel("Where did you play it?")
                Spacer()
                Button {
                    showingInstrument = true
                } label: {
                    Text("\(tuning.label) \(Image(systemName: "chevron.right"))")
                        .font(.futura(.caption))
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("Instrument and tuning, \(tuning.label)")
            }
            FretNeckBoard(stringNames: stringNames, maxFret: PieceLabel.maxFret, scrollTarget: neckTarget,
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
                let name = Text(shape.name(spelling: spelling)).bold().foregroundStyle(PocketColor.practice)
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
        let style = SpotStyle(mark?.tier)
        // While *Into it* waits for a start, only the frets it could have come from stay bright.
        let dimmed = awaitingStart.map { request in
            !markedNotes.contains { $0.string == string && $0.fret == fret }
                && !NeckJoin.accepts(string: string, fret: fret, asStartOf: markedNotes, for: request)
        } ?? false
        return Button {
            place(string: string, fret: fret)
        } label: {
            Text(name)
                .font(.futura(size: isPlaced ? 10 : 9, weight: mark == nil ? .regular : .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(style.ink)
                .frame(width: 24, height: 24)
                .background(Circle().fill(style.fill))
                .overlay(Circle().inset(by: style.ringWidth / 2).stroke(style.ring, lineWidth: style.ringWidth))
                .overlay(Circle().inset(by: -3.5).stroke(isRinged ? PocketColor.practice : .clear, lineWidth: 1.5))
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

    /// A tap on the neck, by `NeckPlacement`'s rules: with Chords off it replaces the note (which keeps its
    /// marks), with Chords on it builds a shape one note per string. A name given by ear just gives way:
    /// only overwriting neck work asks first (0227 D7). A join that no longer fits is dropped by the
    /// sheet's tidy. While *Into it* waits for where a note started, the tap says that instead.
    ///
    /// With Chords off, **placing a note moves on to the next**, silently (ADR 0234 D3): the strip was a
    /// second tap per note, and moving by tapping a chip played it, which with *Hear 8 notes* was eight
    /// notes every time. The marks stay on the note just placed until the next one is (`placedNote`), and
    /// the board stays put. Tapping the note already there confirms it and moves on.
    private func place(string: Int, fret: Int) {
        if awaitingStart == nil { replacing = nil }
        apply(NeckEditing.place(string: string, fret: fret, labels: labels, cursor: cursor))
    }

    /// Write what a rule gave back: the answers as one step of the history (only when they changed), then
    /// where the neck is.
    func apply(_ edit: NeckEditing.Edit) {
        if edit.labels != labels { labels = edit.labels }
        cursor = edit.cursor
    }
}

// MARK: - The cursor, by the names the sheet has always used

extension NameTheNotesSheet {
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
    var chordsOn: Bool {
        get { cursor.chordsOn }
        nonmutating set { cursor.chordsOn = newValue }
    }
    var awaitingStart: LeadInRequest? {
        get { cursor.awaitingStart }
        nonmutating set { cursor.awaitingStart = newValue }
    }
}

// MARK: - The notes around the one being named (ADR 0234 D4)

extension NameTheNotesSheet {
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

    init(_ tier: NeckNeighbours.Tier?) {
        switch tier {
        case .current?:
            self.init(fill: PocketColor.practice, ink: PocketColor.background, ring: .clear, ringWidth: 1,
                      numbered: false)
        case .before(let steps)?:
            let fade = Self.fades[min(max(steps, 1), 3) - 1]
            self.init(fill: PocketColor.practice.opacity(fade),
                      ink: steps == 1 ? PocketColor.background : PocketColor.textPrimary,
                      ring: .clear, ringWidth: 1, numbered: true)
        case .after(let steps)?:
            self.init(fill: .clear, ink: PocketColor.practice,
                      ring: PocketColor.practice.opacity(Self.rings[min(max(steps, 1), 3) - 1]), ringWidth: 2,
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

    var body: some View {
        Text("\(note)")
            .font(.futura(size: 8, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(PocketColor.practice)
            .padding(.horizontal, 3)
            .frame(minWidth: 14, minHeight: 13)
            .background(Capsule().fill(PocketColor.background))
            .overlay(Capsule().stroke(PocketColor.practice, lineWidth: 1))
            .offset(x: 6, y: -5)
            .accessibilityHidden(true)
    }
}
