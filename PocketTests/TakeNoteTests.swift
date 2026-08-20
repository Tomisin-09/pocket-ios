import XCTest
import SwiftData
@testable import Pocket

/// `TakeNote` and `Recording.moments` (ADR 0175) — notes pinned to points in a take.
///
/// Its own file rather than more of `RecordingTests`: the cascade case needs a real in-memory
/// container, which is the shape `RecordingTests` keeps for ownership and nothing else.
final class TakeNoteTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Song.self, Loop.self, Marker.self, JournalEntry.self, Exercise.self,
            Routine.self, RoutineItem.self, Goal.self, Recording.self, TakeNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: - Writing one

    func testANewTakeHasNoMoments() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        XCTAssertTrue(take.moments.isEmpty)
        XCTAssertFalse(take.hasWriting)
    }

    func testAddingAMomentPinsItAndTrimsItsWords() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        let moment = take.addMoment(at: 12, text: "  rushing here  ")
        XCTAssertEqual(moment?.text, "rushing here")
        XCTAssertEqual(moment?.time, 12)
        XCTAssertEqual(take.moments.count, 1)
    }

    /// A moment with no words is a mark with nothing to say — the inverse of the whole-take note,
    /// where clearing the text *is* the delete gesture.
    func testAMomentWithNoWordsIsRefused() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        XCTAssertNil(take.addMoment(at: 12, text: "   \n "))
        XCTAssertTrue(take.moments.isEmpty)
    }

    func testEmptyingAnExistingMomentIsRefused() {
        let moment = TakeNote(time: 12, text: "rushing here")
        XCTAssertFalse(moment.setText("  "))
        XCTAssertEqual(moment.text, "rushing here")
    }

    /// A negative time cannot point into a take, so it clamps rather than being stored and rendering
    /// as a pin off the left edge of the strip.
    func testANegativeTimeClampsToTheStart() {
        XCTAssertEqual(TakeNote(time: -5, text: "x").time, 0)
    }

    // MARK: - Order and labels

    func testMomentsReadInPlaybackOrder() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        take.addMoment(at: 31, text: "second")
        take.addMoment(at: 12, text: "first")
        XCTAssertEqual(take.momentsByTime.map(\.text), ["first", "second"])
    }

    /// Two notes on the same instant keep the order they were **written** in, rather than an
    /// arbitrary one — the only thing that can tell them apart.
    func testMomentsOnTheSameInstantBreakTheTieOnWhenTheyWereWritten() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        let later = TakeNote(time: 12, text: "later", createdAt: Date(timeIntervalSince1970: 200))
        let earlier = TakeNote(time: 12, text: "earlier", createdAt: Date(timeIntervalSince1970: 100))
        take.moments = [later, earlier]
        XCTAssertEqual(take.momentsByTime.map(\.text), ["earlier", "later"])
    }

    func testTheTimeLabelReadsAsMinutesAndSeconds() {
        XCTAssertEqual(TakeNote(time: 0, text: "x").timeLabel, "0:00")
        XCTAssertEqual(TakeNote(time: 62.9, text: "x").timeLabel, "1:02")
        XCTAssertEqual(TakeNote(time: 600, text: "x").timeLabel, "10:00")
    }

    // MARK: - What the row glyph means

    /// The glyph answers "did I write about this one?", and after 0175 there are two ways to have
    /// done so. A take with a moment and no whole-take note still gets it.
    func testATakeWithOnlyAMomentStillReadsAsWrittenOn() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        take.addMoment(at: 12, text: "rushing here")
        XCTAssertFalse(take.hasNote)
        XCTAssertTrue(take.hasWriting)
    }

    // MARK: - Lifetime

    /// **Cascade, the opposite of the take's own rule** (ADR 0151 keeps a take alive past its loop).
    /// A moment is a pointer into audio and means nothing once the audio is gone.
    func testDeletingATakeDeletesItsMoments() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let take = Recording(fileName: "x.m4a", duration: 47)
        context.insert(take)
        take.addMoment(at: 12, text: "rushing here")
        take.addMoment(at: 31, text: "this is the one")
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<TakeNote>()).count, 2)
        // The **back-link**, not just the rows. Counting `TakeNote`s alone passes while
        // `Recording.moments` reads empty, which is the shape the screen renders from — a shoot run
        // caught the section drawn with no rows behind two perfectly persisted notes.
        XCTAssertEqual(try context.fetch(FetchDescriptor<Recording>()).first?.moments.count, 2)

        context.delete(take)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<TakeNote>()).isEmpty)
    }

    /// A moment resolves back to the take it was written on — the inverse is what makes the cascade
    /// above fire at all.
    func testAMomentKnowsItsTake() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let take = Recording(fileName: "x.m4a", duration: 47)
        context.insert(take)
        let moment = take.addMoment(at: 12, text: "rushing here")
        try context.save()
        XCTAssertEqual(moment?.recording?.uid, take.uid)
    }

    /// Same absence as the whole-take note (ADR 0174 §3, carried forward by 0175): a moment is
    /// unreadable away from the strip it points into, so it is not on the Journal's search rail.
    /// Pinned so the decision reads as one if someone searches for a moment's words and finds
    /// nothing.
    func testAMomentsWordsAreNotOnTheJournalSearchRail() {
        let take = Recording(fileName: "x.m4a", duration: 47)
        take.addMoment(at: 12, text: "rushed the turnaround")
        let haystack = JournalTimeline.searchHaystack(for: .take(take))
        XCTAssertFalse(haystack.contains("turnaround"))
    }
}
