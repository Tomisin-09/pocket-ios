import SwiftUI

// **Frets placed before the song's shift changed** (ADR 0305 D5, Q5): named in Standard, then the song was
// raised, and every fret now sounds under the record. The sheet says so over everything else and offers to
// move every fret by the difference on its own string. Nothing moves until the player says so, and a note
// that would fall off the neck is named in the offer, never moved to a string it guessed. The move is one
// step of the history, so ↶ puts it back, and the offer with it. Split out for file length.
extension NameTheNotesSheet {

    /// The offer, while the sheet is still on the strings the piece was heard on and it hasn't been turned
    /// down. Changing the strings in the instrument sheet takes it away too: the player has chosen them.
    @ViewBuilder var refretPrompt: some View {
        if let refret = request.refret, !refretDeclined, tuning.openMidi == request.openMidi {
            VStack(alignment: .leading, spacing: 10) {
                Text(refret.line(playerTuning: Self.tuningName(CountTheNotesModel.tunerTuning().label)))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let stuck = refret.stuckMessage {
                    Text(stuck)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button(refret.button) { applyRefret(refret) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("naming.refret.move")
                    Button("Leave them") { refretDeclined = true }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("naming.refret.leave")
                }
                .font(.futura(.subheadline))
                .tint(PocketColor.practice)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.practice.opacity(0.12)))
            .accessibilityIdentifier("naming.refret")
        }
    }

    /// Move every fret on its string and put the piece on the player's own strings, as one step. The notes
    /// that couldn't move are left unnamed, and the sheet goes to the first of them.
    private func applyRefret(_ refret: PieceRefret) {
        let tuner = CountTheNotesModel.tunerTuning()
        commit(labeled: refret.applied(to: labels), tuning: NamingTuning(openMidi: tuner.openMidi, label: tuner.label))
        if let first = refret.stuck.first { moveTo(first) }
        chipChanged()
    }

    /// *Standard* in *Guitar · Standard*.
    private static func tuningName(_ label: String) -> String {
        label.components(separatedBy: " · ").last ?? label
    }
}
