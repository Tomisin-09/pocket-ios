import XCTest
@testable import Pocket

/// Pure mapping tests for `GoalPriority` (V2 planner Slice 3) — the level ↔ weight bridge the goal
/// editor relies on. No `@Model`s: `GoalPriority` is Foundation-only.
final class GoalPriorityTests: XCTestCase {

    func testWeightsAreOrderedLowNormalHigh() {
        XCTAssertLessThan(GoalPriority.low.weight, GoalPriority.normal.weight)
        XCTAssertLessThan(GoalPriority.normal.weight, GoalPriority.high.weight)
    }

    func testNormalIsNeutralWeight() {
        XCTAssertEqual(GoalPriority.normal.weight, 1.0, accuracy: 0.0001)
    }

    func testNearestSnapsExactWeightsToTheirLevel() {
        for level in GoalPriority.allCases {
            XCTAssertEqual(GoalPriority.nearest(toWeight: level.weight), level)
        }
    }

    func testNearestRoundsToTheClosestLevel() {
        // Just above normal → still normal (closer to 1.0 than to 2.0).
        XCTAssertEqual(GoalPriority.nearest(toWeight: 1.2), .normal)
        // Clearly toward high.
        XCTAssertEqual(GoalPriority.nearest(toWeight: 1.8), .high)
        // Below low → clamps to the nearest, low.
        XCTAssertEqual(GoalPriority.nearest(toWeight: 0.1), .low)
        // Above high → clamps to high.
        XCTAssertEqual(GoalPriority.nearest(toWeight: 5.0), .high)
    }

    func testNearestTieResolvesToLowerLevel() {
        // Exactly between low (0.5) and normal (1.0): 0.75 → the lower, low.
        XCTAssertEqual(GoalPriority.nearest(toWeight: 0.75), .low)
        // Exactly between normal (1.0) and high (2.0): 1.5 → the lower, normal.
        XCTAssertEqual(GoalPriority.nearest(toWeight: 1.5), .normal)
    }
}
