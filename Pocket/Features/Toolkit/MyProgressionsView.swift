import SwiftData
import SwiftUI

/// **My Progressions** (ADR 0218 D10) — the progressions the player has written, newest first, and the
/// management home for them: tap one to edit it, swipe to delete, **+** to write a new one. The *Use a
/// progression* sheet lists the same rows under *Your progressions* but only inserts from them — the
/// split ADR 0103 D5 made for saved chords, for the same reason: one place to manage, less on the way in.
struct MyProgressionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavedProgression.createdAt, order: .reverse) private var progressions: [SavedProgression]

    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    var body: some View {
        Group {
            if progressions.isEmpty { emptyState } else { list }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("My progressions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProgressionBuilderView(tint: PocketColor.toolkit)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New progression")
            }
        }
        .tint(PocketColor.toolkit)
    }

    private var list: some View {
        List {
            ForEach(progressions) { progression in
                NavigationLink {
                    ProgressionBuilderView(progression: progression, tint: PocketColor.toolkit)
                } label: {
                    row(progression)
                }
            }
            .onDelete { offsets in
                offsets.map { progressions[$0] }.forEach(modelContext.delete)
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// Its name, the chords in the key it was written in, and the numerals that move it anywhere.
    private func row(_ progression: SavedProgression) -> some View {
        let spelling = NoteSpelling(rawValue: accidentalRaw) ?? .default
        let steps = progression.steps
        let key = ProgressionKey(tonic: progression.payload.tonic ?? ProgressionDraft.defaultTonic,
                                 isMinor: steps.readsAsMinor)
        return VStack(alignment: .leading, spacing: 3) {
            Text(progression.name)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(steps.map { key.chordName(of: $0, preference: spelling) }.joined(separator: " · "))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            Text(steps.numerals)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No progressions yet", systemImage: "list.bullet")
        } description: {
            Text("Write a progression once, then use it in any key from any chord exercise.")
        } actions: {
            NavigationLink {
                ProgressionBuilderView(tint: PocketColor.toolkit)
            } label: {
                Label("New progression", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(PocketColor.toolkit)
        }
    }
}

#Preview("My progressions — populated") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SavedProgression.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(SavedProgression(ProgressionDraft(
        name: "Verse changes", tonic: 7, steps: [ProgressionStep(9, .minor), ProgressionStep(5), ProgressionStep(0)])))
    return NavigationStack { MyProgressionsView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("My progressions — empty") {
    NavigationStack { MyProgressionsView() }
        .modelContainer(for: SavedProgression.self, inMemory: true)
        .preferredColorScheme(.dark)
}
