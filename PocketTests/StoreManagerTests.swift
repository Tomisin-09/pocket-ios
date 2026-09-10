import XCTest
@testable import Pocket

/// The pure entitlement decision inside `StoreManager` (ADR 0112). The StoreKit-touching parts are
/// exercised on device / in sandbox (Slice 6); here we pin the one branch that decides `isPro` from a
/// real entitlement and the DEBUG override, with no StoreKit involved.
///
/// **Nine tests were deleted from this file on 2026-09-10** along with the closed-beta grant: a
/// `betaGrant` input to `resolveIsPro`, and a `resolveSandbox(receiptURL:)` that decided it from the
/// receipt filename. They are not replaced, because the four tests below already assert the rule
/// that survives — Pro follows a real entitlement, or a Debug override, and nothing else. Writing a
/// fifth test to say "and not the beta grant either" would assert the absence of a symbol that no
/// longer compiles; `testNotEntitledWithNoOverrideIsNotPro` is that assertion and always was. What
/// the deleted tests were actually protecting is in `docs/plans/beta-testing-plan.md`: a
/// Release-only code path needs a Debug-testable decision and a way to see it from the outside.
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

    func testProductIdentifiersAreAnnualFirst() {
        XCTAssertEqual(StoreManager.ProductID.all,
                       [StoreManager.ProductID.annual, StoreManager.ProductID.monthly])
    }
}
