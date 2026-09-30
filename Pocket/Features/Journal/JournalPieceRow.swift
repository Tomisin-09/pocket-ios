import SwiftUI

/// A loop's saved **piece** on the Journal feed (ADR 0229): its count and names, the tab when any note has
/// a fret, and the loop it belongs to. One row per loop, drawn from the piece every time, so it is always
/// the current version and never a copy that could be edited apart from it.
///
/// Tapping it opens the loop in *Train your ear*, where the piece was made and where **Name the notes** opens on it.
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
                Button { onOpen?() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        header
                        if let line = piece.piece.summary(spelling: CountTheNotesModel.spelling(for: piece.loop)) {
                            Text(line)
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textPrimary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onOpen == nil)
                .accessibilityHint(onOpen == nil ? "" : "Opens the loop in Train your ear")
                tab
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

    /// The tab, scrolling sideways as it does under *Saved on this loop*, and the strings it was written
    /// against. Outside the button, so a sideways drag scrolls it rather than opening the loop.
    @ViewBuilder private var tab: some View {
        if let tab = TabLine.render(piece.piece.labels, openMidi: piece.piece.openMidi ?? []) {
            VStack(alignment: .leading, spacing: 3) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(tab)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textPrimary)
                        .fixedSize()
                }
                if let tuning = piece.piece.tuningLabel {
                    Text(tuning)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }
}
