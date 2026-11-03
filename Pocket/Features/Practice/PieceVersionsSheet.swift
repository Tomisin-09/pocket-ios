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
                        deleteButton(index)
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
        }
    }

    /// An earlier version's **Delete**, with *Delete this version?* hung on the button itself, not the List:
    /// on iOS 26 the dialog is a popover pointing at the view it hangs from, and from the List it pointed at
    /// the first row. Its own function rather than a chain inside the `Section`, because one modifier added
    /// inline to a Section's builder has crashed a screen on open before (`RoutineDetailView`, 2026-09).
    private func deleteButton(_ index: Int) -> some View {
        Button("Delete", role: .destructive) {
            deleting = index
            confirmingDelete = true
        }
        .confirmationDialog("Delete this version?", isPresented: confirming(index), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete(index) }
        } message: {
            Text("It's removed from this loop for good. The version in use doesn't change.")
        }
    }

    /// Whether *Delete this version?* is up for this version: one flag, read per button, so only the
    /// button that was tapped presents it.
    private func confirming(_ index: Int) -> Binding<Bool> {
        Binding(get: { confirmingDelete && deleting == index },
                set: { if !$0 { confirmingDelete = false } })
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
