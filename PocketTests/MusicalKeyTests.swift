import XCTest
@testable import Pocket

/// Covers the ADR 0036 key mapping pass: legacy free-text → closed `MusicalKey` cases,
/// flats folded onto sharps, canonical round-tripping, and ordering. Pure logic, no SwiftData.
final class MusicalKeyTests: XCTestCase {
    func testEmptyAndWhitespaceParseToUnknown() {
        XCTAssertEqual(MusicalKey.parse(""), .unknown)
        XCTAssertEqual(MusicalKey.parse("   "), .unknown)
    }

    func testCanonicalRawValuesRoundTrip() {
        for key in MusicalKey.allCases {
            XCTAssertEqual(MusicalKey.parse(key.rawValue), key, "raw \"\(key.rawValue)\"")
        }
    }

    func testBareRootIsMajor() {
        XCTAssertEqual(MusicalKey.parse("C"), .cMajor)
        XCTAssertEqual(MusicalKey.parse("g"), .gMajor)
    }

    func testMinorSpellings() {
        XCTAssertEqual(MusicalKey.parse("Am"), .aMinor)
        XCTAssertEqual(MusicalKey.parse("A minor"), .aMinor)
        XCTAssertEqual(MusicalKey.parse("Amin"), .aMinor)
        XCTAssertEqual(MusicalKey.parse("a min"), .aMinor)
        XCTAssertEqual(MusicalKey.parse("G minor"), .gMinor)
    }

    func testMajorSpellings() {
        XCTAssertEqual(MusicalKey.parse("C major"), .cMajor)
        XCTAssertEqual(MusicalKey.parse("Cmaj"), .cMajor)
        XCTAssertEqual(MusicalKey.parse("c maj"), .cMajor)
    }

    func testSharpsAndFlatsFoldTogether() {
        XCTAssertEqual(MusicalKey.parse("C#"), .cSharpMajor)
        XCTAssertEqual(MusicalKey.parse("Db"), .cSharpMajor)   // Db == C#
        XCTAssertEqual(MusicalKey.parse("Bb"), .aSharpMajor)   // Bb == A#
        XCTAssertEqual(MusicalKey.parse("Ebm"), .dSharpMinor)  // Eb minor == D#m
        XCTAssertEqual(MusicalKey.parse("C\u{266D}"), .bMajor) // Cb == B (wraps)
    }

    func testUnrecognisedParsesToUnknown() {
        XCTAssertEqual(MusicalKey.parse("H"), .unknown)
        XCTAssertEqual(MusicalKey.parse("Bm7"), .unknown)
        XCTAssertEqual(MusicalKey.parse("nonsense"), .unknown)
    }

    func testDisplayNameAndPickerLabel() {
        XCTAssertEqual(MusicalKey.aMinor.displayName, "A minor")
        XCTAssertEqual(MusicalKey.cSharpMajor.displayName, "C# major")
        XCTAssertEqual(MusicalKey.unknown.displayName, "")
        XCTAssertEqual(MusicalKey.unknown.pickerLabel, "Unknown")
    }

    func testPitchClassAndQuality() {
        XCTAssertEqual(MusicalKey.cMajor.pitchClass, 0)
        XCTAssertEqual(MusicalKey.bMinor.pitchClass, 11)
        XCTAssertNil(MusicalKey.unknown.pitchClass)
        XCTAssertEqual(MusicalKey.aMinor.quality, .minor)
        XCTAssertEqual(MusicalKey.aMajor.quality, .major)
        XCTAssertNil(MusicalKey.unknown.quality)
    }

    func testPickerOrderUnknownFirstThenByPitch() {
        let order = MusicalKey.pickerOrder
        XCTAssertEqual(order.first, .unknown)
        XCTAssertEqual(order.count, MusicalKey.allCases.count)
        // After Unknown, the first three are C major, C minor, C# major (pitch, major first).
        XCTAssertEqual(Array(order[1...3]), [.cMajor, .cMinor, .cSharpMajor])
        XCTAssertEqual(order.last, .bMinor)
    }
}
