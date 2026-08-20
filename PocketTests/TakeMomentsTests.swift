import XCTest
@testable import Pocket

/// `TakeMoments` — what a trim does to notes pinned against the old timeline (ADR 0175).
///
/// The pure counterpart to `TakeTrimTests`, and unit-tested for the reason stated on the type: a
/// moment left on its old seconds after a trim renders as a perfectly plausible row over the wrong
/// audio. There is nothing to see, so there is something to assert.
final class TakeMomentsTests: XCTestCase {

    // MARK: - Rebasing

    func testAMomentInsideTheSpanMovesByTheNewZero() {
        // Keep 40…120 of a take; a note at 1:20 is a note at 0:40 afterwards.
        XCTAssertEqual(TakeMoments.rebase(time: 80, keepStart: 40, keepEnd: 120), .keep(40))
    }

    func testAMomentAtTheSpanStartLandsAtZero() {
        XCTAssertEqual(TakeMoments.rebase(time: 40, keepStart: 40, keepEnd: 120), .keep(0))
    }

    func testAMomentAtTheSpanEndLandsAtTheNewEnd() {
        XCTAssertEqual(TakeMoments.rebase(time: 120, keepStart: 40, keepEnd: 120), .keep(80))
    }

    func testAMomentBeforeTheSpanIsDropped() {
        XCTAssertEqual(TakeMoments.rebase(time: 10, keepStart: 40, keepEnd: 120), .drop)
    }

    func testAMomentAfterTheSpanIsDropped() {
        XCTAssertEqual(TakeMoments.rebase(time: 200, keepStart: 40, keepEnd: 120), .drop)
    }

    /// Handles are placed by eye. A moment a few hundredths outside one is a moment the player meant
    /// to keep, so the same `edgeTolerance` the no-op check uses gives it grace — and the result is
    /// clamped into the span rather than going negative.
    func testAMomentJustOutsideTheSpanIsKeptAndClamped() {
        let result = TakeMoments.rebase(time: 40 - TakeTrim.edgeTolerance / 2,
                                        keepStart: 40, keepEnd: 120)
        XCTAssertEqual(result, .keep(0))
    }

    func testAMomentWellOutsideTheToleranceIsStillDropped() {
        XCTAssertEqual(TakeMoments.rebase(time: 40 - TakeTrim.edgeTolerance * 4,
                                          keepStart: 40, keepEnd: 120), .drop)
    }

    /// A trim that keeps the whole take leaves every moment exactly where it was — the trim is a
    /// no-op and so is the rebase.
    func testKeepingTheWholeTakeMovesNothing() {
        let times: [TimeInterval] = [0, 12, 31, 47]
        let outcome = TakeMoments.rebase(times: times, keepStart: 0, keepEnd: 47)
        XCTAssertEqual(outcome.dropped, 0)
        XCTAssertEqual(outcome.kept.compactMap { $0 }, times)
    }

    // MARK: - Batch

    /// The batch keeps the **order it was given**, holes included, because the caller zips it back
    /// against its own rows — a compacted result would silently pair notes with other notes' times.
    func testTheBatchKeepsPositionWithHolesForDrops() {
        let outcome = TakeMoments.rebase(times: [10, 80, 200], keepStart: 40, keepEnd: 120)
        XCTAssertEqual(outcome.kept.count, 3)
        XCTAssertNil(outcome.kept[0])
        XCTAssertEqual(outcome.kept[1], 40)
        XCTAssertNil(outcome.kept[2])
        XCTAssertEqual(outcome.dropped, 2)
    }

    func testDroppedCountAgreesWithTheBatch() {
        let times: [TimeInterval] = [1, 5, 45, 90, 130, 400]
        let count = TakeMoments.droppedCount(times: times, keepStart: 40, keepEnd: 120)
        XCTAssertEqual(count, TakeMoments.rebase(times: times, keepStart: 40, keepEnd: 120).dropped)
        XCTAssertEqual(count, 4)
    }

    func testNoMomentsMeansNothingDropped() {
        XCTAssertEqual(TakeMoments.droppedCount(times: [], keepStart: 40, keepEnd: 120), 0)
    }

    // MARK: - The sentence the confirmation says

    func testOneNoteIsSingular() {
        XCTAssertEqual(TakeMoments.noteCountPhrase(1), "1 note")
    }

    func testMoreThanOneNoteIsPlural() {
        XCTAssertEqual(TakeMoments.noteCountPhrase(2), "2 notes")
        XCTAssertEqual(TakeMoments.noteCountPhrase(11), "11 notes")
    }

    /// Zero reads as plural too — the warning omits the clause entirely at zero, so this only has to
    /// not say "0 note".
    func testZeroNotesIsPlural() {
        XCTAssertEqual(TakeMoments.noteCountPhrase(0), "0 notes")
    }
}
