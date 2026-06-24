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
        // A song whose loops are all rated 0 ("Needs work") is rated 0 — distinct from a
        // loopless or all-unrated song, which is nil ("Unrated").
        XCTAssertEqual(MasteryRollup.rollup([0, 0]), 0)
    }

    // MARK: - Unrated loops are skipped (ADR 0039)

    func testUnratedLoopsAreSkipped() {
        // `nil` = never rated; it must not be averaged as 0. Only the rated loops count.
        XCTAssertEqual(MasteryRollup.rollup([4, nil, 2]), 3)
        XCTAssertEqual(MasteryRollup.rollup([5, nil, nil]), 5)
    }

    func testAllUnratedLoopsRollUpToNil() {
        // A song with loops but no *rated* loop is unrated, like a loopless song.
        XCTAssertNil(MasteryRollup.rollup([nil, nil]))
    }

    func testZeroIsRatedButNilIsNot() {
        // A real 0 still counts; an adjacent nil is skipped — so this averages just the 0.
        XCTAssertEqual(MasteryRollup.rollup([0, nil]), 0)
    }
}
