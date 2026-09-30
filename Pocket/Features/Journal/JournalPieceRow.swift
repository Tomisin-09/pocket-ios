import SwiftUI

/// A loop's saved **piece** on the Journal feed (ADR 0229): what it is and the loop it belongs to, one row
/// per loop, drawn from the piece every time, so it is always the current version and never a copy that
/// could be edited apart from it.
///
/// **Folded to its count** since ADR 0234 D8: "98 notes · Guitar · Standard", and *See the notes* opens
/// the piece in place (`PieceDrawing`), tab or names alike, so a long piece is one line on the feed until
/// it's asked for. The loop's caption opens it in *Train your ear*, where **Name the notes** opens on it.
/// No hold menu: a piece isn't pinned or deleted from here, and it has no text of its own to edit.
struct JournalPieceRow: View {
    let piece: JournalPiece
    let ownerLabel: String?
    /// Open the loop in ear training; `nil` when it can't play there (its song's audio is gone).
    let onOpen: (() -> Void)?
    /// When it last changed, as the header shows it: the time under a day's heading, or the day under a
    /// song's (ADR 0232 D20). `nil` means the time.
    var stamp: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            JournalKindRail(tint: KindChip.tint(for: .transcribed))
            VStack(alignment: .leading, spacing: 6) {
                header
                PieceDrawing(piece: piece.piece, spelling: CountTheNotesModel.spelling(for: piece.loop), folds: true)
                if let ownerLabel {
                    JournalOwnerCaption(label: ownerLabel, onOpen: onOpen)
                }
            }
        }
        .padding(.vertical, 6)
    }

    /// 🧩 *Piece* and when it last changed, laid out as a note's kind and time are.
    private var header: some View {
        HStack(spacing: 6) {
            Text(EntryKind.transcribed.emoji)
                .font(.futura(.caption))
                .accessibilityHidden(true)
            Text("Piece")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(KindChip.tint(for: .transcribed))
            Spacer(minLength: 0)
            Text(stamp ?? piece.date.formatted(date: .omitted, time: .shortened))
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }
}
