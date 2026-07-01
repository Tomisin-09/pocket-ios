import XCTest
@testable import Pocket

/// The default-resolution rule for persisted settings (ADR 0050). `UserDefaults.bool` reads a
/// missing key as `false`, which would silently disable an opt-out setting; `resolvedBool` keeps
/// "never set ⇒ default" honest. Pinned because a regression here flips a feature off without a
/// user ever touching it (AGENTS.md).
final class AppSettingsTests: XCTestCase {

    func testUnsetKeyTakesTheDefault() {
        // The whole point: an untouched setting reads as its default, not `false`.
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: nil, default: true))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: nil, default: false))
    }

    func testSetKeyReadsItsStoredValue() {
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: true, default: false))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: false, default: true))
    }

    func testNonBoolStoredValueFallsBackToDefault() {
        // A key that somehow holds a non-Bool can't crash or read arbitrarily — take the default.
        XCTAssertTrue(AppSettings.resolvedBool(storedValue: "yes", default: true))
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: 42, default: false))
    }

    // MARK: integer settings (count-in length)

    func testUnsetIntKeyTakesTheDefault() {
        // Same rule for ints: a missing key is the default, not `UserDefaults.integer`'s 0.
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: nil, default: 1), 1)
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: 2, default: 1), 2)
    }

    func testNonIntStoredValueFallsBackToDefault() {
        XCTAssertEqual(AppSettings.resolvedInt(storedValue: "two", default: 1), 1)
    }
}
