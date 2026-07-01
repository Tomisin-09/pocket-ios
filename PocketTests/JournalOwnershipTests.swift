import XCTest
import SwiftData
@testable import Pocket

/// `JournalEntry` polymorphic ownership + honest per-owner snapshots (ADR 0058). Factory
/// honesty is checked on plain uninserted `@Model` objects; the relationship, cascade delete,
/// and `journalByRecent` sort are proven once in a real in-memory `ModelContainer` (the
/// additive-migration guarantee — a new relationship joins the schema without wiping the store).
final class JournalOwnershipTests: XCTestCase {

    // MARK: - Factory honesty (snapshot never crosses owners)

    func testForLoopSnapshotsMasteryAndFractionOnly() {
        let entry = JournalEntry.forLoop(text: "clean run", kind: .breakthrough,
                                         masteryAtEntry: 3, commandTempoAtEntry: 0.85)
        XCTAssertEqual(entry.masteryAtEntry, 3)
        XCTAssertEqual(entry.commandTempoAtEntry, 0.85)
        XCTAssertNil(entry.commandBpmAtEntry, "a loop entry must not carry an absolute BPM")
    }

    func testForExerciseSnapshotsBpmOnlyAndNoMastery() {
        let entry = JournalEntry.forExercise(text: "held 120", kind: .breakthrough,
                                             commandBpmAtEntry: 120)
        XCTAssertEqual(entry.commandBpmAtEntry, 120)
        XCTAssertNil(entry.masteryAtEntry, "exercises have no mastery")
        XCTAssertNil(entry.commandTempoAtEntry,
                     "an exercise entry must not store a BPM in the song-fraction field")
    }

    func testForExerciseKeepsUnpromotedCommandAsNilBpm() {
        let entry = JournalEntry.forExercise(text: "first pass", kind: .note,
                                             commandBpmAtEntry: nil)
        XCTAssertNil(entry.commandBpmAtEntry)
    }

    // MARK: - Relationship, cascade, and ordering (in-memory store)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testExerciseJournalPersistsAndListsNewestFirst() throws {
        let context = ModelContext(try makeContainer())
        let exercise = Exercise(name: "Alternating picking")
        context.insert(exercise)

        let now = Date()
        let older = JournalEntry.forExercise(text: "80 comfy", kind: .note,
                                             commandBpmAtEntry: 80,
                                             createdAt: now.addingTimeInterval(-3_600))
        let newer = JournalEntry.forExercise(text: "pushed to 100", kind: .breakthrough,
                                             commandBpmAtEntry: 100, createdAt: now)
        context.insert(older)
        context.insert(newer)
        older.exercise = exercise
        newer.exercise = exercise
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.journal.count, 2)
        XCTAssertEqual(fetched.first?.journalByRecent.map(\.text),
                       ["pushed to 100", "80 comfy"], "journal lists newest first")
    }

    func testDeletingExerciseCascadesItsJournal() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        let entry = JournalEntry.forExercise(text: "clean at 90", kind: .breakthrough,
                                             commandBpmAtEntry: 90)
        context.insert(entry)
        entry.exercise = exercise
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 1)

        context.delete(exercise)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0,
                       "cascade delete removes the exercise's entries")
    }

    /// A loop entry and an exercise entry coexist in one store, each keeping its own owner and
    /// honest snapshot — the entry type is polymorphic, not shared-mutated (ADR 0058).
    func testLoopAndExerciseEntriesCoexistWithDistinctOwners() throws {
        let context = ModelContext(try makeContainer())
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        let exercise = Exercise(name: "Spider")
        context.insert(loop)
        context.insert(exercise)

        let loopEntry = JournalEntry.forLoop(text: "loop note", kind: .note,
                                             masteryAtEntry: 2, commandTempoAtEntry: 0.9)
        let exerciseEntry = JournalEntry.forExercise(text: "ex note", kind: .note,
                                                     commandBpmAtEntry: 110)
        context.insert(loopEntry)
        context.insert(exerciseEntry)
        loopEntry.loop = loop
        exerciseEntry.exercise = exercise
        try context.save()

        XCTAssertEqual(loop.journal.count, 1)
        XCTAssertEqual(exercise.journal.count, 1)
        XCTAssertNil(loop.journal.first?.exercise, "loop entry has no exercise owner")
        XCTAssertNil(exercise.journal.first?.loop, "exercise entry has no loop owner")
        XCTAssertEqual(exercise.journal.first?.commandBpmAtEntry, 110)
        XCTAssertNil(exercise.journal.first?.commandTempoAtEntry)
    }
}
