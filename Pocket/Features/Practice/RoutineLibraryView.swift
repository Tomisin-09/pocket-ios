import SwiftData
import SwiftUI

/// The **Routines** library inside Practice (ADR 0066, slice 2): the list of hand-built
/// practice sessions, pushed from the Practice hub. Owns routine **creation** (`+` → a new
/// empty routine you drop straight into the editor) and **deletion** (swipe). Tapping one
/// opens its editor; the auto-advancing player is slice 3, so there is no "Start" yet.
///
/// Relies on the ambient `NavigationStack` (Practice → Home's stack), like the exercise and
/// loop libraries. Sorted newest-first in memory so `@Query` stays unsorted and deletion
/// indexes the displayed order.
struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query private var routines: [Routine]

    /// Drives the push into a fresh-routine editor. The new routine isn't created here — the
    /// editor builds it in its own sandbox and only persists it on Save, so an abandoned
    /// "New routine" never lands in the library.
    @State private var creatingNew = false

    /// Newest first — the same default sort key as the other libraries (`dateAdded`).
    private var ordered: [Routine] {
        routines.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            if routines.isEmpty {
                Text("No routines yet. Tap + to build one — an ordered run of exercises and "
                     + "loops you work through in a sitting.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(ordered) { routine in
                    NavigationLink(value: routine) {
                        row(for: routine)
                    }
                    .listRowBackground(PocketColor.background)
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true; haptic(.light) } label: { Image(systemName: "plus") }
                    .tint(PocketColor.practice)
                    .accessibilityLabel("New routine")
            }
        }
        .navigationDestination(for: Routine.self) { routine in
            RoutineDetailView(container: context.container, existing: routine)
        }
        .navigationDestination(isPresented: $creatingNew) {
            RoutineDetailView(container: context.container, existing: nil)
        }
    }

    /// A routine row — name (or a placeholder) and a one-line summary of its blocks.
    private func row(for routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name.isEmpty ? "Untitled routine" : routine.name)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Text(summary(for: routine))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.practice)
        }
        .padding(.vertical, 2)
    }

    /// "3 units · 1 rest" — the routine's shape at a glance; "Empty" before any blocks.
    private func summary(for routine: Routine) -> String {
        let items = routine.items
        guard !items.isEmpty else { return "Empty" }
        let units = items.filter(\.kind.carriesUnit).count
        let rests = items.count - units
        var parts = ["\(units) unit\(units == 1 ? "" : "s")"]
        if rests > 0 { parts.append("\(rests) rest\(rests == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(ordered[index]) }
        haptic(.medium)
    }
}

#Preview("Routines — with sessions") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Spider", currentTempo: 60)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    container.mainContext.insert(Routine(name: "Alt-picking builder"))
    return NavigationStack { RoutineLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
