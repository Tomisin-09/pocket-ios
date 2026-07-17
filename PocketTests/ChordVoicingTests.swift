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

    // MARK: - Custom placer contract (ADR 0084 M4)

    /// The custom-chord placer composes an arbitrary `[Int?]` per string and gates "Insert" on
    /// `isValid`; these lock the exact validity semantics that gate relies on.
    func testPlacerComposedVoicingIsValidWhenAnyStringSounds() {
        // A bespoke shell (Cadd9-ish): x3203x — three sounded strings, no negatives.
        let composed = ChordVoicing("Custom", frets: [nil, 3, 0, 2, 3, nil])
        XCTAssertTrue(composed.isValid, "a composed shape with sounded strings is insertable")
    }

    func testPlacerAllMutedVoicingIsInvalid() {
        // The placer starts every string muted; nothing sounds, so Insert stays disabled.
        let empty = ChordVoicing("Custom", frets: Array(repeating: nil, count: ChordVoicing.stringCount))
        XCTAssertFalse(empty.isValid, "an all-muted composition sounds nothing and is not insertable")
    }

    // MARK: - Degree labels (ADR 0084 M4 — the placer's live analysis)

    func testDegreeNameMapsTheChromaticScale() {
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: 0), "R")
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: 4), "3")
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: 7), "5")
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: 10), "♭7")
        // Wraps across the octave and handles negatives (the placer subtracts a root pitch class).
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: 12), "R")
        XCTAssertEqual(ChordVoicing.degreeName(semitonesAboveRoot: -1), "7")
    }

    func testDegreeLabelsSpellTheChordFromTheLowestNote() {
        // E dom7 (020100): E is the root → E R, B 5, D ♭7, G♯ 3, B 5, E R (high-e first index 0).
        XCTAssertEqual(ChordVoicing.eDom7.degreeLabels, ["R", "5", "3", "♭7", "5", "R"])
    }

    func testDegreeLabelsAreNilForMutedStrings() {
        // D major (xx0232): the two muted low strings carry no degree.
        let labels = ChordVoicing.dMajor.degreeLabels
        XCTAssertNil(labels[5], "muted low E has no degree")
        XCTAssertNil(labels[4], "muted A has no degree")
        XCTAssertEqual(labels[3], "R", "the open D string is the root")
    }

    func testDegreeLabelsCanAnchorToAnExplicitRoot() {
        // A 2nd-inversion B major (F♯ in bass, on D/G/B strings at fret 4). Anchored to the chord root
        // B (pitch class 11), the dots read from B: F♯ is the 5th, B the root, D♯ the 3rd — agreeing
        // with the identifier's "B/F♯" instead of the bass-relative R/4/6 (ADR 0093).
        let voicing = ChordVoicing("B/F♯", frets: [nil, 4, 4, 4, nil, nil])
        let labels = voicing.degreeLabels(relativeTo: 11)
        XCTAssertEqual(labels[1], "3", "B string → D♯ is the 3rd of B")
        XCTAssertEqual(labels[2], "R", "G string → B is the root")
        XCTAssertEqual(labels[3], "5", "D string → F♯ is the 5th of B")
    }

    // MARK: - Note labels (Display → Note)

    func testNoteLabelsNameEachSoundedString() {
        // E dom7 (020100): high-e first — e E, B B, G♯ (G string fret 1), D, B (A string fret 2), E.
        XCTAssertEqual(ChordVoicing.eDom7.noteLabels, ["E", "B", "G♯", "D", "B", "E"])
    }

    func testNoteLabelsAreNilForMutedStrings() {
        // D major (xx0232): the two muted low strings carry no note name.
        let labels = ChordVoicing.dMajor.noteLabels
        XCTAssertNil(labels[5], "muted low E has no note")
        XCTAssertNil(labels[4], "muted A has no note")
        XCTAssertEqual(labels[3], "D", "the open D string sounds D")
    }

    // MARK: - Codable round-trip

    func testVoicingRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(ChordVoicing.gDom7)
        let decoded = try JSONDecoder().decode(ChordVoicing.self, from: data)
        XCTAssertEqual(decoded, ChordVoicing.gDom7)
    }
}
