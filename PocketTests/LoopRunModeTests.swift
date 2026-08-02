import XCTest
@testable import Pocket

/// `LoopRunMode` is the loop-block mode tag (ADR 0104 Slice 2, extended by ADR 0135): the standard
/// trainer, ear training, or improvising over a backing track. Primitive-backed for SwiftData and
/// defaulting to `.trainer`. Pure enum logic — raw-value stability, graceful decoding of
/// unknown/empty (so every pre-0104 loop block reads as the trainer), and the presentation strings
/// every surface draws the mode from.
final class LoopRunModeTests: XCTestCase {

    func testRawValuesAreStableForStorage() {
        // Stored as `loopRunModeRaw`; these must not drift or existing blocks mis-decode.
        XCTAssertEqual(LoopRunMode.trainer.rawValue, "trainer")
        XCTAssertEqual(LoopRunMode.ear.rawValue, "ear")
        XCTAssertEqual(LoopRunMode.improvise.rawValue, "improvise")   // ADR 0135
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
        XCTAssertEqual(LoopRunMode(raw: "improvise"), .improvise)
    }

    func testRawValueRoundTrips() {
        for mode in LoopRunMode.allCases {
            XCTAssertEqual(LoopRunMode(rawValue: mode.rawValue), mode)
        }
    }

    // MARK: - Presentation (ADR 0135)
    //
    // The row buttons, the long-press menu and the pushed screen's title in `LoopLibraryView` are all
    // built from these rather than listed per mode, which is what stops the three from disagreeing.

    func testEveryModeCarriesItsOwnPresentation() {
        var labels = Set<String>(), rowLabels = Set<String>(), symbols = Set<String>()
        for mode in LoopRunMode.allCases {
            XCTAssertFalse(mode.label.isEmpty, "\(mode) has no action label")
            XCTAssertFalse(mode.rowLabel.isEmpty, "\(mode) has no row label")
            XCTAssertFalse(mode.symbolName.isEmpty, "\(mode) has no symbol")
            labels.insert(mode.label); rowLabels.insert(mode.rowLabel)
            symbols.insert(mode.symbolName)
        }
        // Distinct, or two buttons on the same row would be indistinguishable.
        XCTAssertEqual(labels.count, LoopRunMode.allCases.count)
        XCTAssertEqual(rowLabels.count, LoopRunMode.allCases.count)
        XCTAssertEqual(symbols.count, LoopRunMode.allCases.count)
    }

    func testEveryModeIsPlaceableInARoutineBlock() {
        // The mode is stored on `RoutineItem.loopRunModeRaw`, so a mode that can't round-trip through
        // a block is a mode a routine silently forgets.
        for mode in LoopRunMode.allCases {
            let item = RoutineItem(kind: .focused, order: 0)
            item.loopRunMode = mode
            XCTAssertEqual(item.loopRunMode, mode)
            XCTAssertEqual(item.loopRunModeRaw, mode.rawValue)
        }
    }

    func testTheRowLabelIsNoLongerThanTheActionLabel() {
        // `rowLabel` exists because "Train your ear" doesn't fit under an icon. If one ever grew past
        // its action label, the compact form has stopped being compact.
        for mode in LoopRunMode.allCases {
            XCTAssertLessThanOrEqual(mode.rowLabel.count, mode.label.count, "\(mode)")
        }
    }
}
