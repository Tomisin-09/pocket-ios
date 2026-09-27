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
        XCTAssertEqual(AutoName.next(prefix: "Section", existing: ["Section 7"]), "Section 8")
    }

    func testASignedSuffixIsNotANumberThisHandedOut() {
        // `Int` parses "+9" and "-9"; neither is a name `AutoName` wrote, so neither counts.
        XCTAssertEqual(AutoName.next(prefix: "Loop", existing: ["Loop +9", "Loop 2"]), "Loop 3")
    }

    // MARK: - Markers: "M3" (ADR 0226 D2)

    func testMarkersNameShort() {
        XCTAssertEqual(AutoName.nextMarker(existing: []), "M1")
        XCTAssertEqual(AutoName.nextMarker(existing: ["M1", "M2"]), "M3")
    }

    /// **The collision the change could have made.** A song's markers named before ADR 0226 keep
    /// their long names; the short counter must continue past them, not start again at M1.
    func testTheShortFormContinuesPastTheLongNamesMarkersAlreadyHave() {
        XCTAssertEqual(AutoName.nextMarker(existing: ["Marker 1", "Marker 5"]), "M6")
        XCTAssertEqual(AutoName.nextMarker(existing: ["Marker 3", "M4"]), "M5")
        XCTAssertEqual(AutoName.nextMarker(existing: ["M7", "Marker 2"]), "M8")
    }

    func testMarkerNamesTheUserTypedStillDontCount() {
        let existing = ["Mid solo", "Marker", "M", "Marker 2b", "M 9", "M3"]
        XCTAssertEqual(AutoName.nextMarker(existing: existing), "M4")
    }

    func testTheHighWaterMarkHoldsForMarkers() {
        // M2 was deleted — the next is past the highest still present.
        XCTAssertEqual(AutoName.nextMarker(existing: ["M1", "M3"]), "M4")
    }
}
