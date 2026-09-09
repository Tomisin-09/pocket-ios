import XCTest
@testable import Pocket

/// Remembering the speed you dropped from (ADR 0201). The rule is small and the failure modes are
/// all "the pill says something untrue" — an offer to return to a value the player never sat at.
final class TempoReturnTests: XCTestCase {

    func testADropIsRemembered() {
        XCTAssertEqual(TempoReturn.remembered(nil, movingFrom: 0.90, to: 0.72), 0.90)
    }

    func testTheFirstDropWinsAcrossOneDrag() {
        // Dragging 1.0 → 0.9 → 0.72 is one gesture and one intent. The speed worth returning to is
        // where the drag started, not the last value it happened to pass through.
        var remembered = TempoReturn.remembered(nil, movingFrom: 1.0, to: 0.9)
        remembered = TempoReturn.remembered(remembered, movingFrom: 0.9, to: 0.8)
        remembered = TempoReturn.remembered(remembered, movingFrom: 0.8, to: 0.72)
        XCTAssertEqual(remembered, 1.0)
    }

    func testANudgeIsNotADrop() {
        // A hair's-width slider wobble must not put a pill beside the readout.
        XCTAssertNil(TempoReturn.remembered(nil, movingFrom: 0.90, to: 0.88))
    }

    func testGettingBackByHandClearsTheOffer() {
        // The player dragged it back themselves. The pill has nothing left to say.
        XCTAssertNil(TempoReturn.remembered(0.90, movingFrom: 0.72, to: 0.90))
    }

    func testGoingPastWhereYouStartedClearsIt() {
        XCTAssertNil(TempoReturn.remembered(0.90, movingFrom: 0.72, to: 1.0))
    }

    func testClimbingBackPartWayKeepsTheOffer() {
        // 0.72 → 0.85 is still below 0.90, so there is still somewhere to go back to.
        XCTAssertEqual(TempoReturn.remembered(0.90, movingFrom: 0.72, to: 0.85), 0.90)
    }

    func testSpeedingUpFromNothingRemembersNothing() {
        // Only drops are remembered; going faster is not something anyone needs undoing.
        XCTAssertNil(TempoReturn.remembered(nil, movingFrom: 0.80, to: 1.0))
    }

    func testDroppingFurtherKeepsTheOriginalHeight() {
        // A second, separate drop later in the session still returns to the top of the first.
        XCTAssertEqual(TempoReturn.remembered(0.90, movingFrom: 0.72, to: 0.60), 0.90)
    }
}
