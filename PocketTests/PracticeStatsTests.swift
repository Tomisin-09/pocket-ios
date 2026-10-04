import XCTest
@testable import Pocket

/// `PracticeStats.summarize` — the derived home-hub measures (counts + the mastered threshold).
final class PracticeStatsTests: XCTestCase {

    /// A loop rated `mastery` at `command` (`×` of original) — full speed unless said otherwise.
    private func loop(_ mastery: Int?, at command: Double = 1.0) -> PracticeStats.LoopFacts {
        .init(mastery: mastery, command: command)
    }

    func testCountsLoopsAndExercisesAndNotes() {
        let summary = PracticeStats.summarize(loops: [loop(3), loop(nil), loop(5)],
                                              exerciseCount: 4, totalNotes: 7)
        XCTAssertEqual(summary.loops, 3)
        XCTAssertEqual(summary.exercises, 4)
        XCTAssertEqual(summary.notes, 7)
    }

    func testFullMasteryCountsOnlyTopOfScale() {
        // 5 = full mastery; 4 and unrated do not count.
        let summary = PracticeStats.summarize(loops: [loop(5), loop(5), loop(4), loop(nil), loop(1)],
                                              exerciseCount: 0, totalNotes: 0)
        XCTAssertEqual(summary.fullMasteryCount, 2)
    }

    func testFullMasteryIgnoresOutOfRangeHighValues() {
        // Only exactly the ceiling counts — a stray 6 (shouldn't occur) isn't full mastery.
        let summary = PracticeStats.summarize(loops: [loop(6), loop(5)], exerciseCount: 0,
                                              totalNotes: 0)
        XCTAssertEqual(summary.fullMasteryCount, 1)
    }

    func testAFiveBelowFullSpeedIsNotFullMastery() {
        // ADR 0250 D10: a rating is at the current tempo, so a 5 at 60% is the cue to raise, not a
        // loop finished. At or above the record's own speed it counts.
        let summary = PracticeStats.summarize(loops: [loop(5, at: 0.6), loop(5, at: 1.0),
                                                      loop(5, at: 1.25)],
                                              exerciseCount: 0, totalNotes: 0)
        XCTAssertEqual(summary.fullMasteryCount, 2)
    }

    func testFullSpeedIsJudgedOnTheBadgesRoundedPercent() {
        // The badge shows whole percent, so the tile agrees with it: 99.6% reads 100%, 99.4% reads 99%.
        XCTAssertTrue(PracticeStats.hasFullMastery(loop(5, at: 0.996)))
        XCTAssertFalse(PracticeStats.hasFullMastery(loop(5, at: 0.994)))
    }

    func testEmptyWhenNoLoopsOrExercises() {
        XCTAssertTrue(PracticeStats.summarize(loops: [], exerciseCount: 0, totalNotes: 0).isEmpty)
    }

    func testNotEmptyWithOnlyExercises() {
        XCTAssertFalse(PracticeStats.summarize(loops: [], exerciseCount: 2, totalNotes: 0).isEmpty)
    }

    func testNotEmptyWithOnlyLoops() {
        XCTAssertFalse(PracticeStats.summarize(loops: [loop(nil)], exerciseCount: 0, totalNotes: 0)
            .isEmpty)
    }
}
