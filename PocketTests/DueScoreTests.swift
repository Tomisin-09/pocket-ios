import XCTest
@testable import Pocket

/// The planner's selection ranking (V2 planner, ADR 0015 S5) — pure, SwiftData-free, so the
/// dueScore formula and its dueness / mastery terms are exercised directly. The property list is
/// from the build plan (`docs/plans/planner-build-plan.md` §6).
final class DueScoreTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func candidate(mastery: Int? = nil,
                           lastPracticed: Date? = nil,
                           priority: Double = 1.0) -> PlannerCandidate {
        PlannerCandidate(unit: PlannerUnitRef(UUID(), .exercise),
                         priority: priority, mastery: mastery,
                         lastPracticed: lastPracticed, estimatedMinutes: 12)
    }

    // MARK: - Dueness (rises with time since practised)

    func testNeverPractisedIsMaxDue() {
        XCTAssertEqual(DueScore.dueness(lastPracticed: nil, now: now), 1.0)
    }

    func testDuenessRisesMonotonicallyWithTimeSincePractised() {
        let days: [Double] = [0, 1, 3, 7, 30, 90]
        let values = days.map { day in
            DueScore.dueness(lastPracticed: now.addingTimeInterval(-day * 86_400), now: now)
        }
        for (earlier, later) in zip(values, values.dropFirst()) {
            XCTAssertLessThan(earlier, later, "dueness must strictly rise with elapsed time")
        }
    }

    func testNeverPractisedIsAtLeastAsDueAsAnyPractised() {
        // Never-practised is max-due (1.0). A practised item's dueness only asymptotes toward 1.0,
        // so it is never *more* due; at realistic gaps it is strictly less. (Exact ties at extreme
        // gaps are broken by the older-first tiebreak in `SessionBuilder.select`.)
        let neverDue = DueScore.dueness(lastPracticed: nil, now: now)
        let month = DueScore.dueness(lastPracticed: now.addingTimeInterval(-30 * 86_400), now: now)
        XCTAssertEqual(neverDue, 1.0)
        XCTAssertGreaterThan(neverDue, month)
    }

    // MARK: - Mastery term (falls as the player rates it settled)

    func testUnratedRanksAsMaxDue() {
        // Unrated (nil) is treated identically to mastery 0 — assumed to still need work.
        XCTAssertEqual(DueScore.masteryTerm(nil), 1.0)
        XCTAssertEqual(DueScore.masteryTerm(0), 1.0)
    }

    func testMasteryFiveRanksLowestForEqualRecency() {
        // Equal recency a week back, so dueness is a positive constant and only the mastery term
        // separates them. mastery 5 zeroes the product; mastery 4 stays positive.
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let settled = candidate(mastery: 5, lastPracticed: weekAgo)
        let rough = candidate(mastery: 4, lastPracticed: weekAgo)
        XCTAssertEqual(DueScore.score(settled, now: now), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(DueScore.score(rough, now: now), DueScore.score(settled, now: now))
    }

    func testMasteryTermIsClampedAndDescending() {
        XCTAssertEqual(DueScore.masteryTerm(3), 1.0 - 3.0 / 5.0, accuracy: 1e-9)
        // Out-of-range values clamp rather than produce a negative / >1 term.
        XCTAssertEqual(DueScore.masteryTerm(9), 0, accuracy: 1e-9)
        XCTAssertEqual(DueScore.masteryTerm(-2), 1.0, accuracy: 1e-9)
    }

    // MARK: - Full score

    func testHigherGoalWeightYieldsHigherScore() {
        let now = self.now
        let light = candidate(mastery: nil, lastPracticed: nil, priority: 1.0)
        let heavy = candidate(mastery: nil, lastPracticed: nil, priority: 3.0)
        XCTAssertGreaterThan(DueScore.score(heavy, now: now), DueScore.score(light, now: now))
    }

    func testFullyRatedRecentItemScoresZero() {
        // mastery 5 zeroes the whole product regardless of recency — retired from rotation.
        let settled = candidate(mastery: 5, lastPracticed: now.addingTimeInterval(-30 * 86_400))
        XCTAssertEqual(DueScore.score(settled, now: now), 0, accuracy: 1e-9)
    }
}
