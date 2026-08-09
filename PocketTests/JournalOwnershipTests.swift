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

    /// ADR 0151 — **this test used to assert a cascade.** A note outlives the unit it was written
    /// about, the rule session entries have followed since ADR 0143. An exercise can be rewritten
    /// from the same idea; a note about how practice actually went cannot.
    func testDeletingExerciseLeavesItsJournal() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let exercise = Exercise(name: "Spider")
        context.insert(exercise)
        XCTAssertTrue(JournalWriter.add(to: .exercise(exercise), text: "clean at 90",
                                        kind: .breakthrough, into: context))
        try context.save()

        context.delete(exercise)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<JournalEntry>())
        XCTAssertEqual(survivors.count, 1, "deleting an exercise must not delete notes about it")
        let orphan = try XCTUnwrap(survivors.first)
        XCTAssertNil(orphan.exercise, "the relationship nullifies")
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(orphan)), "Spider · exercise",
                       "the snapshot keeps the note attributed after its unit is gone")
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

    // MARK: - The discriminator (ADR 0143)

    /// `ownerKind` replaced a hand-written `entry.exercise != nil` at each render site. That test was
    /// only ever right while there were exactly **two** owners: a session entry sets neither
    /// relationship, so every one of them would have been rendered with a loop's mastery row. These
    /// four assertions are what stop that regressing quietly.
    ///
    /// Built **uninserted** — property reads only, and inserting a graph SIGTRAPs in the test host.
    func testOwnerKindNamesEachOfTheFourShapes() {
        let exerciseEntry = JournalEntry.forExercise(text: "ex", kind: .note, commandBpmAtEntry: 96)
        exerciseEntry.exercise = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        XCTAssertEqual(exerciseEntry.ownerKind, .exercise)

        let loopEntry = JournalEntry.forLoop(text: "loop", kind: .note, masteryAtEntry: 3,
                                             commandTempoAtEntry: 0.9)
        loopEntry.loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        XCTAssertEqual(loopEntry.ownerKind, .loop)

        let sessionEntry = JournalEntry.forSession(text: "good hour", kind: .session,
                                                   routineUID: UUID(), routineName: "Warm-up",
                                                   units: [])
        XCTAssertEqual(sessionEntry.ownerKind, .session)

        let orphan = JournalEntry.forLoop(text: "owner deleted", kind: .note, masteryAtEntry: nil,
                                          commandTempoAtEntry: nil)
        XCTAssertEqual(orphan.ownerKind, .orphan,
                       "a nullified relationship reads as orphan, not as a loop with no snapshot")
    }

    /// A unit relationship always wins. Otherwise an entry that happened to carry both — a shape
    /// nothing writes today, but nothing forbids either — could start rendering as a session.
    func testAUnitOwnerOutranksARoutineIdCopy() {
        let entry = JournalEntry.forExercise(text: "ex", kind: .note, commandBpmAtEntry: 96)
        entry.exercise = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
        entry.routineUID = UUID()

        XCTAssertEqual(entry.ownerKind, .exercise)
    }

    /// The whole reason the session owner uses loose id copies (ADR 0143, following `PracticeRun`):
    /// there is no relationship, so there is no cascade, so deleting the routine cannot take the
    /// reflection written about it.
    func testASessionEntryHoldsNoRelationshipToCascadeFrom() {
        let entry = JournalEntry.forSession(text: "shoulders tight", kind: .session,
                                            routineUID: UUID(), routineName: "Morning warm-up",
                                            units: [SessionUnitRef(uid: UUID(), title: "Spider",
                                                                   kind: .exercise)])

        XCTAssertNil(entry.loop)
        XCTAssertNil(entry.exercise)
        XCTAssertNil(entry.masteryAtEntry, "a session spans several units — no one mastery is true")
        XCTAssertNil(entry.commandTempoAtEntry)
        XCTAssertNil(entry.commandBpmAtEntry, "…and no one tempo either")
        XCTAssertEqual(entry.routineNameAtEntry, "Morning warm-up")
    }
}
