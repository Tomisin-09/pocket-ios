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

    /// ADR 0151 — **this test used to assert the opposite.** A take outlives the loop it was recorded
    /// against: the relationship nullifies, the row and its audio stay. A loop can be redrawn in a
    /// minute; a recording of someone playing on a particular evening cannot be remade at all, so the
    /// cascade was destroying the one artifact here with no way back.
    func testDeletingTheOwnerLeavesTheTake() throws {
        let context = ModelContext(try makeContainer())
        let loop = Loop(name: "Chorus", start: 0.3, end: 0.5, speed: 1, repeats: 1)
        let take = Recording(fileName: "keep-me.m4a", duration: 8)
        context.insert(loop)
        context.insert(take)
        RecordingOwner.loop(loop).attach(to: take)
        try context.save()

        context.delete(loop)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<Recording>())
        XCTAssertEqual(survivors.count, 1, "deleting a loop must not destroy its takes")
        XCTAssertNil(survivors.first?.loop, "the relationship nullifies")
        XCTAssertEqual(survivors.first?.ownerKind, Recording.OwnerKind.none)
        // The row survives, so RecordingStore's orphan sweep still sees the file as referenced and
        // leaves the audio alone. Deleting the take is now the user's call, not a side effect.
        XCTAssertEqual(survivors.first?.fileName, "keep-me.m4a")
    }

    /// The caption is snapshotted at capture, so an orphaned take still says what it was recorded
    /// against instead of degrading to a bare "Take 0:08".
    func testAnOrphanedTakeKeepsItsCaption() throws {
        let context = ModelContext(try makeContainer())
        let song = Song(title: "Don't Know Why", duration: 200,
                        ref: SongRef(id: "s", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Chords", start: 0.1, end: 0.4, speed: 1, repeats: 1)
        let take = Recording(fileName: "t.m4a", duration: 11)
        context.insert(song)
        context.insert(loop)
        context.insert(take)
        loop.song = song
        RecordingOwner.loop(loop).attach(to: take)
        try context.save()
        XCTAssertEqual(take.ownerLabelAtTake, "Don't Know Why · Chords")

        context.delete(loop)
        try context.save()

        let orphan = try XCTUnwrap(try context.fetch(FetchDescriptor<Recording>()).first)
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .take(orphan)), "Don't Know Why · Chords",
                       "the snapshot carries the caption past the owner's deletion")
    }

    // MARK: - Naming a take (ADR 0069 amendment)
    //
    // Uninserted models throughout — inserting a graph SIGTRAPs in the XCTest host, and none of this
    // needs a store.

    /// An unnamed take renders exactly as it always did, so no existing row changes until the player
    /// names something.
    func testAnUnnamedTakeStillReadsAsATake() {
        XCTAssertNil(Recording(fileName: "x.m4a", duration: 12).title)
        XCTAssertEqual(Recording(fileName: "x.m4a", duration: 12).displayTitle, "Take")
    }

    func testRenamingTrimsWhitespace() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.rename(to: "  Bridge, third attempt \n")
        XCTAssertEqual(take.title, "Bridge, third attempt")
        XCTAssertEqual(take.displayTitle, "Bridge, third attempt")
    }

    /// A cleared field must leave the take as it was rather than storing whitespace that would render
    /// as a blank row with nothing to tap.
    func testRenamingToNothingIsRefused() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.rename(to: "Solo take")
        take.rename(to: "   \n ")
        XCTAssertEqual(take.title, "Solo take")

        let untouched = Recording(fileName: "y.m4a", duration: 12)
        untouched.rename(to: "")
        XCTAssertNil(untouched.title)
    }

    /// Naming a take must make it *findable* by that name — otherwise it is identifiable everywhere
    /// except the search field that exists to find it.
    func testANamedTakeIsSearchableByItsName() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.rename(to: "Bridge run")
        let haystack = JournalTimeline.searchHaystack(for: .take(take))
        XCTAssertTrue(haystack.contains("bridge run"), "a named take must be searchable by its name")
    }

    // MARK: - The take's note (ADR 0174)

    func testANewTakeHasNoNote() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        XCTAssertNil(take.note)
        XCTAssertFalse(take.hasNote)
    }

    func testSettingANoteTrimsWhitespace() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.setNote("  rushed the turnaround  ")
        XCTAssertEqual(take.note, "rushed the turnaround")
        XCTAssertTrue(take.hasNote)
    }

    /// Where a note parts company with a *name*: clearing one is meaningful. A blank name is a
    /// mistake, because a name is how you tell two takes apart; a note you no longer want is a note
    /// you should be able to delete.
    func testClearingANoteRemovesIt() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.setNote("something")
        take.setNote("")
        XCTAssertNil(take.note)
        XCTAssertFalse(take.hasNote)
    }

    /// Whitespace stores as `nil`, never as a note that renders as an empty block.
    func testANoteOfOnlyWhitespaceIsNoNote() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.setNote("   \n  ")
        XCTAssertNil(take.note)
    }

    /// A take's note is deliberately **not** on the Journal's search rail (ADR 0174) — it belongs to
    /// the take's own screen. Pinned so the decision is visible if someone later wonders why a search
    /// for a note's words finds nothing.
    func testANotesWordsAreNotOnTheJournalSearchRail() {
        let take = Recording(fileName: "x.m4a", duration: 12)
        take.setNote("rushed the turnaround")
        let haystack = JournalTimeline.searchHaystack(for: .take(take))
        XCTAssertFalse(haystack.contains("turnaround"))
    }
}
