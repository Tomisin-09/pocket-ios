import XCTest
@testable import Pocket

/// **Landscape is a lease, not a flag** (ADR 0226 D4).
///
/// The orientation mask is one process-wide slot. It used to be written straight from the practice
/// screen's `onAppear`/`onDisappear`, which is right for exactly one screen at a time: the moment two
/// landscape screens overlap, the outgoing one's teardown narrows the mask the incoming one just
/// widened. `KeepAwakeLease` shipped that bug (device pass 2026-08-06); these pin the same properties
/// here — the mask follows the *count*, the count survives interleaved teardown, and an unbalanced
/// release can't poison it.
///
/// Assertions are **deltas** against `holderCount`, never absolutes — the count is process-global for
/// the whole test run.
@MainActor
final class OrientationLeaseTests: XCTestCase {

    func testLandscapeIsAllowedWhileAnyoneAsksAndOnlyThen() {
        XCTAssertEqual(OrientationLease.mask(holders: 0), .portrait)
        XCTAssertEqual(OrientationLease.mask(holders: 1), [.portrait, .landscape])
        XCTAssertEqual(OrientationLease.mask(holders: 3), [.portrait, .landscape])
    }

    /// **The bug, as a test.** One landscape screen replacing another: the incoming screen claims
    /// before the outgoing one lets go. Landscape must stay allowed throughout.
    func testAnOverlapNeverNarrowsTheMask() {
        let start = OrientationLease.holderCount
        var outgoing = OrientationClaim()
        var incoming = OrientationClaim()
        outgoing.take()
        incoming.take()
        outgoing.give()
        XCTAssertEqual(OrientationLease.holderCount, start + 1,
                       "the outgoing screen's teardown must not release the incoming screen's claim")
        XCTAssertEqual(AppDelegate.orientationMask, [.portrait, .landscape])

        incoming.give()
        XCTAssertEqual(OrientationLease.holderCount, start)
        if start == 0 {
            XCTAssertEqual(AppDelegate.orientationMask, .portrait, "the last one out narrows it back")
        }
    }

    /// SwiftUI re-fires `onAppear`, and a screen can be torn down twice. Neither may move the count.
    func testAClaimIsIdempotentInBothDirections() {
        let start = OrientationLease.holderCount
        var claim = OrientationClaim()
        claim.take()
        claim.take()
        XCTAssertEqual(OrientationLease.holderCount, start + 1, "taking twice is still one holder")
        claim.give()
        claim.give()
        XCTAssertEqual(OrientationLease.holderCount, start, "and giving twice still releases one")
    }

    /// An unbalanced release is floored at zero, or it would defeat every later claim.
    func testAnUnbalancedReleaseCannotGoNegative() {
        let start = OrientationLease.holderCount
        for _ in 0...start { OrientationLease.release() }
        XCTAssertEqual(OrientationLease.holderCount, 0)

        var claim = OrientationClaim()
        claim.take()
        XCTAssertEqual(OrientationLease.holderCount, 1, "a claim after the extra release still counts")
        XCTAssertEqual(AppDelegate.orientationMask, [.portrait, .landscape])
        claim.give()
        for _ in 0..<start { OrientationLease.retain() }
    }
}
