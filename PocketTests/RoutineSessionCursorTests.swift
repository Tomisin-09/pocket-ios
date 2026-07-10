import XCTest
@testable import Pocket

/// The pure session cursor (ADR 0066, slice 3) — position and advancement over a routine's
/// playable blocks. No SwiftData: the conductor owns the models, this owns the off-by-one
/// stepping that breaks silently, so it's exercised directly (AGENTS.md).
final class RoutineSessionCursorTests: XCTestCase {

    func testStartsAtFirstBlock() {
        let cursor = RoutineSessionCursor(total: 3)
        XCTAssertEqual(cursor.index, 0)
        XCTAssertFalse(cursor.isComplete)
        XCTAssertEqual(cursor.position, 1)
        XCTAssertEqual(cursor.progressLabel, "1 of 3")
    }

    func testAdvanceWalksEveryBlockThenCompletes() {
        var cursor = RoutineSessionCursor(total: 3)
        cursor.advance()
        XCTAssertEqual(cursor.progressLabel, "2 of 3")
        XCTAssertFalse(cursor.isComplete)
        cursor.advance()
        XCTAssertEqual(cursor.progressLabel, "3 of 3")
        XCTAssertFalse(cursor.isComplete)
        cursor.advance()
        XCTAssertTrue(cursor.isComplete)
        XCTAssertEqual(cursor.position, 0)
    }

    func testAdvancePastEndIsClampedNeverRunsOver() {
        var cursor = RoutineSessionCursor(total: 2)
        cursor.advance(); cursor.advance()
        XCTAssertTrue(cursor.isComplete)
        XCTAssertEqual(cursor.index, 2)
        cursor.advance()   // no-op past the end
        XCTAssertEqual(cursor.index, 2)
        XCTAssertTrue(cursor.isComplete)
    }

    func testEmptyRoutineIsImmediatelyComplete() {
        let cursor = RoutineSessionCursor(total: 0)
        XCTAssertTrue(cursor.isComplete)
        XCTAssertEqual(cursor.progressLabel, "")
        XCTAssertEqual(cursor.position, 0)
    }

    func testNegativeCountClampsToEmpty() {
        let cursor = RoutineSessionCursor(total: -4)
        XCTAssertEqual(cursor.total, 0)
        XCTAssertTrue(cursor.isComplete)
    }

    func testSingleBlockProgress() {
        var cursor = RoutineSessionCursor(total: 1)
        XCTAssertEqual(cursor.progressLabel, "1 of 1")
        cursor.advance()
        XCTAssertTrue(cursor.isComplete)
    }

    func testRetreatStepsBackAndClampsAtZero() {
        var cursor = RoutineSessionCursor(total: 3)
        cursor.advance(); cursor.advance()
        XCTAssertEqual(cursor.index, 2)
        cursor.retreat()
        XCTAssertEqual(cursor.index, 1)
        cursor.retreat(); cursor.retreat()   // second is a no-op at the first block
        XCTAssertEqual(cursor.index, 0)
    }

    func testRetreatFromCompleteReturnsToLastBlock() {
        var cursor = RoutineSessionCursor(total: 2)
        cursor.advance(); cursor.advance()
        XCTAssertTrue(cursor.isComplete)
        cursor.retreat()
        XCTAssertFalse(cursor.isComplete)
        XCTAssertEqual(cursor.index, 1)
    }

    // MARK: - Reps (ADR 0076)

    func testSingleRunBlocksHaveNoRepCounter() {
        // The `total:` convenience makes every block a single run — advance walks blocks, no reps.
        var cursor = RoutineSessionCursor(total: 2)
        XCTAssertEqual(cursor.rep, 1)
        XCTAssertEqual(cursor.repsForCurrent, 1)
        XCTAssertFalse(cursor.hasMoreReps)
        XCTAssertEqual(cursor.repLabel, "")   // a single run shows no "Rep 1 of 1"
        cursor.advance()
        XCTAssertEqual(cursor.index, 1)
        XCTAssertEqual(cursor.rep, 1)
    }

    func testAdvanceStepsRepsBeforeRollingToNextBlock() {
        var cursor = RoutineSessionCursor(reps: [3, 1])
        XCTAssertEqual(cursor.repLabel, "Rep 1 of 3")
        XCTAssertTrue(cursor.hasMoreReps)
        cursor.advance()                     // rep 1 → 2, same block
        XCTAssertEqual(cursor.index, 0)
        XCTAssertEqual(cursor.rep, 2)
        XCTAssertEqual(cursor.repLabel, "Rep 2 of 3")
        cursor.advance()                     // rep 2 → 3, same block
        XCTAssertEqual(cursor.index, 0)
        XCTAssertEqual(cursor.rep, 3)
        XCTAssertFalse(cursor.hasMoreReps)   // last rep
        cursor.advance()                     // last rep → next block, rep resets
        XCTAssertEqual(cursor.index, 1)
        XCTAssertEqual(cursor.rep, 1)
    }

    func testSkipAbandonsRemainingRepsAndJumpsBlock() {
        var cursor = RoutineSessionCursor(reps: [3, 2])
        cursor.advance()                     // on rep 2 of block 0
        XCTAssertEqual(cursor.rep, 2)
        cursor.skip()                        // skip the rest of block 0's reps
        XCTAssertEqual(cursor.index, 1)
        XCTAssertEqual(cursor.rep, 1)
        XCTAssertEqual(cursor.repLabel, "Rep 1 of 2")
    }

    func testRetreatResetsTheRepCounter() {
        var cursor = RoutineSessionCursor(reps: [1, 3])
        cursor.advance()                     // to block 1, rep 1
        cursor.advance()                     // block 1, rep 2
        XCTAssertEqual(cursor.rep, 2)
        cursor.retreat()                     // back to block 0, rep reset
        XCTAssertEqual(cursor.index, 0)
        XCTAssertEqual(cursor.rep, 1)
    }

    func testRepsAreClampedToAtLeastOne() {
        let cursor = RoutineSessionCursor(reps: [0, -2])
        XCTAssertEqual(cursor.repsForCurrent, 1)
        XCTAssertEqual(cursor.total, 2)
    }

    func testProgressLabelIsBlockBasedNotRepBased() {
        // "N of M" always counts blocks, so a multi-rep block doesn't inflate the session length.
        var cursor = RoutineSessionCursor(reps: [2, 1])
        XCTAssertEqual(cursor.progressLabel, "1 of 2")
        cursor.advance()                     // still block 1 (rep 2)
        XCTAssertEqual(cursor.progressLabel, "1 of 2")
    }
}
