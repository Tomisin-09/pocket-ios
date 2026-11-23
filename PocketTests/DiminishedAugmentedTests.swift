import XCTest
@testable import Pocket

/// **Diminished and augmented** (ADR 0313 D1): the two triads that join major and minor — in the chord
/// picker, on the neck at every root, and in a progression as vii° and III+. Pure: the picker and the
/// builder only draw what these say.
final class DiminishedAugmentedTests: XCTestCase {

    // MARK: - The curated grips are the shapes a chart prints

    func testTheFourCuratedGripsAtCAreTheStandardShapes() {
        // Frets high e first, so read them right to left against a chart's low→high tab.
        XCTAssertEqual(ChordGrip.eShapeDiminished.voicing(rootPitchClass: 0).frets, [nil, nil, 8, 10, 9, 8],
                       "E-shape dim @ C = 8-9-10-8-x-x")
        XCTAssertEqual(ChordGrip.aShapeDiminished.voicing(rootPitchClass: 0).frets, [nil, 4, 5, 4, 3, nil],
                       "A-shape dim @ C = x-3-4-5-4-x")
        XCTAssertEqual(ChordGrip.eShapeAugmented.voicing(rootPitchClass: 0).frets, [nil, 9, 9, 10, nil, 8],
                       "E-shape aug @ C = 8-x-10-9-9-x")
        XCTAssertEqual(ChordGrip.aShapeAugmented.voicing(rootPitchClass: 0).frets, [nil, 1, 1, 2, 3, nil],
                       "A-shape aug @ C = x-3-2-1-1-x")
    }

