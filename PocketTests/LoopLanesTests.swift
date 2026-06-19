import XCTest
@testable import Pocket

final class LoopLanesTests: XCTestCase {

    /// Build an interval with a throwaway id, keeping the id so assertions can
    /// look its lane back up.
    private func interval(_ start: Double, _ end: Double) -> LoopLanes.Interval {
        LoopLanes.Interval(id: UUID(), start: start, end: end)
    }

    // MARK: Lane count

    func testEmptyPacksToZeroLanes() {
        let packing = LoopLanes.pack([])
        XCTAssertEqual(packing.laneCount, 0)
    }

    func testDisjointLoopsAllShareOneLane() {
        // Three loops that never overlap pack into a single lane.
        let loops = [interval(0.0, 0.1), interval(0.2, 0.3), interval(0.4, 0.5)]
        let packing = LoopLanes.pack(loops)
        XCTAssertEqual(packing.laneCount, 1)
        for loop in loops { XCTAssertEqual(packing.lane(for: loop.id), 0) }
    }

    func testTwoOverlappingLoopsUseTwoLanes() {
        let a = interval(0.0, 0.4)
        let b = interval(0.2, 0.6)
        let packing = LoopLanes.pack([a, b])
        XCTAssertEqual(packing.laneCount, 2)
        XCTAssertNotEqual(packing.lane(for: a.id), packing.lane(for: b.id))
    }

    func testNestedLoopDropsToSecondLane() {
        // A tight loop fully inside a wide one — the classic nesting case.
        let wide = interval(0.1, 0.9)
        let tight = interval(0.4, 0.5)
        let packing = LoopLanes.pack([wide, tight])
        XCTAssertEqual(packing.laneCount, 2)
        XCTAssertEqual(packing.lane(for: wide.id), 0)   // earlier start → lane 0
        XCTAssertEqual(packing.lane(for: tight.id), 1)
    }

    func testThreeWayOverlapUsesThreeLanes() {
        // Maximum overlap depth of 3 ⇒ exactly 3 lanes (minimum colouring).
        let loops = [interval(0.0, 0.5), interval(0.1, 0.6), interval(0.2, 0.7)]
        let packing = LoopLanes.pack(loops)
        XCTAssertEqual(packing.laneCount, 3)
        XCTAssertEqual(Set(loops.map { packing.lane(for: $0.id) }), [0, 1, 2])
    }

    // MARK: Touching boundaries

    func testTouchingLoopsShareALane() {
        // One ends exactly where the next begins — not an overlap, so one lane.
        let a = interval(0.0, 0.3)
        let b = interval(0.3, 0.6)
        let packing = LoopLanes.pack([a, b])
        XCTAssertEqual(packing.laneCount, 1)
    }

    // MARK: Lane reuse

    func testLaneIsReusedAfterAnIntervalEnds() {
        // A overlaps B (forces lane 1), but C starts after A ends, so C reclaims
        // lane 0 rather than opening a third lane.
        let a = interval(0.0, 0.3)
        let b = interval(0.1, 0.8)   // long loop holds lane 1 open
        let late = interval(0.4, 0.5)   // begins after A ends
        let packing = LoopLanes.pack([a, b, late])
        XCTAssertEqual(packing.laneCount, 2)
        XCTAssertEqual(packing.lane(for: a.id), 0)
        XCTAssertEqual(packing.lane(for: b.id), 1)
        XCTAssertEqual(packing.lane(for: late.id), 0)
    }

    // MARK: Determinism (order independence)

    func testPackingIsIndependentOfInputOrder() {
        let a = interval(0.0, 0.5)
        let b = interval(0.1, 0.6)
        let late = interval(0.7, 0.9)
        let forward = LoopLanes.pack([a, b, late])
        let shuffled = LoopLanes.pack([late, b, a])
        XCTAssertEqual(forward, shuffled)
    }
}
