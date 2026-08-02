import XCTest
@testable import Pocket

/// `EntryKind` is the loop-journal entry tag (ADR 0038): a closed set, primitive-backed
/// for SwiftData, defaulting to `.note`. Pure enum logic — raw-value stability,
/// graceful decoding of unknown/empty, labels, and picker order.
final class EntryKindTests: XCTestCase {

    func testRawValuesAreStableForStorage() {
        // SwiftData stores `kindRaw`; these must not drift or existing entries mis-decode.
        XCTAssertEqual(EntryKind.goal.rawValue, "goal")
        XCTAssertEqual(EntryKind.breakthrough.rawValue, "breakthrough")
        XCTAssertEqual(EntryKind.struggle.rawValue, "struggle")
        XCTAssertEqual(EntryKind.note.rawValue, "note")
        XCTAssertEqual(EntryKind.session.rawValue, "session")
        XCTAssertEqual(EntryKind.ear.rawValue, "ear")   // ADR 0104 — ear-training note tag
        XCTAssertEqual(EntryKind.improvise.rawValue, "improvise")   // ADR 0135 — jam note tag
    }

    func testEarKindDecodesAndHasGlyph() {
        // The ADR 0104 addition: 👂 "Ear", storable and round-tripping like every other kind.
        XCTAssertEqual(EntryKind(raw: "ear"), .ear)
        XCTAssertEqual(EntryKind.ear.emoji, "👂")
        XCTAssertEqual(EntryKind.ear.label, "Ear")
        XCTAssertTrue(EntryKind.pickerOrder.contains(.ear))
    }

    func testImproviseKindDecodesAndHasGlyph() {
        // The ADR 0135 addition: 🎸 "Improv", what came out of a jam over a backing-track loop.
        // Added the established safe way — a new case on the `String`-raw enum, never a stored enum
        // attribute — so an older build reading a newer store folds it to `.note` rather than faulting.
        XCTAssertEqual(EntryKind(raw: "improvise"), .improvise)
        XCTAssertEqual(EntryKind.improvise.emoji, "🎸")
        XCTAssertEqual(EntryKind.improvise.label, "Improv")
        XCTAssertTrue(EntryKind.pickerOrder.contains(.improvise))
    }

    func testRawValueRoundTrips() {
        for kind in EntryKind.allCases {
            XCTAssertEqual(EntryKind(rawValue: kind.rawValue), kind)
        }
    }

    func testDefaultIsNote() {
        XCTAssertEqual(EntryKind.default, .note)
    }

    func testUnknownRawFoldsToDefault() {
        // A malformed or future stored value must degrade to the neutral default,
        // never crash or fault — the whole point of primitive-backed storage.
        XCTAssertEqual(EntryKind(raw: "gibberish"), .note)
        XCTAssertEqual(EntryKind(raw: ""), .note)
    }

    func testKnownRawDecodesExactly() {
        XCTAssertEqual(EntryKind(raw: "goal"), .goal)
        XCTAssertEqual(EntryKind(raw: "session"), .session)
    }

    func testEveryKindHasEmojiAndLabel() {
        for kind in EntryKind.allCases {
            XCTAssertFalse(kind.emoji.isEmpty)
            XCTAssertFalse(kind.label.isEmpty)
        }
    }

    func testPickerOrderCoversEveryCase() {
        XCTAssertEqual(Set(EntryKind.pickerOrder), Set(EntryKind.allCases))
    }
}
