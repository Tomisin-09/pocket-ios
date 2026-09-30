import SwiftUI

/// A piece as *Saved on this loop* and **Versions** draw it (ADR 0225, 0233): its line of names, then its
/// tab when any note has a fret, with the tuning it was named in under it. Two rows in a list. Drawn from
/// the piece every time, never kept as text (**edit pieces, never the picture**).
struct PieceDrawing: View {
    let piece: PieceTranscription
    let spelling: NoteSpelling

    var body: some View {
        if let line = piece.summary(spelling: spelling) {
            Text(line)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
        }
        if let tab = TabLine.render(piece.labels, openMidi: piece.openMidi ?? []) {
            VStack(alignment: .leading, spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(tab)
                        .font(.pocketMono(.footnote))
                        .foregroundStyle(PocketColor.textPrimary)
                        .fixedSize()
                }
                if let tuning = piece.tuningLabel {
                    Text(tuning)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }
}
