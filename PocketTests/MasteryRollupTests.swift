import XCTest
@testable import Pocket

/// Covers the pure per-loop → per-song mastery rollup (ADR 0036) — the rounding and
/// empty boundaries that break silently otherwise.
final class MasteryRollupTests: XCTestCase {

    func testEmptyLoopsRollUpToNil() {
        XCTAssertNil(MasteryRollup.rollup([]))
    }

    func testSingleLoopRollsUpToItself() {
        XCTAssertEqual(MasteryRollup.rollup([4]), 4)
    }

    func testAverageOfSeveralLoops() {
        XCTAssertEqual(MasteryRollup.rollup([4, 2]), 3)   // exact mean, no rounding
        XCTAssertEqual(MasteryRollup.rollup([5, 3, 1]), 3)
    }

    func testRoundsToNearest() {
        XCTAssertEqual(MasteryRollup.rollup([5, 0]), 3)   // 2.5 → 3 (away from zero)
        XCTAssertEqual(MasteryRollup.rollup([3, 4, 4]), 4)   // 3.66… → 4
        XCTAssertEqual(MasteryRollup.rollup([1, 1, 2]), 1)   // 1.33… → 1
    }

    func testAllZeroLoopsRollUpToZeroNotNil() {
        // A song with loops that are all unpractised is rated 0 ("Needs work"), distinct
        // from a loopless song, which is nil ("Unrated").
        XCTAssertEqual(MasteryRollup.rollup([0, 0]), 0)
    }
}
