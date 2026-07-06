import XCTest
@testable import Pocket

/// The pure **chord voicing** geometry (ADR 0065): every catalog shape is playable, the pitch-class
/// derivation is correct, triads read as three notes, and the diagram window anchors sanely. All
/// SwiftUI-free (T5).
final class ChordVoicingTests: XCTestCase {

    // MARK: - Library integrity

    func testEveryLibraryVoicingIsValid() {
        for voicing in ChordVoicing.library {
            XCTAssertTrue(voicing.isValid, "\(voicing.name) is not a valid voicing")
            XCTAssertEqual(voicing.frets.count, ChordVoicing.stringCount, "\(voicing.name) wrong length")
            XCTAssertFalse(voicing.soundedStrings.isEmpty, "\(voicing.name) sounds no strings")
        }
    }

    func testLibraryNamesAreUnique() {
        let names = ChordVoicing.library.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "duplicate voicing names in the library")
    }

    // MARK: - Pitch-class derivation

    func testCMajorSoundsCEG() {
        // C open (x32010): C, E, G, C, E → pitch classes {C=0, E=4, G=7}.
        XCTAssertEqual(ChordVoicing.cMajor.pitchClasses, [0, 4, 7])
    }

    func testAMinorSoundsACE() {
        // Am open (x02210): A, E, A, C, E → {A=9, C=0, E=4}.
        XCTAssertEqual(ChordVoicing.aMinor.pitchClasses, [9, 0, 4])
    }

    func testE7SoundsRootThirdFifthFlatSeventh() {
        // E7 (020100): E, B, D, G#, B, E → {E=4, G#=8, B=11, D=2}.
        XCTAssertEqual(ChordVoicing.eDom7.pitchClasses, [4, 8, 11, 2])
    }

    // MARK: - Triads are just three-note voicings

    func testTriadVoicingsReadAsThreeNotes() {
        XCTAssertTrue(ChordVoicing.cTriad.isTriad, "C triad should have three distinct pitch classes")
        XCTAssertTrue(ChordVoicing.aMinorTriad.isTriad)
        XCTAssertEqual(ChordVoicing.cTriad.pitchClasses, [0, 4, 7], "C triad = C E G")
        XCTAssertEqual(ChordVoicing.aMinorTriad.pitchClasses, [9, 0, 4], "Am triad = A C E")
    }

    func testSeventhChordsAreNotTriads() {
        XCTAssertFalse(ChordVoicing.eDom7.isTriad)
        XCTAssertFalse(ChordVoicing.cMajor7.isTriad)
    }

    // MARK: - Diagram window

    func testOpenChordAnchorsAtFretOne() {
        XCTAssertEqual(ChordVoicing.cMajor.displayBaseFret, 1)
        XCTAssertEqual(ChordVoicing.eMajor.displayBaseFret, 1)
    }

    func testHighBarreWindowsAtItsLowestFret() {
        // Bm barre tops out at fret 4 (≤4) so it still anchors at 1; build a clearly-high shape.
        let high = ChordVoicing("D (barre)", frets: [5, 7, 7, 7, 5, nil])
        XCTAssertEqual(high.displayBaseFret, 5, "a shape above the nut region windows at its lowest fret")
    }

    func testMutedAndOpenStringsAreDistinguished() {
        // D major (xx0232): low E and A are muted (nil), D is open (0).
        XCTAssertNil(ChordVoicing.dMajor.frets[5], "low E is muted on D")
        XCTAssertNil(ChordVoicing.dMajor.frets[4], "A is muted on D")
        XCTAssertEqual(ChordVoicing.dMajor.frets[3], 0, "D string is open on D")
        XCTAssertEqual(ChordVoicing.dMajor.soundedStrings, [0, 1, 2, 3])
    }

    // MARK: - Codable round-trip

    func testVoicingRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(ChordVoicing.gDom7)
        let decoded = try JSONDecoder().decode(ChordVoicing.self, from: data)
        XCTAssertEqual(decoded, ChordVoicing.gDom7)
    }
}
