import XCTest
@testable import Pocket

/// `LoopType` is a closed, single-select vocabulary (ADR 0036). Pure enum logic —
/// raw-value storage stability, round-trip, labels, and picker order.
final class LoopTypeTests: XCTestCase {

    func testRawValuesAreStableForStorage() {
        // SwiftData stores the raw value; these must not drift or existing loops mis-decode.
        XCTAssertEqual(LoopType.unset.rawValue, "")
        XCTAssertEqual(LoopType.lick.rawValue, "lick")
        XCTAssertEqual(LoopType.riff.rawValue, "riff")
        XCTAssertEqual(LoopType.chords.rawValue, "chords")
    }

    func testRawValueRoundTrips() {
        for type in LoopType.allCases {
            XCTAssertEqual(LoopType(rawValue: type.rawValue), type)
        }
    }

    func testUnsetLabelIsADash() {
        XCTAssertEqual(LoopType.unset.label, "—")
    }

    func testPickerOrderIsUnsetThenDensityOrder() {
        XCTAssertEqual(LoopType.pickerOrder, [.unset, .lick, .riff, .chords])
    }

    func testPickerOrderCoversEveryCase() {
        XCTAssertEqual(Set(LoopType.pickerOrder), Set(LoopType.allCases))
    }
}
