import XCTest
@testable import Pocket

/// The root-position triad grips (ADR 0109) — major/minor on the three upper string sets. Pure geometry,
/// verified against the expected pitch-class sets and names, kept out of `ChordGripTests` to respect the
/// type-body limit.
final class ChordGripTriadTests: XCTestCase {
    /// Every triad, placed at C (pc 0), should sound exactly its three chord tones and nothing else.
    func testTriadsAtCSoundTheRightThreeNotes() {
        let major = Set([0, 4, 7])   // C E G
        let minor = Set([0, 3, 7])   // C E♭ G
        for grip in [ChordGrip.triadGBEMajor, .triadDGBMajor, .triadADGMajor] {
            XCTAssertEqual(Set(grip.voicing(rootPitchClass: 0).pitchClasses), major, "\(grip.name) major")
        }
        for grip in [ChordGrip.triadGBEMinor, .triadDGBMinor, .triadADGMinor] {
            XCTAssertEqual(Set(grip.voicing(rootPitchClass: 0).pitchClasses), minor, "\(grip.name) minor")
        }
    }

    /// Each triad sounds exactly three strings (root, 3rd, 5th — no doublings).
    func testTriadsSoundExactlyThreeStrings() {
        for grip in ChordGrip.triads {
            let sounding = grip.voicing(rootPitchClass: 0).frets.compactMap { $0 }
            XCTAssertEqual(sounding.count, 3, "\(grip.name) \(grip.quality) should voice 3 strings")
        }
    }

    /// A triad names itself plainly from root + quality — "C" / "Cm" — like any other major/minor chord.
    func testTriadsAutoNameFromRootAndQuality() {
        XCTAssertEqual(ChordGrip.triadGBEMajor.voicing(rootPitchClass: 0).name, "C")
        XCTAssertEqual(ChordGrip.triadADGMinor.voicing(rootPitchClass: 2).name, "Dm")
        XCTAssertEqual(ChordGrip.triadDGBMajor.voicing(rootPitchClass: 7).name, "G")
    }

    /// Every triad at every root is a playable voicing (the octave-bump keeps low roots off the nut).
    func testEveryTriadAtEveryRootIsValid() {
        for grip in ChordGrip.triads {
            for root in 0..<12 {
                XCTAssertTrue(grip.voicing(rootPitchClass: root).isValid,
                              "\(grip.name) \(grip.quality) at root \(root) is not playable")
            }
        }
    }

    func testTriadsAreNotPartOfTheMovableCuratedSet() {
        // Triads are their own Insert category, not folded into the movable barre set.
        for grip in ChordGrip.triads {
            XCTAssertFalse(ChordGrip.curated.contains(grip))
            XCTAssertFalse(ChordPicker.insertMovableGrips.contains(grip))
        }
        XCTAssertEqual(ChordPicker.insertTriadGrips.count, 6)
    }
}
