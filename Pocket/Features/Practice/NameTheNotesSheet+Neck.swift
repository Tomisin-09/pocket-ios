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
            FretNeckBoard(stringNames: stringNames, maxFret: PieceLabel.maxFret,
                          scrollTarget: neckTarget) { string, fret in
                neckSpot(string: string, fret: fret, isOther: others.contains(Spot(string: string, fret: fret)))
            }
            if let byEar = labels[active], !byEar.isOnTheNeck,
               let name = byEar.name(openMidi: tuning.openMidi, spelling: spelling) {
                Text("Named by ear as \(Text(name).bold()). It can’t be drawn here; placing a note replaces it.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

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
        Set(labels.indices.compactMap { index -> Spot? in
            guard index != active, case .fretted(let string, let fret) = labels[index] else { return nil }
            return Spot(string: string, fret: fret)
        })
    }

    /// A dot with its note name, spelled for the key (ADR 0123). **A faint name is a map, not a hint:** it
    /// reads the same whatever you heard, so it can't point at the answer.
    private func neckSpot(string: Int, fret: Int, isOther: Bool) -> some View {
        let isPlaced = labels[active] == .fretted(string: string, fret: fret)
        let name = spelling.name(pitchClass: ((tuning.openMidi[string] + fret) % 12 + 12) % 12)
        let ink: Color = isPlaced ? PocketColor.background
            : isOther ? PocketColor.textPrimary : PocketColor.textSecondary.opacity(0.55)
        let fill: Color = isPlaced ? PocketColor.practice
            : isOther ? PocketColor.textPrimary.opacity(0.18) : PocketColor.surfaceSubtle.opacity(0.5)
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
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(stringNames[string]) string, \(fret == 0 ? "open" : "fret \(fret)"), \(name)")
        .accessibilityAddTraits(isPlaced ? .isSelected : [])
    }

    /// A tap places the note being named, replacing whatever it was. Tapping the placed note does nothing.
    /// A name given by ear just gives way: only overwriting neck work asks first (0227 D7).
    private func place(string: Int, fret: Int) {
        labels[active] = .fretted(string: string, fret: fret)
        replacing = nil
    }
}
