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
}
