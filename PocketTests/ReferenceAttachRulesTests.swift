import XCTest
@testable import Pocket

/// **What a reference can be attached to** (ADR 0264 D6), by where the player stands with the plan.
/// References are free; the line inside them follows what the player can open.
final class ReferenceAttachRulesTests: XCTestCase {

    func testStandingComesFromAccessAndAPastPurchase() {
        XCTAssertEqual(PlanStanding(access: .none, hasBoughtBefore: false), .neverBought)
        XCTAssertEqual(PlanStanding(access: .none, hasBoughtBefore: true), .lapsed)
        XCTAssertEqual(PlanStanding(access: .monthly, hasBoughtBefore: true), .onPlan)
        XCTAssertEqual(PlanStanding(access: .payOnce, hasBoughtBefore: false), .onPlan,
                       "on is on, whatever StoreKit's history has caught up with")
    }

    /// *Lapsed* is exactly the wall's returning player, so the two can't disagree about who that is.
    func testLapsedIsTheWallsReturningPlayer() {
        for access in [PlanAccess.none, .monthly, .payOnce] {
            for bought in [false, true] {
                XCTAssertEqual(PlanStanding(access: access, hasBoughtBefore: bought) == .lapsed,
                               PlanAccess.greetsReturningPlayer(access: access, hasBoughtBefore: bought))
            }
        }
    }

    /// Keep for later, a song and a loop are always open: they are free to open.
    func testKeepForLaterSongsAndLoopsAreAlwaysOpen() {
        for standing in [PlanStanding.neverBought, .lapsed, .onPlan] {
            for kind in [nil, ReferencePlaceKind.song, .loop] {
                XCTAssertEqual(ReferenceAttachRules.offer(kind, for: standing), .open, "\(String(describing: kind))")
            }
        }
    }

    /// Never bought: not offered. Lapsed: offered with a lock. On the plan: open.
    func testExercisesAndRoutinesFollowThePlan() {
        for kind in [ReferencePlaceKind.exercise, .routine] {
            XCTAssertEqual(ReferenceAttachRules.offer(kind, for: .neverBought), .hidden)
            XCTAssertEqual(ReferenceAttachRules.offer(kind, for: .lapsed), .locked)
            XCTAssertEqual(ReferenceAttachRules.offer(kind, for: .onPlan), .open)
        }
    }

    func testTheFooterSaysWhyAndNothingOnThePlan() {
        XCTAssertEqual(ReferenceAttachRules.footer(for: .neverBought), "Exercises and routines come with the plan.")
        XCTAssertEqual(ReferenceAttachRules.footer(for: .lapsed),
                       "Your drills and routines are just as you left them. They open again with the plan.")
        XCTAssertNil(ReferenceAttachRules.footer(for: .onPlan))
        XCTAssertEqual(ReferenceAttachRules.lockedCaption, "Opens with the plan")
    }
}
