import XCTest
@testable import Pocket

/// The long-term tier's rank → pull mapping and the visit order it drives (ADR 0171 D3). Pure —
/// `LongTermRank` and `SessionBuilder.visitOrder` are Foundation-only.
///
/// Both halves matter, and the second is the one that is easy to lose: weight alone would make rank
/// invisible in a Quick session, because `roundRobin` deals one item per goal per pass and only the
/// first three goals visited ever appear.
final class LongTermRankTests: XCTestCase {

    // MARK: - Rank → weight

    func testTopRankPullsHardestAndEachStepPullsLess() {
        XCTAssertEqual(LongTermRank.weight(forOrder: 0), LongTermRank.topWeight, accuracy: 0.0001)
        for order in 0..<LongTermRank.maxGoals {
            XCTAssertGreaterThan(LongTermRank.weight(forOrder: order),
                                 LongTermRank.weight(forOrder: order + 1),
                                 "rank \(order) must outpull rank \(order + 1)")
        }
    }

    /// Every rank **inside the cap** is strictly above the floor — which is what makes all ten ranks
    /// distinguishable. If the floor were reached early, the bottom of the list would flatten into
    /// one indistinguishable band and reordering it would do nothing.
    func testEveryRankWithinTheCapIsAboveTheFloor() {
        for order in 0..<LongTermRank.maxGoals {
            XCTAssertGreaterThan(LongTermRank.weight(forOrder: order), LongTermRank.floorWeight)
        }
        XCTAssertEqual(LongTermRank.weight(forOrder: LongTermRank.maxGoals),
                       LongTermRank.floorWeight, accuracy: 0.0001,
                       "the floor is reached exactly one past the cap")
    }

    func testTheFloorHoldsForDataAuthoredOverTheCap() {
        XCTAssertEqual(LongTermRank.weight(forOrder: 500), LongTermRank.floorWeight, accuracy: 0.0001)
        XCTAssertEqual(LongTermRank.weight(forOrder: -3), LongTermRank.topWeight, accuracy: 0.0001,
                       "a negative order is treated as the top, not as a huge weight")
    }

    /// The scale must stay commensurable with `GoalPriority`, because both tiers project into one
    /// pool and compete directly. A top-ranked standing goal outpulls a *Normal* today-goal — but an
    /// explicit *High* today-goal still wins, because the player asked for that today.
    func testTopRankSitsBetweenNormalAndHighTodayGoals() {
        XCTAssertGreaterThan(LongTermRank.weight(forOrder: 0), GoalPriority.normal.weight)
        XCTAssertLessThan(LongTermRank.weight(forOrder: 0), GoalPriority.high.weight)
    }

    // MARK: - Visit order

    func testAnEmptyRankingLeavesDiscoveryOrderUntouched() {
        let first = UUID(), second = UUID()
        let discovered: [UUID?] = [first, nil, second]
        XCTAssertEqual(SessionBuilder.visitOrder(discovered, ranking: []), discovered)
    }

    /// Today's goals lead; the ranked tier follows **in the player's order**, not in dueness order.
    func testRankedGoalsAreVisitedAfterTodaysGoalsAndInRankOrder() {
        let today = UUID(), rankOne = UUID(), rankTwo = UUID()
        // Discovery order is dueness-derived, and puts the *second*-ranked goal first.
        let discovered: [UUID?] = [rankTwo, today, rankOne]
        let visited = SessionBuilder.visitOrder(discovered, ranking: [rankOne, rankTwo])
        XCTAssertEqual(visited, [today, rankOne, rankTwo])
    }

    func testUnrankedGoalsKeepTheirRelativeDiscoveryOrder() {
        let dueFirst = UUID(), dueSecond = UUID(), standing = UUID()
        let visited = SessionBuilder.visitOrder([dueFirst, standing, dueSecond, nil],
                                                ranking: [standing])
        XCTAssertEqual(visited, [dueFirst, dueSecond, nil, standing])
    }

    /// A goal named in the ranking but with no candidates never appears in the discovery list, so it
    /// must simply be absent rather than inserted as an empty visit.
    func testARankedGoalWithNoCandidatesIsNotVisited() {
        let present = UUID(), derivesNothing = UUID()
        let visited = SessionBuilder.visitOrder([present], ranking: [derivesNothing, present])
        XCTAssertEqual(visited, [present])
    }

    /// The behavioural claim, end to end: with a Quick session's three items and four standing
    /// goals, the **top three by rank** are the ones dealt — even though dueness would have picked
    /// a different three. Neutralise `ranking:` and this test fails, which is the point.
    func testRankDecidesWhichGoalsReachAThreeItemSession() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let ranked = (0..<4).map { _ in UUID() }
        // Dueness runs *opposite* to rank: the last-ranked goal has the most-due material.
        let candidates: [PlannerCandidate] = ranked.enumerated().flatMap { index, goal in
            (0..<3).map { _ in
                PlannerCandidate(unit: PlannerUnitRef(UUID(), .exercise), priority: 1.0,
                                 mastery: index, lastPracticed: now, estimatedMinutes: 10,
                                 goalUID: goal)
            }
        }
        let dealt = Set(SessionBuilder.select(candidates, items: 3, ranking: ranked, now: now)
            .compactMap(\.candidate.goalUID))
        XCTAssertEqual(dealt, Set(ranked.prefix(3)))
        XCTAssertFalse(dealt.contains(ranked[3]), "the bottom-ranked goal must not take a slot")
    }
}
