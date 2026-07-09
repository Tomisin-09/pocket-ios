import XCTest
@testable import Pocket

/// The planner's back-half (V2 planner, ADR 0014) — pure session layout, SwiftData-free. The
/// property list is from the build plan (`docs/plans/planner-build-plan.md` §6) and ADR 0014.
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

    // MARK: - Placement (ADR 0014 R5 — U-shape, top-priority last)

    func testSingleItemSessionPlacesItLast() {
        let only = candidate()
        let blocks = SessionBuilder.buildSession(minutes: 30, candidates: [only], now: now)
        XCTAssertEqual(focusRefs(blocks), [only.unit])
        XCTAssertEqual(blocks.last, .focus(only.unit, minutes: 12, microRestEvery: nil))
    }

    func testTopPriorityItemIsAlwaysLast() {
        // Equal recency (all unrated) so dueScore orders purely by mastery term.
        let peak = candidate(mastery: nil)   // score 1.0 — most due
        let mid = candidate(mastery: 2)      // 0.6
        let low = candidate(mastery: 4)      // 0.2
        let blocks = SessionBuilder.buildSession(minutes: 60,
                                                 candidates: [mid, low, peak], now: now)
        XCTAssertEqual(focusRefs(blocks).last, peak.unit, "the most-due item must finish the session")
        // …and it is never buried mid-session.
        let refs = focusRefs(blocks)
        XCTAssertEqual(refs.firstIndex(of: peak.unit), refs.count - 1)
    }

    // MARK: - Budget (ADR 0014 R1/R7)

    func testFocusedMinutesNeverExceedBudget() {
        let candidates = (0..<10).map { _ in candidate(minutes: 12) }
        let blocks = SessionBuilder.buildSession(minutes: 30, candidates: candidates, now: now)
        XCTAssertLessThanOrEqual(focusMinutes(blocks), 30)
        XCTAssertEqual(focusMinutes(blocks), 30, "greedy fill should reach the budget exactly")
    }

    func testFocusedMinutesNeverExceedSixtyMinuteCap() {
        let candidates = (0..<20).map { _ in candidate(minutes: 12) }
        let blocks = SessionBuilder.buildSession(minutes: 120, candidates: candidates, now: now)
        XCTAssertLessThanOrEqual(focusMinutes(blocks), SessionBuilder.maxSessionMinutes)
    }

    func testWarmUpAndPlayExcludedFromFocusedBudget() {
        let focus = candidate(minutes: 12)
        let warm = candidate(minutes: 5)
        let play = candidate(minutes: 20)
        let blocks = SessionBuilder.buildSession(minutes: 15, candidates: [focus],
                                                 warmUp: warm, play: play, now: now)
        XCTAssertLessThanOrEqual(focusMinutes(blocks), 15)
        XCTAssertEqual(blocks.first?.kind, .warmup)
        XCTAssertEqual(blocks.last?.kind, .play)
    }

    // MARK: - Block cap + rests (ADR 0014 R2/R3)

    func testNoFocusedBlockExceedsTheCap() {
        let big = candidate(minutes: 30)   // over the 20-min cap
        let blocks = SessionBuilder.buildSession(minutes: 60, candidates: [big], now: now)
        for block in blocks {
            if case let .focus(_, minutes, _) = block {
                XCTAssertLessThanOrEqual(minutes, RoutineBudget.maxFocusedMinutes)
            }
        }
        XCTAssertEqual(focusMinutes(blocks), 30, "splitting preserves the total minutes")
    }

    func testRestSitsBetweenEveryPairOfFocusedBlocks() {
        let candidates = (0..<3).map { _ in candidate(minutes: 12) }
        let blocks = SessionBuilder.buildSession(minutes: 60, candidates: candidates, now: now)
        for (index, block) in blocks.enumerated() where block.kind == .focused {
            let next = index + 1
            if next < blocks.count, blocks[next].kind == .focused {
                XCTFail("two focused blocks are adjacent with no rest between them")
            }
        }
        // Three 12-min focused blocks ⇒ two interleaved rests.
        XCTAssertEqual(blocks.filter { $0.kind == .rest }.count, 2)
    }

    // MARK: - Selection (ADR 0014 R1 — prefer higher dueScore)

    func testSelectionPrefersHigherDueScore() {
        let due = candidate(minutes: 12, mastery: nil)                   // score 1.0
        let settled = candidate(minutes: 12, mastery: 5, lastPracticed: now) // score 0
        // Budget fits only one 12-min block.
        let blocks = SessionBuilder.buildSession(minutes: 12,
                                                 candidates: [settled, due], now: now)
        XCTAssertEqual(focusRefs(blocks), [due.unit], "the more-due item is chosen first")
    }

    func testEmptyCandidatesYieldEmptySession() {
        XCTAssertTrue(SessionBuilder.buildSession(minutes: 30, candidates: [], now: now).isEmpty)
    }

    func testZeroBudgetYieldsNoFocusedBlocks() {
        let blocks = SessionBuilder.buildSession(minutes: 0, candidates: [candidate()], now: now)
        XCTAssertEqual(focusMinutes(blocks), 0)
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
        let blocks = SessionBuilder.buildSession(minutes: 30, candidates: [candidate()],
                                                 warmUp: nil, now: now)
        XCTAssertFalse(blocks.contains { $0.kind == .warmup })
    }
}
