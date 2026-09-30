import SwiftUI

/// The loop's **saved piece** (ADR 0225), under Count the notes: its count and names, and the tab drawn
/// from it when any note has a fret. Drawn from the stored piece every time, never kept as text, so the
/// tab can't be edited apart from the piece it came from (**edit pieces, never the picture**).
///
/// **Edit names** reopens Name the notes on it. A new pass saved over it keeps it as an earlier version
/// (ADR 0233), and **Versions** appears to use one again. The Journal shows the one in use under Pieces
/// (ADR 0229).
struct SavedPieceSection: View {
    let loop: Loop
    let spelling: NoteSpelling
    let onEdit: () -> Void
    /// Open **Versions** (ADR 0233 D4). Offered once there's an earlier version.
    let onVersions: () -> Void

    var body: some View {
        if let piece = loop.transcription {
            Section {
                PieceDrawing(piece: piece, spelling: spelling)
                Button("Edit names", action: onEdit)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.practice)
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
}
