import XCTest
@testable import Pocket

/// The pure **movable-grip** geometry (ADR 0084) — placing a `ChordGrip` at any root generates a
/// valid `ChordVoicing` whose root and quality match what was asked, and the two library barres are
/// reproduced byte-for-byte. All SwiftUI-free (M7); `ChordVoicing`'s existing accessors are the
/// correctness oracle.
final class ChordGripTests: XCTestCase {

    // MARK: - Byte-identical retrofit of the two hardcoded barres (M5)

    func testEShapeMajorAtFAReproducesFBarre() {
        // F is pitch class 5; the E-shape major slid there is the F barre chord.
        let generated = ChordGrip.eShapeMajor.voicing(rootPitchClass: 5)
        XCTAssertEqual(generated.frets, ChordVoicing.fBarre.frets, "E-shape major @ F must equal fBarre")
        XCTAssertEqual(generated.name, ChordVoicing.fBarre.name, "auto-named 'F'")
    }

    func testAShapeMinorAtBReproducesBMinorBarre() {
        // B is pitch class 11; the A-shape minor slid there is the Bm barre chord.
        let generated = ChordGrip.aShapeMinor.voicing(rootPitchClass: 11)
        XCTAssertEqual(generated.frets, ChordVoicing.bMinorBarre.frets, "A-shape minor @ B must equal bMinorBarre")
        XCTAssertEqual(generated.name, ChordVoicing.bMinorBarre.name, "auto-named 'Bm'")
    }

    // MARK: - Property net: every grip, every root, is a valid voicing with the right root & quality

    func testEveryGripAtEveryRootIsValidWithMatchingRootAndQuality() {
        for grip in ChordGrip.curated {
            for rootPitchClass in 0..<12 {
                let voicing = grip.voicing(rootPitchClass: rootPitchClass)
                let label = "\(grip.name) \(grip.quality) @ pc \(rootPitchClass) → \(voicing.name)"

                XCTAssertTrue(voicing.isValid, "not playable: \(label)")
                XCTAssertEqual(voicing.rootPitchClass, rootPitchClass, "wrong root: \(label)")
                assertQualityMatches(voicing, grip.quality, label: label)
            }
        }
    }

    /// The grip's quality must show up in the generated voicing's actual pitch content.
    private func assertQualityMatches(_ voicing: ChordVoicing, _ quality: ChordGrip.Quality, label: String) {
        guard let root = voicing.rootPitchClass else { return XCTFail("no root: \(label)") }
        let pcs = voicing.pitchClasses
        let has: (Int) -> Bool = { pcs.contains((root + $0) % 12) }

        switch quality {
        case .major:
            XCTAssertTrue(voicing.isTriad, "major should be a triad: \(label)")
            XCTAssertTrue(has(4) && has(7), "major = root+M3+P5: \(label)")
        case .minor:
            XCTAssertTrue(voicing.isTriad, "minor should be a triad: \(label)")
            XCTAssertTrue(voicing.isMinorQuality, "minor quality: \(label)")
            XCTAssertTrue(has(3) && has(7), "minor = root+m3+P5: \(label)")
        case .dom7:
            XCTAssertFalse(voicing.isTriad, "dom7 is four notes: \(label)")
            XCTAssertTrue(has(4) && has(7) && has(10), "dom7 = root+M3+P5+m7: \(label)")
        case .min7:
            XCTAssertFalse(voicing.isTriad, "min7 is four notes: \(label)")
            XCTAssertTrue(has(3) && has(7) && has(10), "min7 = root+m3+P5+m7: \(label)")
        case .maj7:
            XCTAssertFalse(voicing.isTriad, "maj7 is four notes: \(label)")
            XCTAssertTrue(has(4) && has(7) && has(11), "maj7 = root+M3+P5+M7: \(label)")
        case .sus2:
            XCTAssertTrue(voicing.isTriad, "sus2 is three notes: \(label)")
            XCTAssertTrue(has(2) && has(7) && !has(3) && !has(4), "sus2 = root+M2+P5, no 3rd: \(label)")
        case .sus4:
            XCTAssertTrue(voicing.isTriad, "sus4 is three notes: \(label)")
            XCTAssertTrue(has(5) && has(7) && !has(3) && !has(4), "sus4 = root+P4+P5, no 3rd: \(label)")
        case .sixth:
            XCTAssertFalse(voicing.isTriad, "6 is four notes: \(label)")
            XCTAssertTrue(has(4) && has(7) && has(9), "6 = root+M3+P5+M6: \(label)")
        }
    }

    // MARK: - Naming (M2)

    func testSlidGripAutoNamesFromRootAndQuality() {
        XCTAssertEqual(ChordGrip.eShapeDom7.voicing(rootPitchClass: 7).name, "G7")   // E-shape @ G
        XCTAssertEqual(ChordGrip.aShapeMaj7.voicing(rootPitchClass: 0).name, "Cmaj7") // A-shape @ C
        XCTAssertEqual(ChordGrip.aShapeMin7.voicing(rootPitchClass: 2).name, "Dm7")   // A-shape @ D
        XCTAssertEqual(ChordGrip.aShapeSus2.voicing(rootPitchClass: 9).name, "Asus2") // A-shape @ A
        XCTAssertEqual(ChordGrip.eShapeSixth.voicing(rootPitchClass: 4).name, "E6")   // E-shape @ E
    }

    // MARK: - Curated tiers (M3)

    func testSus2IsAShapeOnly() {
        // The E-shape sus2 is the awkward stretch nobody plays (M3), so it's absent from the E family.
        let eShapeQualities = ChordGrip.curated.filter { $0.rootString == .eRoot }.map(\.quality)
        let aShapeQualities = ChordGrip.curated.filter { $0.rootString == .aRoot }.map(\.quality)
        XCTAssertFalse(eShapeQualities.contains(.sus2), "no E-shape sus2")
        XCTAssertTrue(aShapeQualities.contains(.sus2), "A-shape sus2 is offered")
    }

    func testCuratedIsTier1PlusTier2() {
        XCTAssertEqual(ChordGrip.curated.count, ChordGrip.tier1.count + ChordGrip.tier2.count)
    }

    func testRootStringCarriesTheRootFret() {
        // A-shape at C (pc 0): A string open is pc 9, so the root fret is 3; the A-string entry (index
        // 4, offset 0) lands on fret 3 and the low E (index 5) stays muted.
        let voicing = ChordGrip.aShapeMajor.voicing(rootPitchClass: 0)
        XCTAssertEqual(voicing.frets[4], 3, "root sits on the A string at fret 3 for C")
        XCTAssertNil(voicing.frets[5], "low E stays muted on an A-shape grip")
    }
}
