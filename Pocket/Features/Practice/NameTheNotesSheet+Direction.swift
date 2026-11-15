import SwiftUI

// **Higher, same or lower** (ADR 0301): the row over the neck where the player says which way the note went
// from the one before, and the dim it makes. The arrows are the player's word, kept while the sheet is open
// and never saved; the rules are `PitchDirection`'s. Split out for file length.
extension NameTheNotesSheet {

    /// The row shows on Fret & string, on a loop of notes (D1): a name by ear has no octave, and a chord has
    /// no one pitch to be higher than.
    var showsDirection: Bool { mode == .fret && loopType != .chords }

    /// What the note before the one being named is, to compare with.
    var noteBefore: PitchDirection.Before {
        PitchDirection.before(active, in: labels, openMidi: tuning.openMidi)
    }

    /// The arrow lit on the note being named.
    var arrow: PitchDirection? {
        taps.indices.contains(active) ? arrows[taps[active].seconds] : nil
    }

    /// What the lit arrow dims, or `nil` when nothing does (D3, D5).
    var narrowing: NeckNarrowing? {
        guard showsDirection else { return nil }
        return NeckNarrowing.make(arrow, at: active, in: labels, openMidi: tuning.openMidi)
    }

    /// The line under the neck while an arrow is lit (D7).
    var directionLine: String? {
        guard showsDirection else { return nil }
        return arrow?.caption(at: active, before: noteBefore, noun: noun, spelling: spelling)
    }

    /// *From note 5 · D* and the three buttons. On note 1 the row stays, with the buttons off, so the neck
    /// doesn't move between the first note and the second.
    var directionRow: some View {
        let before = noteBefore
        let enabled = before != .nothing
        return HStack(spacing: 8) {
            Text(PitchDirection.rowTitle(at: active, before: before, noun: noun, spelling: spelling))
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                ForEach(PitchDirection.allCases, id: \.self) { direction in
                    directionButton(direction, enabled: enabled)
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PocketColor.textPrimary.opacity(0.08)))
        }
    }

    /// One of the three, lit while it's the note's arrow. A second tap takes it off: an arrow isn't an
    /// answer, so ↶ doesn't step through it (D6). Drawn 30 pt tall and touched at 44.
    private func directionButton(_ direction: PitchDirection, enabled: Bool) -> some View {
        let isOn = arrow == direction
        return Button {
            toggleArrow(direction)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: direction.symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(direction.title)
                    .font(.futura(.footnote, weight: isOn ? .bold : nil))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? PocketColor.background : PocketColor.textPrimary)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? PocketColor.practice : .clear))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -7)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        // On note 1 there's no note to compare with, so the word alone.
        .accessibilityLabel(enabled ? direction.spoken(from: active, noun: noun) : direction.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("naming.direction.\(direction.rawValue)")
    }

    /// Light an arrow on the note being named, or take it off if it's already lit.
    private func toggleArrow(_ direction: PitchDirection) {
        guard taps.indices.contains(active) else { return }
        let key = taps[active].seconds
        arrows[key] = arrows[key] == direction ? nil : direction
    }

    /// Take the arrow off the note being named: placing wins (D4).
    func clearArrow() {
        guard taps.indices.contains(active) else { return }
        arrows[taps[active].seconds] = nil
    }
}
