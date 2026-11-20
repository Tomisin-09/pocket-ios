import SwiftUI

/// Over the neck while picks are watched (ADR 0308 D4–D6): the chord the song is on, its numeral, and what
/// comes next (*then G · VII*). A numeral that isn't the key's own is outlined, with the key's own beside
/// it (*A minor's own here: iv*). With no key set, each chord is its name alone, with no colour and no
/// numeral, and **Set the key** opens Edit song: there's no fallback palette (D6).
struct WatchChordRow: View {
    let chords: WatchChords
    /// The chord to show: the one the song is on, or where the stretch starts while stopped.
    let current: Int?
    /// *A minor*, for the line beside an outlined numeral.
    let keyName: String
    let onSetKey: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let current, chords.chords.indices.contains(current) {
                now(chords.chords[current], next: chords.next(after: current))
                if let own = chords.chords[current].numeral?.keysOwn {
                    Text("\(keyName)'s own here: \(own)")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            if !chords.hasNumerals {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("The song has no key, so its chords have no numerals or colours.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Set the key", action: onSetKey)
                        .font(.futura(.footnote, weight: .semibold))
                        .accessibilityIdentifier("watch.setKey")
                }
            }
        }
    }

    private func now(_ chord: WatchChords.Chord, next: WatchChords.Chord?) -> some View {
        let colour = chord.numeral.map { PocketColor.chord(degree: $0.degree) }
        return HStack(alignment: .center, spacing: 10) {
            Text(chord.name)
                .font(.futura(size: 20, weight: .bold))
                .foregroundStyle(colour ?? PocketColor.textPrimary)
            if let numeral = chord.numeral { ChordNumeralBadge(numeral: numeral) }
            Spacer(minLength: 8)
            if let next {
                Text("then \(next.title)")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill((colour ?? PocketColor.textPrimary).opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chord, \(chord.title)" + (next.map { ", then \($0.title)" } ?? ""))
        .accessibilityIdentifier("watch.chord")
    }
}

/// A chord's numeral (ADR 0308 D6, D7): filled with its colour when it's the key's own, outlined when its
/// root is in the key with another kind, and silver, filled, for a root outside the key.
struct ChordNumeralBadge: View {
    let numeral: ChordNumeral

    var body: some View {
        let colour = PocketColor.chord(degree: numeral.degree)
        Text(numeral.numeral)
            .font(.futura(.subheadline, weight: .bold))
            .foregroundStyle(numeral.isOutlined ? colour : PocketColor.chordInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background {
                if numeral.isOutlined {
                    Capsule().strokeBorder(colour, lineWidth: 1.5)
                } else {
                    Capsule().fill(colour)
                }
            }
    }
}
