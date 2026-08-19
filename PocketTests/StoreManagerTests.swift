import XCTest
@testable import Pocket

/// The pure entitlement decision inside `StoreManager` (ADR 0112). The StoreKit-touching parts are
/// exercised on device / in sandbox (Slice 6); here we pin the one branch that decides `isPro` from a
/// real entitlement and the DEBUG override, with no StoreKit involved.
final class StoreManagerTests: XCTestCase {

    func testEntitledWithNoOverrideIsPro() {
        XCTAssertTrue(StoreManager.resolveIsPro(entitled: true, debugOverride: nil))
    }

    func testNotEntitledWithNoOverrideIsNotPro() {
        XCTAssertFalse(StoreManager.resolveIsPro(entitled: false, debugOverride: nil))
    }

    func testDebugOverrideForcesProRegardlessOfEntitlement() {
        XCTAssertTrue(StoreManager.resolveIsPro(entitled: false, debugOverride: true))
        XCTAssertTrue(StoreManager.resolveIsPro(entitled: true, debugOverride: true))
    }

    func testDebugOverrideForcesFreeRegardlessOfEntitlement() {
        XCTAssertFalse(StoreManager.resolveIsPro(entitled: true, debugOverride: false))
        XCTAssertFalse(StoreManager.resolveIsPro(entitled: false, debugOverride: false))
    }

    // MARK: - Closed-beta grant
    //
    // TODO(beta): delete this section with the grant itself, before the next App Store submission.

    /// The grant's whole purpose: a TestFlight tester with no purchase is Pro.
    func testBetaGrantEntitlesWithoutAPurchase() {
        XCTAssertTrue(StoreManager.resolveIsPro(entitled: false, debugOverride: nil, betaGrant: true))
    }

    /// **What the app goes back to when the grant is removed.** With `betaGrant` false, only a real
    /// entitlement unlocks Pro. This no longer describes a *shipping* build — the grant is now
    /// unconditional outside Debug, so nothing at runtime passes `false` here — it pins the
    /// behaviour the `TODO(beta)` removal must restore.
    func testBetaGrantAbsentLeavesEntitlementInCharge() {
        XCTAssertFalse(StoreManager.resolveIsPro(entitled: false, debugOverride: nil, betaGrant: false))
        XCTAssertTrue(StoreManager.resolveIsPro(entitled: true, debugOverride: nil, betaGrant: false))
    }

    /// An explicit debug override still wins, so a Debug build can exercise the *locked* state even
    /// while running against the sandbox.
    func testDebugOverrideBeatsTheBetaGrant() {
        XCTAssertFalse(StoreManager.resolveIsPro(entitled: false, debugOverride: false, betaGrant: true))
    }

    // MARK: - Which build the grant fires on
    //
    // Nothing to assert here any more, and that absence is the point. The grant used to be a pure
    // function of the receipt path (`resolveSandbox(receiptURL:)`), and these tests pinned that a
    // production receipt could never trigger it. That condition was removed deliberately — it was
    // the last thing that could fail on a tester's first launch — so the grant is now a bare
    // `#if DEBUG`, with no runtime input a test could feed. **The safety it used to assert is now
    // procedural only:** the `TODO(beta)` markers and the checklist in
    // `docs/plans/beta-testing-plan.md`. `testBetaGrantAbsentLeavesEntitlementInCharge` above still
    // covers what the app does once the grant is taken back out.

    /// Defaulting `betaGrant` must not change the pre-existing rule — the call sites above omit it.
    func testOmittingBetaGrantMatchesTheOriginalRule() {
        XCTAssertEqual(StoreManager.resolveIsPro(entitled: true, debugOverride: nil),
                       StoreManager.resolveIsPro(entitled: true, debugOverride: nil, betaGrant: false))
        XCTAssertEqual(StoreManager.resolveIsPro(entitled: false, debugOverride: nil),
                       StoreManager.resolveIsPro(entitled: false, debugOverride: nil, betaGrant: false))
    }

    func testProductIdentifiersAreAnnualFirst() {
        XCTAssertEqual(StoreManager.ProductID.all,
                       [StoreManager.ProductID.annual, StoreManager.ProductID.monthly])
    }
}
