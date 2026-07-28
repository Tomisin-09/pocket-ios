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

    func testProductIdentifiersAreAnnualFirst() {
        XCTAssertEqual(StoreManager.ProductID.all,
                       [StoreManager.ProductID.annual, StoreManager.ProductID.monthly])
    }
}
