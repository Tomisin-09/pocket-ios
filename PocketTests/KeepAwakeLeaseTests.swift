import XCTest
@testable import Pocket

/// **The screen slept through a routine with "Keep screen awake" on** (device pass 2026-08-06).
///
/// `UIApplication.isIdleTimerDisabled` is one process-wide slot with no notion of who asked for it,
/// and it was being driven straight from a per-screen `onAppear`/`onDisappear` pair. Inside a routine
/// every block change puts two practice surfaces on screen at once, so the outgoing screen's teardown
/// re-enabled the idle timer the incoming screen had just disabled — and nothing said so, because the
/// setting still read "on".
///
/// The lease is the fix, and these are the properties that make it one: the flag follows the *count*,
/// the count survives interleaved teardown, and an unbalanced release can't poison it.
///
/// Assertions are **deltas** against `holderCount`, never absolutes — the count is process-global for
/// the whole test run, so an absolute would make this suite order-dependent (the same rule
/// `RecordingControllerTests` follows for the audio-session lease).
@MainActor
final class KeepAwakeLeaseTests: XCTestCase {

    /// The pure decision, which is where the two independent conditions live.
    func testTheIdleTimerIsDisabledOnlyWhenSomeoneAsksAndTheSettingIsOn() {
        XCTAssertTrue(KeepAwakeLease.shouldDisableIdleTimer(holders: 1, settingOn: true))
        XCTAssertFalse(KeepAwakeLease.shouldDisableIdleTimer(holders: 1, settingOn: false),
                       "a practice surface must not override the player's setting")
        XCTAssertFalse(KeepAwakeLease.shouldDisableIdleTimer(holders: 0, settingOn: true),
                       "the setting alone must not keep the phone awake away from practice")
        XCTAssertFalse(KeepAwakeLease.shouldDisableIdleTimer(holders: 0, settingOn: false))
    }

    func testManyHoldersStillCountAsAsking() {
        XCTAssertTrue(KeepAwakeLease.shouldDisableIdleTimer(holders: 3, settingOn: true))
    }

    /// **The bug, as a test.** A routine advancing from one block to the next: the incoming screen
    /// claims before the outgoing one lets go (SwiftUI does not promise the order, and this is the
    /// order that used to break it). The screen must stay held throughout.
    func testABlockChangeNeverDropsToZeroHolders() {
        let start = KeepAwakeLease.holderCount
        var outgoing = KeepAwakeClaim()
        var incoming = KeepAwakeClaim()
        outgoing.take()                                    // block A on screen
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 1)

        incoming.take()                                    // block B appears…
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 2)
        outgoing.give()                                    // …then block A disappears
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 1,
                       "the outgoing block's teardown must not release the incoming block's claim")

        incoming.give()
        XCTAssertEqual(KeepAwakeLease.holderCount, start, "and the session ends held by nobody")
    }

    /// The reverse order — outgoing first — has to balance just the same.
    func testTeardownBeforeSetupAlsoBalances() {
        let start = KeepAwakeLease.holderCount
        var first = KeepAwakeClaim()
        var second = KeepAwakeClaim()
        first.take()
        first.give()
        second.take()
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 1)
        second.give()
        XCTAssertEqual(KeepAwakeLease.holderCount, start)
    }

    /// SwiftUI re-fires `onAppear`, and a screen can be torn down twice. Neither may move the count,
    /// or a nested host + block pair would drift a holder every time you enter a routine.
    func testAClaimIsIdempotentInBothDirections() {
        let start = KeepAwakeLease.holderCount
        var claim = KeepAwakeClaim()
        claim.take()
        claim.take()
        claim.take()
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 1, "taking twice is still one holder")

        claim.give()
        claim.give()
        XCTAssertEqual(KeepAwakeLease.holderCount, start, "and giving twice still releases one")
    }

    /// A host and the block inside it both claiming — the nesting the routine player now relies on.
    func testANestedHostAndBlockHoldIndependently() {
        let start = KeepAwakeLease.holderCount
        var host = KeepAwakeClaim()
        var block = KeepAwakeClaim()
        host.take()
        block.take()
        block.give()
        XCTAssertEqual(KeepAwakeLease.holderCount, start + 1,
                       "the block leaving leaves the session's own claim standing")
        host.give()
        XCTAssertEqual(KeepAwakeLease.holderCount, start)
    }

    /// An unbalanced release must not drive the count negative — a negative count would silently
    /// defeat every later claim, which is a worse version of the bug being fixed.
    func testReleasingMoreThanWasTakenCannotPoisonTheCount() {
        let start = KeepAwakeLease.holderCount
        KeepAwakeLease.release()
        KeepAwakeLease.release()
        XCTAssertEqual(KeepAwakeLease.holderCount, max(0, start - 2))

        var claim = KeepAwakeClaim()
        claim.take()
        XCTAssertGreaterThan(KeepAwakeLease.holderCount, 0, "a claim after that still registers")
        claim.give()
    }
}
