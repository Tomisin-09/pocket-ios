import XCTest
@testable import Pocket

final class AutoNameTests: XCTestCase {

    func testFirstNameWhenNoneExist() {
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: []), "Loop 1")
    }

    func testIncrementsPastHighest() {
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: ["Loop 1", "Loop 2"]), "Loop 3")
    }

    func testTracksHighWaterMarkNotCount() {
        // "Loop 2" was deleted — the next must be 4 (past the highest still present),
        // not 3, so it can't collide with the surviving "Loop 3".
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: ["Loop 1", "Loop 3"]), "Loop 4")
    }

    func testIgnoresUserTypedNames() {
        // Custom names don't feed the counter; numbering continues from the matches.
        let existing = ["Chorus bend", "Loop 5", "verse"]
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: existing), "Loop 6")
    }

    func testIgnoresNonIntegerSuffixes() {
        // "Loop 2a" isn't a pure number → ignored; only "Loop 1" counts.
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: ["Loop 1", "Loop 2a"]), "Loop 2")
    }

    func testPrefixMustBeFollowedBySpace() {
        // "Looper 9" starts with "Loop" but isn't "Loop <n>" — must not count.
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: ["Looper 9"]), "Loop 1")
    }

    func testWorksForOtherPrefixes() {
        XCTAssertEqual(AutoName.next(prefix: "Marker", existing: ["Marker 7"]), "Marker 8")
    }
}
