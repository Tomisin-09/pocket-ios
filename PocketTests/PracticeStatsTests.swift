import XCTest
@testable import Pocket

/// `PracticeStats.summarize` — the derived home-hub measures (counts + the mastered threshold).
final class PracticeStatsTests: XCTestCase {

    func testCountsLoopsAndExercisesAndNotes() {
        let summary = PracticeStats.summarize(loopMasteryValues: [3, nil, 5],
                                              exerciseCount: 4, totalNotes: 7)
        XCTAssertEqual(summary.loops, 3)
        XCTAssertEqual(summary.exercises, 4)
        XCTAssertEqual(summary.notes, 7)
    }

    func testFullMasteryCountsOnlyTopOfScale() {
        // 5 = full mastery; 4 and unrated do not count.
        let summary = PracticeStats.summarize(loopMasteryValues: [5, 5, 4, nil, 1],
                                              exerciseCount: 0, totalNotes: 0)
        XCTAssertEqual(summary.fullMasteryCount, 2)
    }

    func testFullMasteryIgnoresOutOfRangeHighValues() {
        // Only exactly the ceiling counts — a stray 6 (shouldn't occur) isn't full mastery.
        let summary = PracticeStats.summarize(loopMasteryValues: [6, 5], exerciseCount: 0,
                                              totalNotes: 0)
        XCTAssertEqual(summary.fullMasteryCount, 1)
    }

    func testEmptyWhenNoLoopsOrExercises() {
        XCTAssertTrue(PracticeStats.summarize(loopMasteryValues: [], exerciseCount: 0, totalNotes: 0)
            .isEmpty)
    }

    func testNotEmptyWithOnlyExercises() {
        XCTAssertFalse(PracticeStats.summarize(loopMasteryValues: [], exerciseCount: 2,
                                               totalNotes: 0).isEmpty)
    }

    func testNotEmptyWithOnlyLoops() {
        XCTAssertFalse(PracticeStats.summarize(loopMasteryValues: [nil], exerciseCount: 0,
                                               totalNotes: 0).isEmpty)
    }
}
