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

    /// **The safety assertion.** A production build must never be entitled by the beta path — an App
    /// Store download reports `.production`, so `betaGrant` is `false` there and only a real
    /// entitlement can unlock Pro. If this ever fails, the app is giving itself away.
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
    // The half that was never covered. `resolveIsPro` was tested from day one, but *what feeds its
    // `betaGrant` argument* was an `AppTransaction` read behind `#if !DEBUG` — unreachable from the
    // simulator, from a local device build and from every UI test, so the one rule that decides a
    // tester's entitlement shipped with nothing checking it. Now it's a pure function of the receipt
    // path and these run on every push.

    /// A TestFlight or sandbox install carries `sandboxReceipt` — the case the grant exists for.
    func testSandboxReceiptGrantsTheBeta() {
        let url = URL(fileURLWithPath: "/var/mobile/.../StoreKit/sandboxReceipt")
        XCTAssertTrue(StoreManager.resolveSandbox(receiptURL: url))
    }

    /// **The safety assertion, at the input this time.** An App Store download's receipt is named
    /// `receipt`, so the grant cannot fire on it. If this fails, the app gives itself away.
    func testProductionReceiptDoesNotGrantTheBeta() {
        let url = URL(fileURLWithPath: "/var/mobile/.../StoreKit/receipt")
        XCTAssertFalse(StoreManager.resolveSandbox(receiptURL: url))
    }

    /// No receipt at all (a simulator, or a build that has never been through the App Store) is not
    /// a sandbox install. Fails closed.
    func testMissingReceiptDoesNotGrantTheBeta() {
        XCTAssertFalse(StoreManager.resolveSandbox(receiptURL: nil))
    }

    /// The match is on the **filename**, not on the path containing "sandbox" — a directory that
    /// happens to be named that way must not grant.
    func testGrantMatchesTheFilenameNotThePath() {
        let url = URL(fileURLWithPath: "/var/mobile/sandboxReceipt/StoreKit/receipt")
        XCTAssertFalse(StoreManager.resolveSandbox(receiptURL: url))
    }

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
