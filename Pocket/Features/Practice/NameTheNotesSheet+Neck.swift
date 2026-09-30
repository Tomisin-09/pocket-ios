import SwiftUI

// **Fret & string** on the neck (ADR 0227 D3): where you played it. The draw-your-own board with every
// spot carrying its note name faintly, the note being named bold on the practice tint, and the pass's
// other placed notes in ink, so the lick's shape is on the neck as well as in the tab. Split out for
// file length.
extension NameTheNotesSheet {

    var neckPicker: some View {
        let others = otherPlacedSpots
        let heard = Set(NamingStrip.heardNotes(labels, hearing: hearing).map { Spot(string: $0.string, fret: $0.fret) })
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
                let spot = Spot(string: string, fret: fret)
                neckSpot(string: string, fret: fret, isOther: others.contains(spot), isHeard: heard.contains(spot))
            } marks: {
                // The marks are drawn on the note they go on, which after a placement is the one just placed.
                NeckMarksLayer(notes: labels[marked]?.frettedNotes ?? [],
                               previous: marked > 0 ? labels[marked - 1]?.frettedNotes ?? [] : [],
                               join: NeckJoin.symbol(into: marked, of: labels),
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
    private func neckSpot(string: Int, fret: Int, isOther: Bool, isHeard: Bool) -> some View {
        let notes = labels[active]?.frettedNotes ?? []
        let isPlaced = notes.contains { $0.string == string && $0.fret == fret }
        // In a shape, the ringed note is the one bend and vibrato go on.
        let markedNotes = labels[marked]?.frettedNotes ?? []
        let isRinged = markedNotes.count > 1 && string == ringed
            && markedNotes.contains { $0.string == string && $0.fret == fret }
        let name = spelling.name(pitchClass: ((tuning.openMidi[string] + fret) % 12 + 12) % 12)
        let ink: Color = isPlaced ? PocketColor.background
            : isOther ? PocketColor.textPrimary : PocketColor.textSecondary.opacity(0.55)
        let fill: Color = isPlaced ? PocketColor.practice
            : isOther ? PocketColor.textPrimary.opacity(0.18) : PocketColor.surfaceSubtle.opacity(0.5)
        // While *Into it* waits for a start, only the frets it could have come from stay bright.
        let dimmed = awaitingStart.map { request in
            !markedNotes.contains { $0.string == string && $0.fret == fret }
                && !NeckJoin.accepts(string: string, fret: fret, asStartOf: markedNotes, for: request)
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
                .background(HeardHalo(isHeard: isHeard))
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
    ///
    /// With Chords off, **placing a note moves on to the next**, silently (ADR 0234 D3): the strip was a
    /// second tap per note, and moving by tapping a chip played it, which with *Hear 8 notes* was eight
    /// notes every time. The marks stay on the note just placed until the next one is (`placedNote`), and
    /// the board stays put. Tapping the note already there confirms it and moves on.
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
        guard outcome.label.isOnTheNeck else { return }
        let move = NamingCursor.afterPlacing(at: active, count: labels.count, chords: chordsOn)
        // Where it doesn't move on (Chords on, the last note), the marks are the note's own again.
        placedNote = move.marked
        if move.active != active { active = move.active }
    }
}

/// The glow behind a spot while its note sounds (ADR 0227 D2): the strip's ring, on the neck. It pops in
/// as the note plays and fades as the next one takes over, so the lick is seen moving under the fingers;
/// with Reduce Motion it only fades. The neck never scrolls to follow it, so the board can't move under
/// a finger that's naming.
private struct HeardHalo: View {
    let isHeard: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(PocketColor.practice.opacity(0.4))
            .padding(-5)
            .scaleEffect(isHeard || reduceMotion ? 1 : 0.6)
            .opacity(isHeard ? 1 : 0)
            .animation(isHeard ? .easeOut(duration: 0.16) : .easeIn(duration: 0.3), value: isHeard)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
