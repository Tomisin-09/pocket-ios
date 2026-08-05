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
        // The label spells by the key itself (ADR 0123): C♯ major is written D♭ major (5 flats, not 7
        // sharps). Only the *label* moves — the stored `rawValue` is still the canonical "C#".
        XCTAssertEqual(MusicalKey.cSharpMajor.displayName, "D♭ major")
        XCTAssertEqual(MusicalKey.cSharpMajor.rawValue, "C#")
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

    // MARK: - Composing a key from its two halves (the split picker, v2 close-out N10)

    /// Every case except `.unknown` has to be reachable from the picker's two controls, and land back
    /// on itself. If this ever fails, some key is simply unpickable — with no error anywhere.
    func testMakeReachesEveryKeyAndRoundTrips() {
        for key in MusicalKey.allCases where key != .unknown {
            guard let pitchClass = key.pitchClass, let quality = key.quality else {
                return XCTFail("\(key.rawValue) has no root or quality")
            }
            let made = MusicalKey.make(pitchClass: pitchClass, quality: quality)
            XCTAssertEqual(made, key, "make(\(pitchClass), \(quality))")
            XCTAssertEqual(MusicalKey.parse(made.rawValue), key, "parse(\(made.rawValue))")
        }
    }

    /// `pitchClass` wraps, so the grid can hand over a raw index without clamping first.
    func testMakeWrapsPitchClass() {
        XCTAssertEqual(MusicalKey.make(pitchClass: 12, quality: .major), .cMajor)
        XCTAssertEqual(MusicalKey.make(pitchClass: -1, quality: .minor), .bMinor)
    }

    /// The root buttons are labelled key-first (ADR 0123), so the **same pitch spells differently in
    /// the two tonalities** — which is why the grid re-labels when the segmented control flips, and
    /// the thing most likely to look like a bug if it ever stopped happening.
    func testRootLabelIsSpelledByTheKeyNotThePitch() {
        XCTAssertEqual(MusicalKey.make(pitchClass: 3, quality: .major).rootLabel, "E♭")
        XCTAssertEqual(MusicalKey.make(pitchClass: 3, quality: .minor).rootLabel, "D♯")
        XCTAssertEqual(MusicalKey.unknown.rootLabel, "")
    }

    /// The label on a button and the label in the footer describe one key, so the root has to be the
    /// front of the full name rather than a second spelling of it.
    func testRootLabelLeadsTheDisplayName() {
        for key in MusicalKey.allCases where key != .unknown {
            XCTAssertTrue(key.displayName.hasPrefix(key.rootLabel + " "),
                          "\(key.rawValue): \"\(key.rootLabel)\" vs \"\(key.displayName)\"")
        }
    }
}
