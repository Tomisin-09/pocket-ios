import XCTest
@testable import Pocket

/// `LoopRunMode` is the loop-block mode tag (ADR 0104 Slice 2): standard trainer vs ear training,
/// primitive-backed for SwiftData, defaulting to `.trainer`. Pure enum logic — raw-value stability,
/// graceful decoding of unknown/empty (so every pre-0104 loop block reads as the trainer).
final class LoopRunModeTests: XCTestCase {

    func testRawValuesAreStableForStorage() {
        // Stored as `loopRunModeRaw`; these must not drift or existing blocks mis-decode.
        XCTAssertEqual(LoopRunMode.trainer.rawValue, "trainer")
        XCTAssertEqual(LoopRunMode.ear.rawValue, "ear")
    }

    func testDefaultIsTrainer() {
        XCTAssertEqual(LoopRunMode.default, .trainer)
    }

    func testUnknownRawFoldsToTrainer() {
        // A pre-0104 loop block has no stored value; a malformed/future one must degrade to the
        // standard trainer, never crash — the point of primitive-backed storage.
        XCTAssertEqual(LoopRunMode(raw: ""), .trainer)
        XCTAssertEqual(LoopRunMode(raw: "gibberish"), .trainer)
    }

    func testKnownRawDecodesExactly() {
        XCTAssertEqual(LoopRunMode(raw: "trainer"), .trainer)
        XCTAssertEqual(LoopRunMode(raw: "ear"), .ear)
    }

    func testRawValueRoundTrips() {
        for mode in LoopRunMode.allCases {
            XCTAssertEqual(LoopRunMode(rawValue: mode.rawValue), mode)
        }
    }
}
