import SwiftData
import SwiftUI

/// A loop's piece and its earlier versions (ADR 0233 D4): the one in use first, then the rest, newest
/// first, each dated and drawn as *Saved on this loop* draws it. Opened from Saved on this loop and from the
/// map's tab sheet.
///
/// **Use this version** swaps one in and keeps the one it takes over from, so switching never loses
/// anything and switching back is the same action. **Delete** removes an earlier one, after asking. The one
/// in use can't be deleted: use another one first.
struct PieceVersionsSheet: View {
    let loop: Loop
    let spelling: NoteSpelling

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// The earlier version *Delete this version?* is about, by its place in the list.
    @State private var deleting: Int?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                if let piece = loop.transcription {
                    Section {
                        PieceDrawing(piece: piece, spelling: spelling)
                    } header: {
                        header("In use", piece)
                    } footer: {
                        Text("The song map, its tab and the Journal's Pieces show this one.")
                    }
                }
                ForEach(Array(loop.keptTranscriptions.enumerated()), id: \.offset) { index, piece in
                    Section {
                        PieceDrawing(piece: piece, spelling: spelling)
                        Button("Use this version") { use(index) }
                            .foregroundStyle(PocketColor.practice)
                        Button("Delete", role: .destructive) {
                            deleting = index
                            confirmingDelete = true
                        }
                    } header: {
                        header(nil, piece)
                    }
                }
            }
            .navigationTitle("Versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete this version?", isPresented: $confirmingDelete,
                                titleVisibility: .visible, presenting: deleting) { index in
                Button("Delete", role: .destructive) { delete(index) }
            } message: { _ in
                Text("It's removed from this loop for good. The version in use doesn't change.")
            }
        }
    }

    /// *In use · 30 Sep 2026 at 10:12*, or the date alone. Kept in its own case: a list header is
    /// capitalised otherwise, and a date doesn't read in capitals.
    private func header(_ title: String?, _ piece: PieceTranscription) -> some View {
        Text(([title, Self.date(of: piece)].compactMap(\.self)).joined(separator: " · "))
            .textCase(nil)
    }

    /// When the piece last changed (0229 D2), or *Undated* for one saved before pieces kept a date.
    static func date(of piece: PieceTranscription) -> String {
        piece.changedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Undated"
    }

    private func use(_ index: Int) {
        loop.pieceVersions.use(index)
        try? modelContext.save()
        haptic(.success)
    }

    private func delete(_ index: Int) {
        loop.pieceVersions.delete(index)
        try? modelContext.save()
    }
}

/// **Versions · 3**, the way into `PieceVersionsSheet`, shown once a loop has an earlier version (ADR 0233
/// D4). The count is every version, the one in use included.
struct PieceVersionsRow: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label("Versions", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(PocketColor.practice)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(PocketColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .accessibilityLabel("Versions, \(count)")
        .accessibilityHint("Shows this piece's earlier versions, to use one or delete one")
    }
}
