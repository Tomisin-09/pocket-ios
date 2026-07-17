import SwiftData
import SwiftUI

/// The **"My chords" manager** (ADR 0095 S4) — a list of the player's saved custom voicings, reached from
/// the chord editor's Add / swap menus. Each row shows the chord's diagram + name; **tap to insert** it
/// into the progression, **swipe to delete** it from the library. This exists because a dropdown `Menu`
/// can't host a swipe action, and a growing library needs pruning. It's the interim home for the
/// `SavedChord` collection until the dedicated hub (ADR 0096) gives it a screen of its own.
struct SavedChordsSheet: View {
    /// Called with a saved chord's voicing when the player taps it to insert.
    let onPick: (ChordVoicing) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Newest first — the just-saved chord is at the top where the player looks for it.
    @Query(sort: \SavedChord.createdAt, order: .reverse) private var savedChords: [SavedChord]

    var body: some View {
        NavigationStack {
            Group {
                if savedChords.isEmpty { emptyState } else { list }
            }
            .navigationTitle("My chords")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(PocketColor.practice)
    }

    private var list: some View {
        List {
            ForEach(savedChords) { saved in
                Button {
                    onPick(saved.voicing)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        ChordDiagramView(voicing: saved.voicing, tint: PocketColor.practice)
                            .frame(width: 52)
                        Text(saved.name)
                            .font(.futura(.body, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No saved chords yet", systemImage: "bookmark")
        } description: {
            Text("Build a shape with **Custom chord** and tap **Save to My chords** to keep it here.")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(savedChords[index]) }
    }
}

#Preview("My chords") {
    SavedChordsSheet { _ in }
        .modelContainer(for: SavedChord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
