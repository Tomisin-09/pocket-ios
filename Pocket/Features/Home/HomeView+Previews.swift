import SwiftData
import SwiftUI

/// A varied home preview seed: a song with a derived mastery and a relative last-practice time
/// (`nil` ⇒ never practised, so it lands after the practised ones and out of the resume card).
private struct HomePreviewSeed {
    let title: String
    let artist: String
    let mastery: Int?
    let practicedOffset: TimeInterval?

    static let library: [HomePreviewSeed] = [
        .init(title: "Little Wing", artist: "Jimi Hendrix", mastery: 2, practicedOffset: -3600 * 5),
        .init(title: "Blue Hour", artist: "The Allmans", mastery: 4, practicedOffset: -86400 * 2),
        .init(title: "Apex", artist: "Arc", mastery: 5, practicedOffset: -86400 * 9),
        .init(title: "Red Moon", artist: "Zydeco Trio", mastery: 1, practicedOffset: nil),
        .init(title: "3 Strikes", artist: "", mastery: nil, practicedOffset: nil)
    ]

    /// A fully seeded in-memory container for the "with history" previews — shared by the
    /// compact and the regular-width (ADR 0105) variants so they stay in lockstep.
    @MainActor static func seededContainer() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: Song.self, Routine.self, RoutineItem.self, Exercise.self, Loop.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let now = Date()
        for seed in library {
            let song = Song.sample()
            song.title = seed.title
            song.artist = seed.artist
            if let mastery = seed.mastery { song.loops.forEach { $0.mastery = mastery } } else { song.loops = [] }
            song.lastPracticed = seed.practicedOffset.map { now.addingTimeInterval($0) }
            container.mainContext.insert(song)
        }
        let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
        container.mainContext.insert(drill)
        for (name, offset) in [("Morning warm-up", -3600.0), ("Speed builder", -86400.0 * 3)] {
            let routine = Routine(name: name)
            routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                             RoutineItem.rest(order: 1),
                             RoutineItem.item(drill, order: 2)]
            routine.lastPracticed = now.addingTimeInterval(offset)
            container.mainContext.insert(routine)
        }
        try? container.mainContext.save()
        return container
    }
}

#Preview("Home — with history") {
    HomeView().modelContainer(HomePreviewSeed.seededContainer())
}

// Regular-width variant (ADR 0105): the layout is dormant on the iPhone-only v1 build, so
// this forces the regular horizontal size class in a wide frame to inspect how the hub caps
// to a centred readable column at iPad / landscape width without an iPad build.
#Preview("Home — regular width (iPad groundwork)") {
    HomeView()
        .modelContainer(HomePreviewSeed.seededContainer())
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

#Preview("Home — first launch") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Song.self, Routine.self, RoutineItem.self, Exercise.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    return HomeView().modelContainer(container)
}
