import SwiftUI

/// The loop's **saved piece** (ADR 0225), under Count the notes: its count and names, and the tab drawn
/// from it when any note has a fret. Drawn from the stored piece every time, never kept as text, so the
/// tab can't be edited apart from the piece it came from (**edit pieces, never the picture**).
///
/// **Edit names** reopens Name the notes on it. A new pass saved over it replaces it; the Journal keeps
/// the dated line for each save.
struct SavedPieceSection: View {
    let loop: Loop
    let spelling: NoteSpelling
    let onEdit: () -> Void

    var body: some View {
        if let piece = loop.transcription {
            Section {
                if let line = summary(piece) {
                    Text(line)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .accessibilityIdentifier("count.saved.line")
                }
                if let tab = TabLine.render(piece.labels, openMidi: piece.openMidi ?? []) {
                    VStack(alignment: .leading, spacing: 4) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(tab)
                                .font(.pocketMono(.footnote))
                                .foregroundStyle(PocketColor.textPrimary)
                                .fixedSize()
                                .accessibilityIdentifier("count.saved.tab")
                        }
                        if let tuning = piece.tuningLabel {
                            Text(tuning)
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                }
                Button("Edit names", action: onEdit)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.practice)
            } header: {
                Text("Saved on this loop")
            } footer: {
                Text("Saving another pass replaces this one. Each save also writes a dated line to the loop's "
                    + "Journal.")
                    .font(.futura(.caption))
            }
        }
    }

    private func summary(_ piece: PieceTranscription) -> String? {
        let named = piece.taps.compactMap(\.label)
        return TapTally.summary(count: piece.count, names: piece.names(spelling: spelling), perBeat: nil,
                                countsChords: !named.isEmpty && named.allSatisfy(\.isChord))
    }
}
