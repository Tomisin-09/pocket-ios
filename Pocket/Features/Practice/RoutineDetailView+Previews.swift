import SwiftData
import SwiftUI

/// Previews for `RoutineDetailView`, split out to keep the editor under the 400-line cap
/// (`swiftlint file_length`), matching the `LibraryView+Previews` / `HomeView+Previews` pattern.
///
/// The preview carries a **description** (ADR 0177) so the read-only rendering of it is in the
/// canvas; it opens read-only, and tapping **Edit** in the running preview is what shows the editable
/// field.

#Preview("Routine detail") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self, PracticeRun.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.notes = "Ten minutes before a lesson — hands first, then the piece."
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return NavigationStack { RoutineDetailView(container: container, existing: routine) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
