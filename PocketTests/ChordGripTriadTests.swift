import XCTest
@testable import Pocket

/// The triad grips (ADR 0109) — major/minor on the three upper string sets, in all three inversions.
/// Pure geometry, verified against the expected pitch-class sets, bass tone per inversion, and names.
final class ChordGripTriadTests: XCTestCase {
    /// Every triad, placed at C (pc 0), sounds exactly its three chord tones and nothing else —
    /// inversion changes the voicing, not the chord.
    func testTriadsAtCSoundTheRightThreeNotes() {
        let major = Set([0, 4, 7])   // C E G
        let minor = Set([0, 3, 7])   // C E♭ G
        for grip in ChordGrip.triads {
            let expected = grip.quality == .major ? major : minor
            XCTAssertEqual(Set(grip.voicing(rootPitchClass: 0).pitchClasses), expected,
                           "\(grip.name) \(grip.inversionName) \(grip.quality)")
        }
    }

    /// Each triad sounds exactly three strings (root, 3rd, 5th — no doublings).
    func testTriadsSoundExactlyThreeStrings() {
        for grip in ChordGrip.triads {
            let sounding = grip.voicing(rootPitchClass: 0).frets.compactMap { $0 }
            XCTAssertEqual(sounding.count, 3, "\(grip.name) \(grip.inversionName) should voice 3 strings")
        }
    }

    /// The bass note (lowest-pitched sounding string) matches the inversion: root for root position, the
    /// 3rd for 1st inversion, the 5th for 2nd inversion.
    func testBassNoteMatchesInversion() {
        for grip in ChordGrip.triads {
            let frets = grip.voicing(rootPitchClass: 0).frets
            // Within a three-string set the highest index is the lowest-pitched (bass) string.
            guard let bassString = (0..<6).reversed().first(where: { frets[$0] != nil }),
                  let bassFret = frets[bassString] else {
                return XCTFail("\(grip.name) has no sounding string")
            }
            let bassPitchClass = GuitarScale.pitchClass(string: bassString, fret: bassFret)
            let expectedBass: Int
            switch grip.inversion {
            case 1: expectedBass = grip.quality == .major ? 4 : 3   // the 3rd
            case 2: expectedBass = 7                                // the 5th
            default: expectedBass = 0                               // the root
            }
            XCTAssertEqual(bassPitchClass, expectedBass,
                           "\(grip.name) \(grip.inversionName) \(grip.quality) bass")
        }
    }

    /// A triad names itself plainly from root + quality — "C" / "Cm" — regardless of inversion.
    func testTriadsAutoNameFromRootAndQuality() {
        XCTAssertEqual(ChordGrip.triadGBEMajor.voicing(rootPitchClass: 0).name, "C")
        XCTAssertEqual(ChordGrip.triadGBEMajor1.voicing(rootPitchClass: 0).name, "C")   // 1st inversion
        XCTAssertEqual(ChordGrip.triadADGMinor2.voicing(rootPitchClass: 2).name, "Dm")  // 2nd inversion
    }

    /// Every triad at every root is a playable voicing (the octave-bump keeps low roots off the nut).
    func testEveryTriadAtEveryRootIsValid() {
        for grip in ChordGrip.triads {
            for root in 0..<12 {
                XCTAssertTrue(grip.voicing(rootPitchClass: root).isValid,
                              "\(grip.name) \(grip.inversionName) \(grip.quality) at root \(root)")
            }
        }
    }

    /// The Insert set is the full 18 — 3 sets × 3 inversions × 2 qualities — and none leak into the
    /// movable barre set.
    func testInsertTriadSetIsEighteenAcrossThreeInversions() {
        XCTAssertEqual(ChordPicker.insertTriadGrips.count, 18)
        let inversions = Set(ChordPicker.insertTriadGrips.map(\.inversion))
        XCTAssertEqual(inversions, [0, 1, 2], "all three inversions present")
        for grip in ChordGrip.triads {
            XCTAssertFalse(ChordGrip.curated.contains(grip))
            XCTAssertFalse(ChordPicker.insertMovableGrips.contains(grip))
        }
    }
}
