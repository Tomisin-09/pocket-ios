import XCTest
@testable import Pocket

/// Remembering the speed you dropped from (ADR 0201, rule revised by ADR 0202). The failure modes
/// are all "the pill says something untrue" — an offer to return to a value the player never sat
/// at, or no offer at all after a drop that plainly happened.
final class TempoReturnTests: XCTestCase {

    func testADropIsRemembered() {
        XCTAssertEqual(TempoReturn.remembered(nil, gestureStart: 0.90, now: 0.72), 0.90)
    }

    /// The regression ADR 0202 exists for. The slider is continuous: one drag writes `speed`
    /// dozens of times, each step far smaller than `minimumDrop`. Anchored to the gesture's start,
    /// every frame of the drag agrees on the same answer; anchored to the previous *write*, no
    /// frame ever counted as a drop and the pill never appeared at all.
    func testEveryFrameOfOneDragAgrees() {
        var remembered: Double?
        var previous = 1.0
        for step in stride(from: 0.99, through: 0.72, by: -0.01) {
            remembered = TempoReturn.remembered(remembered, gestureStart: 1.0, now: step)
            // A per-write rule would have seen only this, and found nothing:
            XCTAssertGreaterThan(step, previous - TempoReturn.minimumDrop)
            previous = step
        }
        XCTAssertEqual(remembered, 1.0)
    }

    /// One rung, not the top of the ladder — the same shape as `SpanHistory.widenTarget`.
    func testASecondDropOffersTheRungAboveIt() {
        var remembered = TempoReturn.remembered(nil, gestureStart: 1.0, now: 0.75)
        XCTAssertEqual(remembered, 1.0)
        remembered = TempoReturn.remembered(remembered, gestureStart: 0.75, now: 0.60)
        XCTAssertEqual(remembered, 0.75, "a second drop returns to where it started, not to 1.0")
    }

    func testANudgeIsNotADrop() {
        // A hair's-width slider wobble must not put a pill beside the readout.
        XCTAssertNil(TempoReturn.remembered(nil, gestureStart: 0.90, now: 0.88))
    }

    func testANudgeLeavesAStandingOfferAlone() {
        XCTAssertEqual(TempoReturn.remembered(0.90, gestureStart: 0.72, now: 0.70), 0.90)
    }

    func testGettingBackByHandClearsTheOffer() {
        // The player dragged it back themselves. The pill has nothing left to say.
        XCTAssertNil(TempoReturn.remembered(0.90, gestureStart: 0.72, now: 0.90))
    }

    func testGoingPastWhereYouStartedClearsIt() {
        XCTAssertNil(TempoReturn.remembered(0.90, gestureStart: 0.72, now: 1.0))
    }

    func testClimbingBackPartWayKeepsTheOffer() {
        // 0.72 → 0.85 is still below 0.90, so there is still somewhere to go back to.
        XCTAssertEqual(TempoReturn.remembered(0.90, gestureStart: 0.72, now: 0.85), 0.90)
    }

    func testSpeedingUpFromNothingRemembersNothing() {
        // Only drops are remembered; going faster is not something anyone needs undoing.
        XCTAssertNil(TempoReturn.remembered(nil, gestureStart: 0.80, now: 1.0))
    }
}
