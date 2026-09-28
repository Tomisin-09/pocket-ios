import SwiftUI

// **Fret & string** on the neck (ADR 0227 D3): where you played it. The draw-your-own board with every
// spot carrying its note name faintly, the note being named bold on the practice tint, and the pass's
// other placed notes in ink, so the lick's shape is on the neck as well as in the tab. Split out for
// file length.
extension NameTheNotesSheet {

    var neckPicker: some View {
        let others = otherPlacedSpots
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
                neckSpot(string: string, fret: fret, isOther: others.contains(Spot(string: string, fret: fret)))
            } marks: {
                NeckMarksLayer(notes: labels[active]?.frettedNotes ?? [],
                               previous: active > 0 ? labels[active - 1]?.frettedNotes ?? [] : [],
                               join: NeckJoin.symbol(into: active, of: labels),
                               stringCount: tuning.openMidi.count, maxFret: PieceLabel.maxFret,
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

    /// One place on the neck, as a set member.
    struct Spot: Hashable {
        let string: Int
        let fret: Int
    }

    /// The strings' names down the left edge, thinnest first, as the tab names them.
    private var stringNames: [String] {
        TabLine.stringNames(openMidi: tuning.openMidi).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Where the pass's other answers sit on the neck: drawn in ink, a map of the lick so far.
    private var otherPlacedSpots: Set<Spot> {
        Set(labels.indices.flatMap { index -> [Spot] in
            guard index != active else { return [] }
            return (labels[index]?.frettedNotes ?? []).map { Spot(string: $0.string, fret: $0.fret) }
        })
    }

    /// A dot with its note name, spelled for the key (ADR 0123). **A faint name is a map, not a hint:** it
    /// reads the same whatever you heard, so it can't point at the answer.
    private func neckSpot(string: Int, fret: Int, isOther: Bool) -> some View {
        let notes = labels[active]?.frettedNotes ?? []
        let isPlaced = notes.contains { $0.string == string && $0.fret == fret }
        // In a shape, the ringed note is the one bend and vibrato go on.
        let isRinged = isPlaced && notes.count > 1 && string == ringed
        let name = spelling.name(pitchClass: ((tuning.openMidi[string] + fret) % 12 + 12) % 12)
        let ink: Color = isPlaced ? PocketColor.background
            : isOther ? PocketColor.textPrimary : PocketColor.textSecondary.opacity(0.55)
        let fill: Color = isPlaced ? PocketColor.practice
            : isOther ? PocketColor.textPrimary.opacity(0.18) : PocketColor.surfaceSubtle.opacity(0.5)
        // While *Into it* waits for a start, only the frets it could have come from stay bright.
        let dimmed = awaitingStart.map { request in
            !isPlaced && !NeckJoin.accepts(string: string, fret: fret, asStartOf: notes, for: request)
        } ?? false
        return Button {
            place(string: string, fret: fret)
        } label: {
            Text(name)
                .font(.futura(size: isPlaced ? 10 : 9, weight: isPlaced || isOther ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(ink)
                .frame(width: 24, height: 24)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(isPlaced || isOther ? .clear : PocketColor.surfaceBorder, lineWidth: 1))
                .overlay(Circle().inset(by: -3.5).stroke(isRinged ? PocketColor.practice : .clear, lineWidth: 1.5))
                .opacity(dimmed ? 0.3 : 1)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(stringNames[string]) string, \(fret == 0 ? "open" : "fret \(fret)"), \(name)")
        .accessibilityAddTraits(isPlaced ? .isSelected : [])
        .accessibilityHint(isRinged ? "Ringed. Tap again to take it out." : "")
    }

    /// A tap on the neck, by `NeckPlacement`'s rules: with Chords off it replaces the note (which keeps its
    /// marks), with Chords on it builds a shape one note per string. A name given by ear just gives way:
    /// only overwriting neck work asks first (0227 D7). A join that no longer fits is dropped by the
    /// sheet's tidy. While *Into it* waits for where a note started, the tap says that instead.
    private func place(string: Int, fret: Int) {
        if let awaitingStart {
            takeStart(string: string, fret: fret, for: awaitingStart)
            return
        }
        replacing = nil
        let outcome = NeckPlacement.tap(string: string, fret: fret, on: labels[active], ringed: ringed,
                                        chords: chordsOn)
        if outcome.label != labels[active] { labels[active] = outcome.label }
        ringed = outcome.ringed
    }
}
