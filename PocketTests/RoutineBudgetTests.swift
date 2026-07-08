import XCTest
@testable import Pocket

/// Pure pacing / budget / rest rules for a practice routine (ADR 0066 R7, distilled
/// from ADR 0014). No SwiftData — this layer reasons over `RoutineItemKind` and small
/// value projections only, so every rule is exercised directly.
final class RoutineBudgetTests: XCTestCase {

    // MARK: - Budget accounting (ADR 0014 R1 — only focused work is budgeted)

    func testOnlyFocusedBlocksCountTowardTheBudget() {
        let plan: [RoutineBudget.PlanItem] = [
            .init(.warmup, minutes: 5),
            .init(.focused, minutes: 12),
            .init(.rest, minutes: 3),
            .init(.focused, minutes: 8),
            .init(.play, minutes: 20)
        ]
        // 12 + 8 focused; warm-up / rest / play are surfaced but unbudgeted.
        XCTAssertEqual(RoutineBudget.budgetedMinutes(plan), 20)
    }

    func testBudgetOfNoFocusedWorkIsZero() {
        let plan: [RoutineBudget.PlanItem] = [.init(.warmup, minutes: 10),
                                              .init(.play, minutes: 30)]
        XCTAssertEqual(RoutineBudget.budgetedMinutes(plan), 0)
    }

    func testKindBudgetingFlags() {
        XCTAssertTrue(RoutineItemKind.focused.isBudgeted)
        XCTAssertFalse(RoutineItemKind.warmup.isBudgeted)
        XCTAssertFalse(RoutineItemKind.play.isBudgeted)
        XCTAssertFalse(RoutineItemKind.rest.isBudgeted)
    }

    // MARK: - Block cap + splitting (ADR 0014 R2 — never one long grind)

    func testBlockCapBoundary() {
        XCTAssertFalse(RoutineBudget.exceedsBlockCap(RoutineBudget.maxFocusedMinutes))
        XCTAssertTrue(RoutineBudget.exceedsBlockCap(RoutineBudget.maxFocusedMinutes + 1))
    }

    func testSplitFocusedChunksToTheCeiling() {
        XCTAssertEqual(RoutineBudget.splitFocused(50), [20, 20, 10])
        XCTAssertEqual(RoutineBudget.splitFocused(40), [20, 20])
    }

    func testSplitFocusedLeavesAnUnderCapSpanWhole() {
        XCTAssertEqual(RoutineBudget.splitFocused(12), [12])
        XCTAssertEqual(RoutineBudget.splitFocused(20), [20])
    }

    func testSplitFocusedOfNonPositiveIsEmpty() {
        XCTAssertEqual(RoutineBudget.splitFocused(0), [])
        XCTAssertEqual(RoutineBudget.splitFocused(-5), [])
    }

    // MARK: - Rest proposal (ADR 0014 R3 — a break between focused blocks)

    func testRestInsertedBetweenAdjacentFocusedBlocks() {
        XCTAssertEqual(RoutineBudget.withProposedRests([.focused, .focused]),
                       [.focused, .rest, .focused])
    }

    func testNoRestWhenFocusedBlocksAreAlreadySeparated() {
        XCTAssertEqual(RoutineBudget.withProposedRests([.focused, .warmup, .focused]),
                       [.focused, .warmup, .focused])
    }

    func testRestOnlyBetweenTheFocusedPairInAMixedRun() {
        XCTAssertEqual(
            RoutineBudget.withProposedRests([.warmup, .focused, .focused, .play]),
            [.warmup, .focused, .rest, .focused, .play])
    }

    func testRestBetweenEveryConsecutiveFocusedPair() {
        XCTAssertEqual(RoutineBudget.withProposedRests([.focused, .focused, .focused]),
                       [.focused, .rest, .focused, .rest, .focused])
    }

    func testProposeRestsEdgeCases() {
        XCTAssertEqual(RoutineBudget.withProposedRests([]), [])
        XCTAssertEqual(RoutineBudget.withProposedRests([.focused]), [.focused])
    }

    // MARK: - Orphan rule (ADR 0066 R5 — skip a block whose unit went missing)

    func testUnitBlockWithoutAResolvableUnitIsOrphaned() {
        XCTAssertTrue(RoutineBudget.isOrphaned(kind: .focused, hasResolvableUnit: false))
        XCTAssertTrue(RoutineBudget.isOrphaned(kind: .warmup, hasResolvableUnit: false))
    }

    func testUnitBlockWithAResolvableUnitIsNotOrphaned() {
        XCTAssertFalse(RoutineBudget.isOrphaned(kind: .focused, hasResolvableUnit: true))
    }

    func testRestIsNeverOrphaned() {
        XCTAssertFalse(RoutineBudget.isOrphaned(kind: .rest, hasResolvableUnit: false))
    }
}
