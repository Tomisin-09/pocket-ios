import SwiftData
import SwiftUI

/// The **Exercises** library inside Practice (ADR 0046): the focused list of click-only,
/// command-anchored drills — your own plus the seeded starters — pushed from the Practice hub.
/// Owns exercise **creation** (the `+` → `NewExerciseSheet`) and **deletion** (swipe), since
/// exercises live here and nowhere else. Tapping one opens its `ExerciseRunView`.
///
/// Relies on an ambient `NavigationStack` (Practice → Home's stack), like the hub. Sort key +
/// direction and the search query narrow the list in memory (ADR 0056) via the pure
/// `PracticeLibrarySort`, so `@Query` stays unsorted and deletion indexes the *displayed* list.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @State private var creating = false
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("exerciseLibrarySort") private var sortKey: ExerciseSortKey = .name
    @AppStorage("exerciseLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""

    /// The exercises narrowed by search and ordered by the current sort — the list the user sees,
    /// and the one deletion offsets must index into.
    private var visibleExercises: [Exercise] {
        let matched = exercises
            .filter { PracticeLibrarySort.exerciseMatches(fields(for: $0), query: searchText) }
        return PracticeLibrarySort.sortedExercises(matched, by: sortKey,
                                                   ascending: sortAscending, fields: fields(for:))
    }

    private func fields(for exercise: Exercise) -> ExerciseSortFields {
        ExerciseSortFields(name: exercise.name, command: exercise.command,
                           dateAdded: exercise.dateAdded)
    }

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises yet. Tap + to create one — a named drill you push faster "
                     + "over time.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if visibleExercises.isEmpty {
                Text("No exercises match “\(searchText)”.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(visibleExercises) { exercise in
                    NavigationLink {
                        ExerciseRunView(exercise: exercise)
                    } label: {
                        PracticeUnitRow(title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                                        progress: "Command \(exercise.command) → "
                                            + "\(exercise.derivedTarget) BPM")
                    }
                    .listRowBackground(PocketColor.background)
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Exercises")
        .toolbar {
            if !exercises.isEmpty {
                ToolbarItem(placement: .topBarLeading) { sortMenu }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true; haptic(.light) } label: {
                    Image(systemName: "plus")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("New exercise")
            }
        }
        .sheet(isPresented: $creating) {
            NewExerciseSheet(onCreate: create)
        }
    }

    /// The sort control — a menu whose label spells out the active key with a direction arrow
    /// (ADR 0056, mirroring the song library and the loop library).
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortKey) {
                ForEach(ExerciseSortKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
            Picker("Order", selection: $sortAscending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                Text(sortKey.label)
            }
            .tint(PocketColor.practice)
        }
        .accessibilityLabel("Sort by \(sortKey.label), \(sortAscending ? "ascending" : "descending")")
    }

    /// Create an exercise anchored on the entered **command** tempo (ADR 0046): the warm-up working
    /// floor and the reach derive from it (pure `TempoStretch`), so the number typed in the sheet is
    /// the command shown on the run screen — no working/command mismatch. The chosen meter is stored
    /// so the run metronome accents + count-in match it (ADR 0052).
    private func create(name: String, command: Int, signature: TimeSignature) {
        guard !name.isEmpty else { return }
        context.insert(Exercise.commandAnchored(name: name, command: command,
                                                beatsPerBar: signature.beats,
                                                noteValue: signature.noteValue))
        haptic(.medium)
    }

    private func delete(at offsets: IndexSet) {
        let shown = visibleExercises
        for index in offsets { context.delete(shown[index]) }
        haptic(.medium)
    }
}

#Preview("Exercises — with units") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96))
    container.mainContext.insert(Exercise(name: "Spider", currentTempo: 60))
    return NavigationStack { ExerciseLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
