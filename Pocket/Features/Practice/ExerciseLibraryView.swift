import SwiftData
import SwiftUI

/// The **Exercises** library inside Practice (ADR 0046): the focused list of click-only,
/// command-anchored drills — your own plus the seeded starters — pushed from the Practice hub.
/// Owns exercise **creation** (the `+` → `NewExerciseSheet`) and **deletion** (swipe), since
/// exercises live here and nowhere else. Tapping one opens its `ExerciseRunView`.
///
/// Relies on an ambient `NavigationStack` (Practice → Home's stack), like the hub.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var creating = false

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises yet. Tap + to create one — a named drill you push faster "
                     + "over time.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(exercises) { exercise in
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
        .toolbar {
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

    /// Create an exercise anchored on the entered **command** tempo (ADR 0046): the warm-up working
    /// floor and the reach derive from it (pure `TempoStretch`), so the number typed in the sheet is
    /// the command shown on the run screen — no working/command mismatch.
    private func create(name: String, command: Int) {
        guard !name.isEmpty else { return }
        context.insert(Exercise.commandAnchored(name: name, command: command))
        haptic(.medium)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(exercises[index]) }
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
