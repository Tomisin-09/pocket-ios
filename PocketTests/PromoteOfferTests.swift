import XCTest
@testable import Pocket

/// Pure post-run promote math (ADR 0079): the "offer promote?" predicate and the promoted-command
/// target. Exercised as plain values — no engine/UI — because this is exactly the tempo boundary
/// logic that breaks silently (AGENTS.md).
final class PromoteOfferTests: XCTestCase {

    // MARK: - Offer predicate (ceiling-clamped reach > command)

    func testOffersWhenReachSitsAboveCommand() {
        XCTAssertTrue(PromoteOffer.canPromote(reach: 106, command: 100, ceiling: 300))
    }

    func testDoesNotOfferWhenReachEqualsCommand() {
        // Nothing to promote — command has caught up to the reach (ADR 0079 §5).
        XCTAssertFalse(PromoteOffer.canPromote(reach: 100, command: 100, ceiling: 300))
    }

    func testDoesNotOfferWhenReachBelowCommand() {
        XCTAssertFalse(PromoteOffer.canPromote(reach: 98, command: 100, ceiling: 300))
    }

    func testDoesNotOfferWhenReachExceedsCeilingButCommandIsAtCeiling() {
        // Command already at the ceiling; the auto-reach overshoots it (300 × 1.06 = 318) but the
        // ceiling-clamped promote (300) equals command — a no-op, so no offer.
        XCTAssertFalse(PromoteOffer.canPromote(reach: 318, command: 300, ceiling: 300))
    }

    // MARK: - Promoted-command target (min(ceiling, reach))

    func testPromotesUpToTheReachBelowCeiling() {
        XCTAssertEqual(PromoteOffer.promotedCommand(reach: 106, ceiling: 300), 106)
    }

    func testClampsToCeilingWhenReachWouldExceedIt() {
        // A reach past the device ceiling promotes only to the ceiling.
        XCTAssertEqual(PromoteOffer.promotedCommand(reach: 315, ceiling: 300), 300)
    }

    func testPromotesToReachExactlyAtCeiling() {
        XCTAssertEqual(PromoteOffer.promotedCommand(reach: 300, ceiling: 300), 300)
    }
}
