import SwiftUI

/// The loop's **saved piece** (ADR 0225), under Count the notes, drawn for reading (`PieceDrawing`, ADR
/// 0234 D8): its count, then its tab in rows that fit, with names given by ear above them. Drawn from the
/// stored piece every time, never kept as text, so the tab can't be edited apart from the piece it came
/// from (**edit pieces, never the picture**).
///
/// **Name the notes** opens on it, the only way in since ADR 0234 D1: a pass is saved first and named
/// here, so names can't be left on scratch paper. A new pass saved over it keeps it as an earlier version
/// (ADR 0233), and **Versions** appears to use one again. The Journal shows the one in use under Pieces
/// (ADR 0229). Once something is named on the neck, *Watch it on the neck* sits under Name the notes, to see
/// it back as the loop plays (ADR 0254).
struct SavedPieceSection: View {
    let loop: Loop
    let spelling: NoteSpelling
    /// Open Name the notes on the piece, at a note (0-based): the first, or a snag's (ADR 0234 D7).
    let onEdit: (Int) -> Void
    /// Open **Versions** (ADR 0233 D4). Offered once there's an earlier version.
    let onVersions: () -> Void
    /// Open *Watch it on the neck* (ADR 0254), or `nil` to leave it out: the host passes one only when
    /// there's something to watch (its D2).
    var onWatch: (() -> Void)?

    var body: some View {
        if let piece = loop.transcription {
            Section {
                PieceDrawing(piece: piece, spelling: spelling)
                let snags = loop.snagsOnPiece
                if !snags.isEmpty { snagRows(snags) }
                // One row for the ways to work on the piece, naming it and watching it back: as two rows, the
                // Form drew a divider between them at an inset of its own.
                VStack(alignment: .leading, spacing: 10) {
                    Button("Name the notes") { onEdit(0) }
                        .accessibilityIdentifier("count.saved.name")
                    if let onWatch {
                        Button(action: onWatch) {
                            Label(WatchOnNeckSheet.title, systemImage: WatchOnNeckSheet.symbol)
                        }
                        .accessibilityIdentifier("count.saved.watch")
                    }
                }
                .font(.futura(.subheadline))
                .buttonStyle(.bordered)
                .tint(PocketColor.practice)
                let kept = loop.keptTranscriptions.count
                if kept > 0 {
                    PieceVersionsRow(count: kept + 1, action: onVersions)
                        .font(.futura(.subheadline))
                }
            } header: {
                Text("Saved on this loop")
            } footer: {
                Text("Saving another pass keeps this one as an earlier version. The Journal lists the one in "
                     + "use under Pieces.")
                    .font(.futura(.caption))
            }
        }
    }

    /// **Snags on this piece** (ADR 0234 D7): where the player got stuck, each with the line they left, so
    /// coming back to a half-named lick starts from the note that stopped them. A snag made while playing
    /// the loop is here too, on the note it caught on. Tapping one opens Name the notes on it.
    private func snagRows(_ snags: [PieceSnag]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snags on this piece")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            ForEach(snags, id: \.snag.uid) { placed in
                Button {
                    if let note = placed.note { onEdit(note) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        SnagCatch()
                            .stroke(PocketColor.oracle, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .frame(width: 16, height: 16)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                            .accessibilityHidden(true)
                        Text(Self.words(for: placed, line: loop.line(forSnag: placed.snag.uid)?.text))
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(placed.note == nil)
            }
        }
        .accessibilityIdentifier("count.saved.snags")
    }

    /// "Note 12 · the line", or, with no line, what kind of snag it is. A snag too far from any note says
    /// when it is instead.
    nonisolated static func words(for placed: PieceSnag, line: String?) -> String {
        let place = placed.note.map { "Note \($0 + 1)" }
            ?? "At \(String(format: "%.1f", placed.snag.seconds)) s"
        let what = line ?? (placed.snag.markedWhileNaming == true ? "no line yet" : "snagged while playing")
        return "\(place) · \(what)"
    }
}
