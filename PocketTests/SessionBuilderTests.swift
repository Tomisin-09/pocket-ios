import XCTest
@testable import Pocket

/// The planner's back-half (V2 planner, ADR 0014; block model ADR 0129) — pure session layout,
/// SwiftData-free. A preset denominates **focused blocks**, not minutes: the builder fills an item
/// count, chunks it into R2-sized blocks, and rests between *blocks*.
final class SessionBuilderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func candidate(minutes: Int = 12,
                           mastery: Int? = nil,
                           lastPracticed: Date? = nil,
                           priority: Double = 1.0,
                           uid: UUID = UUID()) -> PlannerCandidate {
        PlannerCandidate(unit: PlannerUnitRef(uid, .exercise), priority: priority,
                         mastery: mastery, lastPracticed: lastPracticed, estimatedMinutes: minutes)
    }

    private func focusMinutes(_ blocks: [SessionBlock]) -> Int {
        blocks.reduce(0) { total, block in
            if case let .focus(_, minutes, _) = block { return total + minutes }
            return total
        }
    }

    private func focusRefs(_ blocks: [SessionBlock]) -> [PlannerUnitRef] {
        blocks.compactMap { if case let .focus(ref, _, _) = $0 { return ref } else { return nil } }
    }

    private func restCount(_ blocks: [SessionBlock]) -> Int {
        blocks.filter { $0.kind == .rest }.count
    }

    private func pool(_ count: Int) -> [PlannerCandidate] {
        (0..<count).map { _ in candidate() }
    }

    // MARK: - The preset is a count of blocks (ADR 0129)

    func testPresetsScheduleTheirItemCounts() {
        // `allCases` is declaration order: quick · focused · full.
        XCTAssertEqual(SessionLength.allCases.map(\.items), [3, 6, 12])
        XCTAssertEqual(SessionLength.allCases.map(\.blocks), [1, 2, 4])
    }

    func testQuickBuildsOneBlockOfThreeWithNoRest() {
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(10), now: now)
        XCTAssertEqual(focusRefs(blocks).count, 3)
        XCTAssertEqual(restCount(blocks), 0, "one block has nothing to rest between")
        // 15-minute block shared by three items.
        XCTAssertEqual(focusMinutes(blocks), 15)
    }

    func testFocusedBuildsTwoBlocksWithOneRest() {
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: pool(10), now: now)
        XCTAssertEqual(focusRefs(blocks).count, 6)
        XCTAssertEqual(restCount(blocks), 1)
        XCTAssertEqual(focusMinutes(blocks), 30)
    }

    func testFullBuildsFourBlocksWithThreeRests() {
        let blocks = SessionBuilder.buildSession(length: .full, candidates: pool(20), now: now)
        XCTAssertEqual(focusRefs(blocks).count, 12)
        XCTAssertEqual(restCount(blocks), 3)
        // Lands exactly on R7's hour — the ceiling is structural now, not a clamp.
        XCTAssertEqual(focusMinutes(blocks), SessionBuilder.maxSessionMinutes)
    }

    /// The regression this whole change exists for: a pool of one-minute-estimating exercises used to
    /// fill a "Quick 15" with fifteen items and fourteen rests — 31 blocks, ~72 minutes.
    func testAShortEstimatingPoolNoLongerFloodsTheSession() {
        let stubs = (0..<20).map { _ in candidate(minutes: 1) }
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: stubs, now: now)
        XCTAssertEqual(focusRefs(blocks).count, 3)
        XCTAssertEqual(restCount(blocks), 0)
        XCTAssertEqual(blocks.count, 3)
    }

    func testCandidateEstimateNoLongerSetsItsSlot() {
        // A one-minute item and a thirty-minute item get the same share: the block decides, and the
        // ramp is fitted to it (SessionEstimate.fitted) rather than the item sizing the block.
        let blocks = SessionBuilder.buildSession(
            length: .quick,
            candidates: [candidate(minutes: 1), candidate(minutes: 30), candidate(minutes: 12)],
            now: now)
        let minutes = blocks.compactMap { if case let .focus(_, min, _) = $0 { return min } else { return nil } }
        XCTAssertEqual(minutes, [5, 5, 5])
    }

    // MARK: - Block sharing with a thin library

    func testAThinLibraryYieldsFewerLongerItemsNotStubs() {
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(2), now: now)
        // Two items share the 15-minute block rather than taking 5 each and leaving it short.
        XCTAssertEqual(focusMinutes(blocks), 14)   // 15 / 2 = 7 apiece, integer division
        XCTAssertEqual(focusRefs(blocks).count, 2)
    }

    func testALoneItemGetsAWholeBlock() {
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(1), now: now)
        XCTAssertEqual(focusMinutes(blocks), SessionLength.blockMinutes)
    }

    /// A partial last block goes to the peak item (U-shape puts it last), so the most-due thing gets a
    /// block to itself — R5's recency, reinforced rather than diluted.
    func testTheTrailingPartialBlockBelongsToTheMostDueItem() {
        let peak = candidate(mastery: nil)                       // score 1.0
        let others = (0..<3).map { _ in candidate(mastery: 4) }   // 0.2 each
        let blocks = SessionBuilder.buildSession(length: .focused,
                                                 candidates: others + [peak], now: now)
        XCTAssertEqual(focusRefs(blocks).last, peak.unit)
        XCTAssertEqual(blocks.last, .focus(peak.unit, minutes: SessionLength.blockMinutes,
                                           microRestEvery: SessionBuilder.microRestEveryMinutes))
    }

    // MARK: - Placement (ADR 0014 R5 — U-shape, top-priority last)

    func testSingleItemSessionPlacesItLast() {
        let only = candidate()
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: [only], now: now)
        XCTAssertEqual(focusRefs(blocks), [only.unit])
    }

    func testTopPriorityItemIsAlwaysLast() {
        let peak = candidate(mastery: nil)   // score 1.0 — most due
        let mid = candidate(mastery: 2)      // 0.6
        let low = candidate(mastery: 4)      // 0.2
        let blocks = SessionBuilder.buildSession(length: .quick,
                                                 candidates: [mid, low, peak], now: now)
        let refs = focusRefs(blocks)
        XCTAssertEqual(refs.last, peak.unit, "the most-due item must finish the session")
        XCTAssertEqual(refs.firstIndex(of: peak.unit), refs.count - 1)
    }

    // MARK: - Rests sit between blocks, never inside one (ADR 0129 amending R3)

    func testItemsInsideABlockAreAdjacent() {
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(3), now: now)
        XCTAssertTrue(blocks.allSatisfy { $0.kind == .focused },
                      "three items in one block are the rotation — nothing separates them")
    }

    func testRestSitsBetweenBlocksOnly() {
        let blocks = SessionBuilder.buildSession(length: .full, candidates: pool(12), now: now)
        // Rests land at the block seams: after items 3, 6 and 9.
        let kinds = blocks.map(\.kind)
        XCTAssertEqual(kinds.enumerated().filter { $0.element == .rest }.map(\.offset), [3, 7, 11])
    }

    func testNoFocusedBlockExceedsTheCap() {
        let blocks = SessionBuilder.buildSession(length: .full, candidates: pool(12), now: now)
        for block in blocks where block.kind == .focused {
            XCTAssertLessThanOrEqual(block.minutes, RoutineBudget.maxFocusedMinutes)
        }
    }

    func testFocusedBlocksCarryTheMicroRestCadence() {
        // ADR 0014 R4 was plumbed and passed `nil` at every site since; it now states its cadence.
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(3), now: now)
        for block in blocks {
            if case let .focus(_, _, cue) = block {
                XCTAssertEqual(cue, SessionBuilder.microRestEveryMinutes)
            }
        }
    }

    // MARK: - Book-ends (ADR 0014 R1, scaled by preset — ADR 0129 sub-decision 2)

    func testQuickSchedulesAWarmUpButNoPlayThrough() {
        let blocks = SessionBuilder.buildSession(length: .quick, candidates: pool(3),
                                                 warmUp: candidate(minutes: 5),
                                                 play: candidate(minutes: 20), now: now)
        XCTAssertEqual(blocks.first?.kind, .warmup)
        XCTAssertFalse(blocks.contains { $0.kind == .play },
                       "a 10-minute play block would dominate the preset chosen because time is short")
    }

    func testLongerPresetsKeepTheirPlayThrough() {
        for length in [SessionLength.focused, .full] {
            let blocks = SessionBuilder.buildSession(length: length, candidates: pool(6),
                                                     warmUp: candidate(minutes: 5),
                                                     play: candidate(minutes: 20), now: now)
            XCTAssertEqual(blocks.first?.kind, .warmup)
            XCTAssertEqual(blocks.last?.kind, .play)
        }
    }

    func testBookEndsAreExcludedFromTheFocusedTotal() {
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: pool(6),
                                                 warmUp: candidate(minutes: 5),
                                                 play: candidate(minutes: 20), now: now)
        XCTAssertEqual(focusMinutes(blocks), 30, "R1 — only deliberate work is budgeted")
    }

    // MARK: - Selection (ADR 0014 R6 — prefer higher dueScore)

    func testSelectionPrefersHigherDueScore() {
        let due = candidate(mastery: nil)                            // score 1.0
        let settled = candidate(mastery: 5, lastPracticed: now)      // score 0
        let picked = SessionBuilder.select([settled, due], items: 1, now: now)
        XCTAssertEqual(picked.map(\.candidate.unit), [due.unit])
    }

    func testGoallessCandidatesAreExcluded() {
        let ignored = candidate(priority: 0)
        XCTAssertTrue(SessionBuilder.select([ignored], items: 3, now: now).isEmpty)
    }

    func testZeroItemsSelectsNothing() {
        XCTAssertTrue(SessionBuilder.select(pool(5), items: 0, now: now).isEmpty)
    }

    func testEmptyCandidatesYieldEmptySession() {
        XCTAssertTrue(SessionBuilder.buildSession(length: .focused, candidates: [], now: now).isEmpty)
    }

    // MARK: - Warm-up LRU (Decision 3)

    func testWarmUpPickIsLeastRecentlyPractised() {
        let recent = candidate(lastPracticed: now)
        let older = candidate(lastPracticed: now.addingTimeInterval(-10 * 86_400))
        let never = candidate(lastPracticed: nil)
        let pick = SessionBuilder.warmUpPick([recent, older, never])
        XCTAssertEqual(pick?.unit, never.unit, "never-practised is most stale — picked first")

        let pickDated = SessionBuilder.warmUpPick([recent, older])
        XCTAssertEqual(pickDated?.unit, older.unit)
    }

    func testWarmUpPickOfEmptyPoolIsNil() {
        XCTAssertNil(SessionBuilder.warmUpPick([]))
    }

    func testNoWarmUpBlockWhenPoolEmpty() {
        let blocks = SessionBuilder.buildSession(length: .focused, candidates: pool(3),
                                                 warmUp: nil, now: now)
        XCTAssertFalse(blocks.contains { $0.kind == .warmup })
    }
}
