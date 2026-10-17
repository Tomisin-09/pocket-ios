import SwiftData
import SwiftUI

// The Practice hub's previews (ADR 0257), seeded to the canvas boards: a library with something on
// every shelf, and a first run. Split out of `PracticeView` so the screen's file stays about the
// screen.

#Preview("Practice hub — shelves") {
    NavigationStack { PracticeView() }
        .modelContainer(PracticeViewPreviewData.container(populated: true))
        .environment(PracticeReminder(usesSystemNotifications: false))
        .preferredColorScheme(.dark)
}

#Preview("Practice hub — first run") {
    NavigationStack { PracticeView() }
        .modelContainer(PracticeViewPreviewData.container(populated: false))
        .environment(PracticeReminder(usesSystemNotifications: false))
        .preferredColorScheme(.dark)
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Practice hub — regular width (iPad groundwork)") {
    NavigationStack { PracticeView() }
        .modelContainer(PracticeViewPreviewData.container(populated: true))
        .environment(PracticeReminder(usesSystemNotifications: false))
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

/// The seeded store behind the previews.
enum PracticeViewPreviewData {
    @MainActor
    static func container(populated: Bool) -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: Exercise.self, Song.self, Loop.self, Routine.self, RoutineItem.self, PracticeRun.self,
            LongTermGoal.self, Profile.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let drills = seedDrills(populated: populated, in: context)
        seedRoutines(drills: drills, populated: populated, in: context)
        guard populated else { return container }
        for (order, title) in ["Clean up your chord changes", "Build speed", "Tighten your timing"].enumerated() {
            context.insert(LongTermGoal(title: title, order: order))
        }
        seedLoops(in: context)
        return container
    }

    @MainActor
    private static func seedDrills(populated: Bool, in context: ModelContext) -> [Exercise] {
        let kinds: [(String, ExerciseTemplate)] = populated
            ? [("Spider", .basic), ("Chromatic", .warmup), ("Finger rolls", .warmup), ("Folk strum", .strumming),
               ("Alt picking", .picking), ("A minor pentatonic", .scales), ("Canon in D part 1", .chords),
               ("Self control chords", .chords), ("Ivy changes", .chords), ("Groove", .strumChords),
               ("Am7 shape", .arpeggios), ("Hammer run", .legato), ("Sight-read a page", .freeform)]
            : [("Chromatic", .warmup), ("Folk strum", .strumming), ("Alt picking", .picking),
               ("A minor pentatonic", .scales), ("Open chords", .chords), ("Hammer run", .legato)]
        return kinds.map { name, template in
            let drill = Exercise(name: name, currentTempo: 70, commandTempo: 90, template: template)
            context.insert(drill)
            return drill
        }
    }

    @MainActor
    private static func seedRoutines(drills: [Exercise], populated: Bool, in context: ModelContext) {
        let morning = Routine(name: "Morning Routine")
        morning.presetSlug = "morning-warm-up"
        context.insert(morning)
        morning.items = [RoutineItem.item(drills[0], kind: .warmup, order: 0), RoutineItem.rest(order: 1),
                         RoutineItem.item(drills[1], order: 2), RoutineItem.rest(order: 3),
                         RoutineItem.item(drills[2], order: 4), RoutineItem.item(drills[3], order: 5)]
        guard populated else { return }
        morning.isFavorite = true
        logSittings(5, of: morning, lastDaysAgo: 1, in: context)
        for (name, daysAgo) in [("Chord changes", 2.0), ("Canon in D, all parts", 5.0), ("Speed builder", 9.0)] {
            let routine = Routine(name: name, dateAdded: .now.addingTimeInterval(-daysAgo * 86_400 - 3_600))
            context.insert(routine)
            routine.items = [RoutineItem.item(drills[6], order: 0), RoutineItem.rest(order: 1),
                             RoutineItem.item(drills[7], order: 2)]
            logSittings(3, of: routine, lastDaysAgo: daysAgo, in: context)
        }
        let unsaved = Routine(name: "16 Oct Quick Session", dateAdded: .now.addingTimeInterval(-86_400))
        unsaved.isTemporary = true
        context.insert(unsaved)
        unsaved.items = [RoutineItem.item(drills[4], order: 0), RoutineItem.item(drills[5], order: 1)]
    }

    /// `count` sittings a week apart, the latest `lastDaysAgo` days back — what the cards' history
    /// line and the shelf's order read (the practice log, not `lastPracticed`).
    @MainActor
    private static func logSittings(_ count: Int, of routine: Routine, lastDaysAgo: Double,
                                    in context: ModelContext) {
        routine.lastPracticed = .now.addingTimeInterval(-lastDaysAgo * 86_400)
        for week in 0..<count {
            context.insert(PracticeRun(startedAt: .now.addingTimeInterval(-(lastDaysAgo + Double(week) * 7) * 86_400),
                                       durationSeconds: 600, kind: .exercise, routineUID: routine.uid))
        }
    }

    @MainActor
    private static func seedLoops(in context: ModelContext) {
        for (title, count) in [("Slow Bend", 4), ("Self Control", 3), ("Isn't She Lovely", 2)] {
            let song = Song(title: title, artist: "Preview", duration: 180,
                            ref: SongRef(id: "preview-\(title)", source: .localFile, bookmark: nil))
            context.insert(song)
            // Loop bounds are fractions of the song (`Song.sample`'s shape).
            song.loops = (0..<count).map { index in
                let loop = Loop(name: "Section \(index + 1)", start: Double(index) * 0.2,
                                end: Double(index) * 0.2 + 0.15, speed: 1, repeats: 1)
                loop.commandTempo = 0.8
                return loop
            }
        }
    }
}
