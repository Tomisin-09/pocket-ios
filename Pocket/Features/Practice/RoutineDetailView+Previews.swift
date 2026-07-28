import SwiftData
import SwiftUI

/// Previews for `RoutineDetailView`, split out to keep the editor under the 400-line cap
/// (`swiftlint file_length`), matching the `LibraryView+Previews` / `HomeView+Previews` pattern.
///
/// Two previews, because the entitlement branch is the interesting one (ADR 0112): the Pro editor
/// with its Add affordances, and the **free demo** — the curated routine a free player may open and
/// rearrange but not extend. `\.isPro` defaults to `false`, so the demo preview needs no injection
/// beyond a matching `presetSlug`.

#Preview("Routine detail — Pro") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return NavigationStack { RoutineDetailView(container: container, existing: routine) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("Routine detail — free demo") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Spider Walk", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning Routine")
    routine.presetSlug = RoutinePresets.freeTasteSlug
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return NavigationStack { RoutineDetailView(container: container, existing: routine) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
