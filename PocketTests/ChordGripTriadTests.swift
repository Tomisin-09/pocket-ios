import XCTest
@testable import Pocket

/// The triad grips (ADR 0109, ADR 0313) — major, minor and diminished on the three upper string sets in
/// all three inversions, and augmented once per set. Pure geometry, verified against the expected
/// pitch-class sets, bass tone per inversion, and names.
final class ChordGripTriadTests: XCTestCase {
    /// A triad's three tones above C, by quality.
    private func tones(_ quality: ChordGrip.Quality) -> Set<Int> {
        switch quality {
        case .major: [0, 4, 7]          // C E G
        case .minor: [0, 3, 7]          // C E♭ G
        case .diminished: [0, 3, 6]     // C E♭ G♭
        case .augmented: [0, 4, 8]      // C E G♯
        default: []
        }
    }

    /// Every triad, placed at C (pc 0), sounds exactly its three chord tones and nothing else —
    /// inversion changes the voicing, not the chord.
    func testTriadsAtCSoundTheRightThreeNotes() {
        for grip in ChordGrip.triads {
            XCTAssertEqual(Set(grip.voicing(rootPitchClass: 0).pitchClasses), tones(grip.quality),
                           "\(grip.name) \(grip.inversionName) \(grip.quality)")
        }
    }

    /// Every triad at every root sounds that root's chord: the shape is right everywhere, not only at C.
    func testTriadsAtEveryRootSoundTheirChord() {
        for grip in ChordGrip.triads {
            for root in 0..<12 {
                let expected = Set(tones(grip.quality).map { ($0 + root) % 12 })
                XCTAssertEqual(Set(grip.voicing(rootPitchClass: root).pitchClasses), expected,
                               "\(grip.name) \(grip.inversionName) \(grip.quality) at \(root)")
            }
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
            let third = grip.quality == .major || grip.quality == .augmented ? 4 : 3
            let fifth = grip.quality == .diminished ? 6 : (grip.quality == .augmented ? 8 : 7)
            let expectedBass: Int
            switch grip.inversion {
            case 1: expectedBass = third    // the 3rd
            case 2: expectedBass = fifth    // the 5th
            default: expectedBass = 0       // the root
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
        XCTAssertEqual(ChordGrip.triadDGBDim2.voicing(rootPitchClass: 11).name, "Bdim")
        XCTAssertEqual(ChordGrip.triadADGAug.voicing(rootPitchClass: 0).name, "Caug")
    }

    /// The shapes at known roots, as a chart prints them (frets high e first).
    func testDiminishedAndAugmentedShapesAtKnownRoots() {
        // B dim on G-B-e: G4 · B3 · e1 — the vii° every major-key triad drill reaches.
        XCTAssertEqual(ChordGrip.triadGBEDim.voicing(rootPitchClass: 11).frets, [1, 3, 4, nil, nil, nil])
        // C aug on G-B-e: G5 · B5 · e4.
        XCTAssertEqual(ChordGrip.triadGBEAug.voicing(rootPitchClass: 0).frets, [4, 5, 5, nil, nil, nil])
    }

    /// An augmented triad is the same shape in every inversion, so the one shape placed at its 3rd is its
    /// 1st inversion: one shape per set covers all three (ADR 0313 D1).
    func testOneAugmentedShapeIsEveryInversion() {
        for grip in ChordGrip.triads where grip.quality == .augmented {
            let atC = grip.voicing(rootPitchClass: 0)
            let atE = grip.voicing(rootPitchClass: 4)
            XCTAssertEqual(Set(atC.pitchClasses), Set(atE.pitchClasses), "\(grip.name): C aug is E aug")
            XCTAssertFalse(grip.namesInversion)
        }
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

    /// The set is ordered so a 3-column grid lays each quality's three inversions on one row: every
    /// consecutive triple shares a string set + quality and runs root · 1st · 2nd inversion. Augmented has
    /// one shape per set, so its three fill the last row, one per set.
    func testTriadsAreRowGroupedBySetAndQualityAcrossInversions() {
        let triads = ChordGrip.triads.filter { $0.quality != .augmented }
        XCTAssertEqual(triads.count % 3, 0)
        let augmented = Array(ChordGrip.triads.suffix(3))
        XCTAssertTrue(augmented.allSatisfy { $0.quality == .augmented && $0.inversion == 0 }, "the last row")
        XCTAssertEqual(augmented.map(\.name), ["G-B-e", "D-G-B", "A-D-G"])
        for start in stride(from: 0, to: triads.count, by: 3) {
            let row = Array(triads[start..<start + 3])
            XCTAssertEqual(Set(row.map(\.name)).count, 1, "row \(start / 3) mixes string sets")
            XCTAssertEqual(Set(row.map(\.quality)).count, 1, "row \(start / 3) mixes qualities")
            XCTAssertEqual(row.map(\.inversion), [0, 1, 2], "row \(start / 3) isn't root/1st/2nd")
        }
    }

    /// The Insert set is the full 30 — 3 sets × 3 inversions × major, minor and diminished, and one
    /// augmented per set — and none leak into the movable barre set (ADR 0109's test, kept by ADR 0313).
    func testInsertTriadSetIsThirtyAcrossThreeInversions() {
        XCTAssertEqual(ChordPicker.insertTriadGrips.count, 30)
        XCTAssertEqual(Set(ChordPicker.insertTriadGrips.map(\.quality)), [.major, .minor, .diminished, .augmented])
        let inversions = Set(ChordPicker.insertTriadGrips.map(\.inversion))
        XCTAssertEqual(inversions, [0, 1, 2], "all three inversions present")
        for grip in ChordGrip.triads {
            XCTAssertFalse(ChordGrip.curated.contains(grip))
            XCTAssertFalse(ChordPicker.insertMovableGrips.contains(grip))
        }
    }
}
