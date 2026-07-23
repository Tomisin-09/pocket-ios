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

    /// What a generated voicing must contain, per quality: whether it's a three-note triad, the
    /// intervals (semitones above root) that must sound, and the intervals that must *not* (the 3rds a
    /// suspension replaces). The 9ths list only R-3-7-9 — the 5th is droppable in guitar voicings.
    private struct QualitySpec {
        let isTriad: Bool
        let required: [Int]
        let forbidden: [Int]
        init(triad: Bool, required: [Int], forbidden: [Int] = []) {
            self.isTriad = triad; self.required = required; self.forbidden = forbidden
        }
    }

    private static let qualitySpecs: [ChordGrip.Quality: QualitySpec] = [
        .major: .init(triad: true, required: [4, 7]),
        .minor: .init(triad: true, required: [3, 7], forbidden: [4]),
        // Power chord: root + 5th (+ octave root) only — two pitch classes, so not a triad, and it must
        // sound neither 3rd (that's the whole point of a "5").
        .fifth: .init(triad: false, required: [7], forbidden: [3, 4]),
        .dom7: .init(triad: false, required: [4, 7, 10]),
        .min7: .init(triad: false, required: [3, 7, 10], forbidden: [4]),
        .maj7: .init(triad: false, required: [4, 7, 11]),
        .sus2: .init(triad: true, required: [2, 7], forbidden: [3, 4]),
        .sus4: .init(triad: true, required: [5, 7], forbidden: [3, 4]),
        .sixth: .init(triad: false, required: [4, 7, 9]),
        .dom9: .init(triad: false, required: [4, 10, 2]),
        .maj9: .init(triad: false, required: [4, 11, 2]),
        .min9: .init(triad: false, required: [3, 10, 2], forbidden: [4])
    ]

    /// The grip's quality must show up in the generated voicing's actual pitch content.
    private func assertQualityMatches(_ voicing: ChordVoicing, _ quality: ChordGrip.Quality, label: String) {
        guard let root = voicing.rootPitchClass else { return XCTFail("no root: \(label)") }
        guard let spec = Self.qualitySpecs[quality] else { return XCTFail("no spec for \(quality): \(label)") }
        let pcs = voicing.pitchClasses
        let has: (Int) -> Bool = { pcs.contains((root + $0) % 12) }

        XCTAssertEqual(voicing.isTriad, spec.isTriad, "triad-ness for \(quality): \(label)")
        for interval in spec.required {
            XCTAssertTrue(has(interval), "\(quality) needs interval \(interval): \(label)")
        }
        for interval in spec.forbidden {
            XCTAssertFalse(has(interval), "\(quality) must not sound interval \(interval): \(label)")
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

    // MARK: - "As actually played" voicings (2026-07-13 device review)

    func testAShapeGripsMuteLowE() {
        // Every A-shape roots on the A string, so the low E (index 5) is always muted.
        for grip in ChordGrip.curated where grip.rootString == .aRoot {
            let voicing = grip.voicing(rootPitchClass: 0)
            XCTAssertNil(voicing.frets[5], "\(voicing.name): low E should be muted on an A-shape")
        }
    }

    func testAShapeTriadsAndSeventhsMuteHighE() {
        // The Tier-1/-2 non-9th A-shapes are the 4-string A-D-G-B barre — high e (index 0) muted too.
        // The 9ths break this: their iconic barre voices the top 5th on the high e (x-3-2-3-3-3), so
        // they are excluded (maj9 still mutes it for the R-3-7-9 shell — covered below).
        let nonNinth: Set<ChordGrip.Quality> = [.dom9, .maj9, .min9]
        for grip in ChordGrip.curated where grip.rootString == .aRoot && !nonNinth.contains(grip.quality) {
            let voicing = grip.voicing(rootPitchClass: 0)
            XCTAssertNil(voicing.frets[0], "\(voicing.name): high e should be muted on an A-shape triad/7th")
        }
    }

    func testEShapeMaj7IsTheShellVoicing() {
        // The E-shape maj7 mutes the A string (index 4) and high e (index 0) — the playable shell, not
        // the six-string barre-plus-stretch.
        let gmaj7 = ChordGrip.eShapeMaj7.voicing(rootPitchClass: 7)   // G
        XCTAssertNil(gmaj7.frets[0], "high e muted on the E-shape maj7 shell")
        XCTAssertNil(gmaj7.frets[4], "A string muted on the E-shape maj7 shell")
        XCTAssertEqual(gmaj7.pitchClasses, [7, 11, 2, 6], "still G B D F# = Gmaj7")
    }

    func testSixthIsEShapeOnly() {
        // The A-shape 6 voices its 6th on the high e — muting that string would erase it — so Sixth is
        // offered only on the E-shape, where the 6th sits on the B string.
        let sixthFamilies = ChordGrip.curated.filter { $0.quality == .sixth }.map(\.rootString)
        XCTAssertEqual(sixthFamilies, [.eRoot], "Sixth is E-shape only")
        XCTAssertTrue(ChordGrip.eShapeSixth.voicing(rootPitchClass: 4).pitchClasses.contains(1),
                      "E6 still sounds its 6th (C#)")
    }

    // MARK: - 9th grips (ADR 0101) — known-shape oracles, octave-bump, and reverse naming

    func testAShape9thsMatchTheStandardChartAtC() {
        // The three A-shape 9ths at C are the shapes every chart prints (tab shown low→high).
        XCTAssertEqual(ChordGrip.aShapeDom9.voicing(rootPitchClass: 0).frets, [3, 3, 3, 2, 3, nil],
                       "A-shape 9 @ C = x-3-2-3-3-3 (the funk '9 chord')")
        XCTAssertEqual(ChordGrip.aShapeMaj9.voicing(rootPitchClass: 0).frets, [nil, 3, 4, 2, 3, nil],
                       "A-shape maj9 @ C = x-3-2-4-3-x")
        XCTAssertEqual(ChordGrip.aShapeMin9.voicing(rootPitchClass: 0).frets, [3, 3, 3, 1, 3, nil],
                       "A-shape m9 @ C = x-3-1-3-3-3")
    }

    func testEShapeDom9MatchesTheF9Barre() {
        // E-shape 9 @ F is the 6-string F9 barre, 1-3-1-2-1-3 low→high.
        XCTAssertEqual(ChordGrip.eShapeDom9.voicing(rootPitchClass: 5).frets, [3, 1, 2, 1, 3, 1],
                       "E-shape 9 @ F = the F9 barre")
    }

    func testSubRootGripBumpsAnOctaveRatherThanFallingOffTheNut() {
        // A-shape m9's D-string ♭3 sits two frets below the root; at A (root fret 0) a naive placement
        // would be fret -2. The octave-bump lands the whole shape at fret 12 instead — still valid, still
        // Am9, just higher up the neck (ADR 0101).
        let am9 = ChordGrip.aShapeMin9.voicing(rootPitchClass: 9)   // A
        XCTAssertTrue(am9.isValid, "the bumped shape is playable")
        XCTAssertTrue((am9.frets.compactMap { $0 }).allSatisfy { $0 >= 0 }, "no string falls off the nut")
        XCTAssertEqual(am9.frets[4], 12, "root sits on the A string at fret 12 after the octave bump")
        XCTAssertEqual(am9.rootPitchClass, 9, "still rooted on A")
    }

    func testNonNinthGripsAreUnaffectedByTheBump() {
        // Every offset-≥0 grip must place identically to before at every root (open shapes never bump).
        for grip in ChordGrip.curated where !(grip.offsets.compactMap { $0 }.contains { $0 < 0 }) {
            for root in 0..<12 {
                let low = grip.voicing(rootPitchClass: root).frets.compactMap { $0 }.min() ?? 0
                XCTAssertLessThan(low, 12, "\(grip.name) \(grip.quality) @ \(root) should not have bumped")
            }
        }
    }

    func testNamerRecognisesTheSlid9thGrips() {
        // The reverse-lookup namer (ADR 0093) must independently spell the generated 9ths — this is what
        // the sheet's identity caption shows, and it exercises both the full and drop-5 catalog forms.
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.aShapeDom9.voicing(rootPitchClass: 0)), "C9")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.aShapeMaj9.voicing(rootPitchClass: 0)), "Cmaj9")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.aShapeMin9.voicing(rootPitchClass: 0)), "Cm9")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.eShapeDom9.voicing(rootPitchClass: 5)), "F9")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.eShapeMaj9.voicing(rootPitchClass: 5)), "Fmaj9")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.eShapeMin9.voicing(rootPitchClass: 5)), "Fm9")
    }

    // MARK: - Power chords (ADR 0106)

    func testPowerChordShapesAtKnownRoots() {
        // E-shape power rooted on the open low E is E5: low-E/A/D at 0-2-2, the top three strings muted.
        let ePower = ChordGrip.eShapeFifth.voicing(rootPitchClass: 4)   // E
        XCTAssertEqual(ePower.frets, [nil, nil, nil, 2, 2, 0], "E5 = 0-2-2 on low E / A / D, top muted")
        XCTAssertEqual(ePower.name, "E5", "auto-named from the root + '5' suffix")
        XCTAssertEqual(ePower.pitchClasses, [4, 11], "E5 sounds only E and its 5th, B")

        // A-shape power rooted on the open A is A5: A/D/G at 0-2-2, low E and the top two strings muted.
        let aPower = ChordGrip.aShapeFifth.voicing(rootPitchClass: 9)   // A
        XCTAssertEqual(aPower.frets, [nil, nil, 2, 2, 0, nil], "A5 = 0-2-2 on A / D / G, low E + top muted")
        XCTAssertEqual(aPower.name, "A5")
        XCTAssertEqual(aPower.pitchClasses, [9, 4], "A5 sounds only A and its 5th, E")
    }

    func testPowerChordsAreInTier1AndBothFamilies() {
        let fifths = ChordGrip.tier1.filter { $0.quality == .fifth }
        XCTAssertEqual(Set(fifths.map(\.name)), ["E-shape", "A-shape"],
                       "power chords ship in Tier 1 on both CAGED root strings")
    }

    func testRootStringCarriesTheRootFret() {
        // A-shape at C (pc 0): A string open is pc 9, so the root fret is 3; the A-string entry (index
        // 4, offset 0) lands on fret 3 and the low E (index 5) stays muted.
        let voicing = ChordGrip.aShapeMajor.voicing(rootPitchClass: 0)
        XCTAssertEqual(voicing.frets[4], 3, "root sits on the A string at fret 3 for C")
        XCTAssertNil(voicing.frets[5], "low E stays muted on an A-shape grip")
    }
}
