import XCTest
import SwiftData
@testable import Pocket

/// `Recording` polymorphic ownership (ADR 0069 §5), mirroring `JournalOwnershipTests`. The
/// no-owner case is checked on a plain uninserted `@Model`; owner resolution, precedence, and the
/// additive-migration guarantee (a new `Recording` entity — with links to `Loop`/`Exercise`/`Song`
/// — joins the schema without wiping the store) are proven once in a real in-memory container.
final class RecordingTests: XCTestCase {

    func testNewRecordingWithNoOwnerIsNone() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        XCTAssertEqual(take.ownerKind, .none)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, Goal.self, Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testOwnerKindResolvesPerOwner() throws {
        let context = ModelContext(try makeContainer())

        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        let exercise = Exercise(name: "Spider")
        let song = Song(title: "Etude", duration: 60,
                        ref: SongRef(id: "x", source: .localFile, bookmark: nil))
        let loopTake = Recording(fileName: "l.m4a", duration: 10)
        let exerciseTake = Recording(fileName: "e.m4a", duration: 11)
        let songTake = Recording(fileName: "s.m4a", duration: 12)
        context.insert(loop)
        context.insert(exercise)
        context.insert(song)
        context.insert(loopTake)
        context.insert(exerciseTake)
        context.insert(songTake)
        loopTake.loop = loop
        exerciseTake.exercise = exercise
        songTake.song = song
        try context.save()

        XCTAssertEqual(loopTake.ownerKind, .loop)
        XCTAssertEqual(exerciseTake.ownerKind, .exercise)
        XCTAssertEqual(songTake.ownerKind, .song)
        XCTAssertNil(loopTake.exercise, "a loop take carries no exercise owner")
        XCTAssertNil(exerciseTake.song, "an exercise take carries no song owner")
    }

    func testRecordingOwnerAttachRoutesToTheRightRelationship() throws {
        let context = ModelContext(try makeContainer())
        let loop = Loop(name: "Verse", start: 0, end: 0.2, speed: 0.9, repeats: 2)
        let exercise = Exercise(name: "Spider")
        context.insert(loop)
        context.insert(exercise)

        let loopTake = Recording(fileName: "l.m4a", duration: 5)
        let exerciseTake = Recording(fileName: "e.m4a", duration: 5)
        context.insert(loopTake)
        context.insert(exerciseTake)
        RecordingOwner.loop(loop).attach(to: loopTake)
        RecordingOwner.exercise(exercise).attach(to: exerciseTake)
        try context.save()

        XCTAssertEqual(loopTake.ownerKind, .loop)
        XCTAssertEqual(exerciseTake.ownerKind, .exercise)
        XCTAssertNil(loopTake.exercise)
    }

    func testDeletingOwnerCascadesTheTakeRow() throws {
        let context = ModelContext(try makeContainer())
        let loop = Loop(name: "Chorus", start: 0.3, end: 0.5, speed: 1, repeats: 1)
        let take = Recording(fileName: "reap-me.m4a", duration: 8)
        context.insert(loop)
        context.insert(take)
        take.loop = loop
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recording>()).count, 1)

        context.delete(loop)
        try context.save()

        // Cascade-owned like the journal: deleting the owner removes the take's row. The file is
        // now unreferenced and gets reaped by RecordingStore's orphan sweep (cascade drops the row,
        // not the on-disk audio) — this is why that sweep exists.
        XCTAssertTrue(try context.fetch(FetchDescriptor<Recording>()).isEmpty,
                      "cascade delete removes the owner's takes")
    }
}