    func testTheyNameThemselvesAsChordNamerDoes() {
        XCTAssertEqual(ChordGrip.aShapeDiminished.voicing(rootPitchClass: 11).name, "Bdim")
        XCTAssertEqual(ChordGrip.eShapeAugmented.voicing(rootPitchClass: 0).name, "Caug")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.aShapeDiminished.voicing(rootPitchClass: 11)), "Bdim")
        XCTAssertEqual(ChordNamer.bestName(for: ChordGrip.triadGBEDim1.voicing(rootPitchClass: 11)), "Bdim/D")
    }

    // MARK: - A progression's vii° and III+

    func testTheirNumeralsAreTheOnesChordNumeralWrites() throws {
        XCTAssertEqual(ProgressionStep(11, .diminished).numeral, "vii°")
        XCTAssertEqual(ProgressionStep(4, .augmented).numeral, "III+")
        XCTAssertEqual(ProgressionStep(2, .diminished).numeral, "ii°", "ii° — the minor key's own")
        // A song's chord badge (ADR 0308) and a progression's numeral must not number one chord two ways.
        for step in [ProgressionStep(11, .diminished), ProgressionStep(4, .augmented)] {
            let badge = try XCTUnwrap(ChordNumeral.read(root: step.semitones, suffix: step.quality.nameSuffix,
                                                        in: .cMajor))
            XCTAssertEqual(step.numeral, badge.numeral)
        }
    }

    func testADiminishedChordIsMinorFamilyAndAnAugmentedOneIsNot() {
        XCTAssertTrue(ProgressionStep(11, .diminished).isMinorFamily)
        XCTAssertFalse(ProgressionStep(4, .augmented).isMinorFamily)
    }

    func testTheyAreSpelledFromTheKey() {
        XCTAssertEqual(ProgressionKey(tonic: 0).chordName(of: ProgressionStep(11, .diminished)), "Bdim")
        XCTAssertEqual(ProgressionKey(tonic: 5).chordName(of: ProgressionStep(11, .diminished)), "Edim", "vii° in F")
        XCTAssertEqual(ProgressionKey(tonic: 10).chordName(of: ProgressionStep(11, .diminished)), "Adim",
                       "vii° in B♭")
        XCTAssertEqual(ProgressionKey(tonic: 0).chordName(of: ProgressionStep(4, .augmented)), "Eaug")
    }

    func testTheInKeyRowEndsOnVii() {
        XCTAssertEqual(ProgressionDraft.inKey.last, ProgressionStep(11, .diminished))
        XCTAssertEqual(ProgressionDraft.inKey.count, 7)
    }

    /// The stored words are what an **older** build reads. It doesn't know them, so its tolerant decode
    /// (ADR 0218 D2, held by `testAnUnknownQualityOrAMissingLengthDoesNotFailTheDecode`) reads vii° as VII
    /// and keeps its place and length. Pinned, because renaming a case would turn every saved vii° into a
    /// major chord on this build too.
    func testTheyAreStoredUnderTheirOwnNamesAndRoundTrip() throws {
        let steps = [ProgressionStep(11, .diminished, bars: 2), ProgressionStep(4, .augmented)]
        let data = try JSONEncoder().encode(steps)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains(#""quality":"diminished""#), json)
        XCTAssertTrue(json.contains(#""quality":"augmented""#), json)
        XCTAssertEqual(try JSONDecoder().decode([ProgressionStep].self, from: data), steps)

        let olderBuildsReading = Data(#"[{"semitones":11,"quality":"halfDiminished","bars":2}]"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode([ProgressionStep].self, from: olderBuildsReading),
                       [ProgressionStep(11, .major, bars: 2)], "a quality a build doesn't know: B, not Bdim")
    }

    // MARK: - What counts as the chord

    func testTheAlteredFifthMustSoundAndThePerfectOneMustNot() {
        let bDim = ChordGrip.aShapeDiminished.voicing(rootPitchClass: 11)
        XCTAssertTrue(ProgressionResolver.fits(bDim, root: 11, quality: .diminished))
        XCTAssertFalse(ProgressionResolver.fits(bDim, root: 11, quality: .minor), "a ♭5 is not a minor chord")
        XCTAssertFalse(ProgressionResolver.fits(ChordVoicing.bMinorBarre, root: 11, quality: .diminished),
                       "Bm has no ♭5")

        let cAug = ChordGrip.aShapeAugmented.voicing(rootPitchClass: 0)
        XCTAssertTrue(ProgressionResolver.fits(cAug, root: 0, quality: .augmented))
        XCTAssertFalse(ProgressionResolver.fits(cAug, root: 0, quality: .major), "a ♯5 is not a major chord")
        XCTAssertFalse(ProgressionResolver.fits(.cMajor, root: 0, quality: .augmented))
    }

    func testAPerfectFifthBesideTheAlteredOneDisqualifies() {
        // B D F with an F♯ on top, and C E G♯ with a G: each sounds both fifths, so it's neither chord.
        let bClash = ChordVoicing("clash", frets: [2, 6, nil, 0, 2, nil])
        XCTAssertEqual(Set(bClash.pitchClasses), [11, 2, 5, 6], "precondition: B D F F♯")
        XCTAssertFalse(ProgressionResolver.fits(bClash, root: 11, quality: .diminished))
        let cClash = ChordVoicing("clash", frets: [3, nil, 1, 2, 3, nil])
        XCTAssertEqual(Set(cClash.pitchClasses), [0, 4, 8, 7], "precondition: C E G♯ G")
        XCTAssertFalse(ProgressionResolver.fits(cClash, root: 0, quality: .augmented))
    }

    func testADim7DoesNotStandInForADiminishedTriad() {
        // B D F A♭ — the 6th a major chord may carry would make this another chord.
        let bDimSeven = ChordVoicing("Bdim7", frets: [nil, 3, 1, 3, 2, nil])
        XCTAssertFalse(ProgressionResolver.fits(bDimSeven, root: 11, quality: .diminished))
    }

    func testOnBassTheyPlayTheirTenth() {
        let key = ProgressionKey(tonic: 0)
        let vii = ProgressionResolver.resolve(ProgressionStep(11, .diminished), in: key, instrument: .bass).voicing
        XCTAssertEqual(vii.frets, BassChordShape.minorTenth.voicing(rootPitchClass: 11)?.frets)
        XCTAssertEqual(vii.name, "Bdim", "named for the chord, though the bass states its third")
        let aug = ProgressionResolver.resolve(ProgressionStep(4, .augmented), in: key, instrument: .bass).voicing
        XCTAssertEqual(aug.frets, BassChordShape.majorTenth.voicing(rootPitchClass: 4)?.frets)
    }

    // MARK: - The picker

    func testAnAugmentedChipNamesNoInversion() {
        XCTAssertEqual(ChordPicker.triadSubtitle(.triadGBEAug), "G-B-e")
        XCTAssertEqual(ChordPicker.triadSubtitle(.triadGBEDim1), "G-B-e · 1st inv")
        XCTAssertFalse(ChordPicker.triadSearchText(.triadGBEAug).contains("inversion"))
        XCTAssertTrue(ChordPicker.matches(query: "diminished", in: ChordPicker.triadSearchText(.triadDGBDim)))
    }

    func testTheFourStringGripsAreNotCalledBarres() {
        XCTAssertEqual(ChordPicker.movableSubtitle(.aShapeDiminished), "A-shape")
        XCTAssertEqual(ChordPicker.movableSubtitle(.eShapeAugmented), "E-shape")
        XCTAssertEqual(ChordPicker.movableSubtitle(.aShapeSus4), "A-shape barre", "the rest are unchanged")
        XCTAssertTrue(ChordPicker.matches(query: "aug", in: ChordPicker.movableSearchText(.eShapeAugmented,
                                                                                         placedName: "Caug")))
    }
}
