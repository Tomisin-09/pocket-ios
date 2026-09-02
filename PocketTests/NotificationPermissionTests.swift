import XCTest
@testable import Pocket

/// The three-way permission decision (ADR 0186 D5).
///
/// Small, and worth having anyway: the rule it encodes is invisible when it breaks. A `.denied` that
/// routes to `.ask` calls `requestAuthorization`, which returns `false` **without showing anything**
/// — so the bug looks exactly like the player declining a prompt they never saw, on a device, once,
/// and never in a simulator run where the prompt has not been spent yet.
final class NotificationPermissionTests: XCTestCase {

    func testAnUnaskedPlayerIsAsked() {
        XCTAssertEqual(NotificationPermission.notDetermined.next, .ask)
    }

    /// **The one this type exists for.** A denial must never route to `.ask`.
    func testADenialIsNeverAskedAgain() {
        XCTAssertEqual(NotificationPermission.denied.next, .sendToSettings)
    }

    func testAGrantedPlayerIsNotAskedAgainEither() {
        XCTAssertEqual(NotificationPermission.granted.next, .proceed)
    }

    /// Only `.granted` can deliver — and, separately, none of these says anything about whether the
    /// player *wants* the reminder. That is the conflation ADR 0186 D5 unpicks.
    func testOnlyGrantedCanDeliver() {
        XCTAssertTrue(NotificationPermission.granted.canDeliver)
        XCTAssertFalse(NotificationPermission.denied.canDeliver)
        XCTAssertFalse(NotificationPermission.notDetermined.canDeliver)
    }
}
