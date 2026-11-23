import SwiftUI

/// **The chord under the hand**, over a board that plays chords (ADR 0313, *What the phone showed*): its
/// name in its colour, its numeral, and what comes next (*then F · IV*), in Watch it on the neck's idiom
/// (ADR 0308 D4) and with its badge, so a chord's colour means the same thing on both. A run of one chord
/// names the inversion instead, since that's what changes (*C · I · 1st inversion, then 2nd inversion*).
///
/// While nothing is lit (the count-in, or a board that doesn't walk) it names the chord the run starts on.
/// Draws nothing for a drill that doesn't name its chords.
struct DrillChordLine: View {
    let drill: FretboardDrill
    /// The chord playing (`FretboardDrill.chordIndex(at:)`), or `nil` while nothing is lit.
    let chord: Int?

    /// The key spells first, then the preference, as the board spells its notes (ADR 0123).
    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    private var spelling: NoteSpelling {
        drill.spelling(preference: NoteSpelling(rawValue: accidentalRaw) ?? .default)
    }

    var body: some View {
        if let chords = drill.chords, let first = chords.first {
            let index = chord.flatMap { chords.indices.contains($0) ? $0 : nil }
            let current = index.map { chords[$0] } ?? first
            let next = drill.chord(after: index ?? 0)
            let colour = current.numeral.map { PocketColor.chord(degree: $0.degree) }
            ViewThatFits(in: .horizontal) {
                line(current, startsOn: index == nil, next: next, colour: colour)
                line(current, startsOn: index == nil, next: nil, colour: colour)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((colour ?? PocketColor.textPrimary).opacity(0.14)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(words(current, startsOn: index == nil, next: next))
            .accessibilityIdentifier("fretboard.chord")
        }
    }

    private func line(_ current: DrillChord, startsOn: Bool, next: DrillChord?, colour: Color?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            if startsOn {
                Text("Starts on")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(current.name(spelling: spelling))
                .font(.futura(size: 18, weight: .bold))
                .foregroundStyle(colour ?? PocketColor.textPrimary)
            if let numeral = current.numeral { ChordNumeralBadge(numeral: numeral) }
            if let detail = current.detail {
                Text(detail)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            if let next {
                Text("then \(title(of: next, after: current))")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// *F · IV*, or just the inversion when the next chord is this one in another shape.
    private func title(of next: DrillChord, after current: DrillChord) -> String {
        if next.isSameChord(as: current), let detail = next.detail { return detail }
        let name = next.name(spelling: spelling)
        return next.numeral.map { "\(name) · \($0.numeral)" } ?? name
    }

    private func words(_ current: DrillChord, startsOn: Bool, next: DrillChord?) -> String {
        let numeral = current.numeral.map { ", \($0.numeral)" } ?? ""
        let detail = current.detail.map { ", \($0)" } ?? ""
        let then = next.map { ", then \(title(of: $0, after: current))" } ?? ""
        return (startsOn ? "Starts on " : "Chord, ") + current.name(spelling: spelling) + numeral + detail + then
    }
}

#Preview("Chord line") {
    let run = TriadRun.starter
    let drill = run.expanded(beatsPerBar: 4)
    return VStack(alignment: .leading, spacing: 16) {
        DrillChordLine(drill: drill, chord: nil)
        DrillChordLine(drill: drill, chord: 1)
        DrillChordLine(drill: drill, chord: 6)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
