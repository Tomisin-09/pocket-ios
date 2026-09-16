import XCTest
@testable import Pocket

/// **Steps in a key onto the neck** (ADR 0218 D3–D6): which shape each step gets, how its root is
/// spelled, and when a shape counts as the chord. Pure — the sheet only draws these answers.
final class ProgressionResolverTests: XCTestCase {

    private func resolve(_ step: ProgressionStep, tonic: Int, minor: Bool = false,
                         instrument: Instrument = .guitar, mine: [ChordVoicing] = [],
                         preference: NoteSpelling = .sharps) -> ProgressionResolver.Resolved {
        ProgressionResolver.resolve(step, in: ProgressionKey(tonic: tonic, isMinor: minor),
                                    instrument: instrument, myChords: mine, preference: preference)
    }

    // MARK: - The invariant the builder relies on (D5)

    /// **Every quality the builder offers, at every root, has a shape that is that chord.** This is what
    /// makes it safe to offer any chord in any key — break it and some progression somewhere inserts a
    /// silent row.
    func testEveryQualityAtEveryRootResolvesToThatChordOnGuitar() {
        for quality in ChordGrip.Quality.allCases {
            for root in 0..<12 {
                let step = ProgressionStep(0, quality)
                let voicing = resolve(step, tonic: root).voicing
                XCTAssertTrue(voicing.isValid, "\(quality) at \(root) is not a playable shape")
                XCTAssertTrue(ProgressionResolver.fits(voicing, root: root, quality: quality),
                              "\(quality) at \(root) resolved to \(voicing.frets), which isn't that chord")
                XCTAssertLessThanOrEqual(voicing.highestFret ?? 0, 15, "\(quality) at \(root) is off the neck")
                XCTAssertEqual(voicing.name, ProgressionKey(tonic: root).chordName(of: step, preference: .sharps))
            }
        }
    }

    func testEveryQualityAtEveryRootResolvesToABassShapeOnTheRoot() {
        for quality in ChordGrip.Quality.allCases {
            for root in 0..<12 {
                let voicing = resolve(ProgressionStep(0, quality), tonic: root, instrument: .bass).voicing
                XCTAssertTrue(voicing.isBass, "\(quality) at \(root) drew a guitar shape on a bass drill")
                XCTAssertEqual(voicing.rootPitchClass, root, "\(quality) at \(root) isn't rooted on \(root)")
            }
        }
    }

    func testEveryBuiltInProgressionResolvesInEveryKey() {
        for template in ProgressionTemplate.catalog {
            for tonic in 0..<12 {
                let key = ProgressionKey(tonic: tonic, isMinor: template.steps.readsAsMinor)
                for step in template.steps {
                    let voicing = ProgressionResolver.resolve(step, in: key, instrument: .guitar).voicing
                    XCTAssertFalse(voicing.name.isEmpty, "\(template.id) in \(tonic) has an unnamed chord")
                    XCTAssertTrue(voicing.isValid, "\(template.id) in \(tonic) has an unplayable chord")
                }
            }
        }
    }

    // MARK: - Which shape (D4)

    func testAnOpenShapeWinsWhereOneExists() {
        let gInG = resolve(ProgressionStep(0), tonic: 7).voicing
        XCTAssertEqual(gInG.frets, ChordVoicing.gMajor.frets, "the I chord in G is the open G, not a barre")
        XCTAssertEqual(gInG.name, "G")
        XCTAssertEqual(resolve(ProgressionStep(0), tonic: 5).voicing.frets, ChordVoicing.fBarre.frets)
    }

    func testTheOpenC7CountsEvenWithoutItsFifth() {
        let cSeven = resolve(ProgressionStep(0, .dom7), tonic: 0).voicing
        XCTAssertEqual(cSeven.frets, ChordVoicing.cDom7.frets)
    }

    func testWithNoOpenShapeTheLowestGripWins() {
        // B7 in E: the A-shape at fret 2 sits far lower than the E-shape at fret 7.
        let bSeven = resolve(ProgressionStep(7, .dom7), tonic: 4).voicing
        XCTAssertEqual(bSeven.frets, [2, 4, 2, 4, 2, nil])
        XCTAssertEqual(bSeven.name, "B7")
        // F♯m7 in E: the E-shape at fret 2 beats the A-shape at fret 9.
        let fSharpM7 = resolve(ProgressionStep(2, .min7), tonic: 4).voicing
        XCTAssertEqual(fSharpM7.frets, [2, 2, 2, 2, 4, 2])
        XCTAssertEqual(fSharpM7.name, "F♯m7")
    }

    // MARK: - Spelling (D3)

    func testRootsAreSpelledFromTheirDegreeNotFromASharpsList() {
        XCTAssertEqual(ProgressionKey(tonic: 0).rootName(of: ProgressionStep(10), preference: .sharps), "B♭",
                       "♭VII in C is B♭ whatever the preference — A♯ is not a chord chart's spelling")
        XCTAssertEqual(ProgressionKey(tonic: 5).rootName(of: ProgressionStep(5)), "B♭", "IV in F")
        XCTAssertEqual(ProgressionKey(tonic: 3).rootName(of: ProgressionStep(7)), "B♭", "V in E♭")
        XCTAssertEqual(ProgressionKey(tonic: 2).rootName(of: ProgressionStep(4)), "F♯", "III in D")
    }

    func testAMinorReadingProgressionSpellsItsBorrowedChords() {
        let steps = ProgressionTemplate.catalog.first { $0.id == "descending-minor" }?.steps ?? []
        XCTAssertTrue(steps.readsAsMinor)
        let key = ProgressionKey(tonic: 9, isMinor: true)
        XCTAssertEqual(steps.map { key.chordName(of: $0) }, ["Am", "G", "F", "E"])
        XCTAssertEqual(key.label(), "Am")
    }

    func testTheTwoUndecidedKeysFollowThePreference() {
        XCTAssertEqual(ProgressionKey(tonic: 6).label(preference: .flats), "G♭")
        XCTAssertEqual(ProgressionKey(tonic: 6).label(preference: .sharps), "F♯")
        XCTAssertEqual(ProgressionKey(tonic: 1, isMinor: true).label(preference: .flats), "C♯m",
                       "C♯ minor's signature is E major's, so it is sharp whatever the preference")
    }

    func testADoubleAccidentalFallsBackToTheKeysReading() {
        // ♭VI in G♭ is E𝄫 by letter — true, and not something to print on a chord.
        XCTAssertEqual(ProgressionKey(tonic: 6).rootName(of: ProgressionStep(8), preference: .flats), "D")
    }

    func testAProgressionWrittenAgainstTheWrongTonicStillMovesCorrectly() {
        // A player writes G · C · D while the builder says C: the numerals read V · I · II…
        let steps = [7, 0, 2].map { ProgressionStep.from(rootPitchClass: $0, tonic: 0, quality: .major) }
        XCTAssertEqual(steps.map { ProgressionKey(tonic: 0).chordName(of: $0) }, ["G", "C", "D"])
        // …and it still moves as the distances between those chords, which is all that sounds.
        XCTAssertEqual(steps.map { ProgressionKey(tonic: 7).chordName(of: $0) }, ["D", "G", "A"])
    }

    // MARK: - What counts as the chord

    func testASavedAdd9CanStandInForTheMajorChord() {
        let cadd9 = ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil])
        XCTAssertTrue(ProgressionResolver.fits(cadd9, root: 0, quality: .major))
        XCTAssertFalse(ProgressionResolver.fits(cadd9, root: 0, quality: .sus2), "it has a third")
    }

    func testTheThirdAndSeventhMustBeExactlyTheQualitys() {
        XCTAssertFalse(ProgressionResolver.fits(.cDom7, root: 0, quality: .major), "a C7 is not a C")
        XCTAssertFalse(ProgressionResolver.fits(.cMajor7, root: 0, quality: .dom7), "a Cmaj7 is not a C7")
        XCTAssertFalse(ProgressionResolver.fits(.aMinor, root: 9, quality: .major))
        XCTAssertTrue(ProgressionResolver.fits(.cMajor7, root: 0, quality: .maj7))
    }

    func testAPowerChordIsOnlyAPowerChord() {
        let cFive = ChordGrip.aShapeFifth.voicing(rootPitchClass: 0)
        XCTAssertTrue(ProgressionResolver.fits(cFive, root: 0, quality: .fifth))
        XCTAssertFalse(ProgressionResolver.fits(cFive, root: 0, quality: .major), "no third, so not a major chord")
        XCTAssertFalse(ProgressionResolver.fits(.cMajor, root: 0, quality: .fifth))
    }

    func testAClashingToneOrTheWrongRootDisqualifies() {
        let cFlatNine = ChordVoicing("C♭9", frets: [0, 2, 0, 2, 3, nil]) // C E G with a C♯
        XCTAssertFalse(ProgressionResolver.fits(cFlatNine, root: 0, quality: .major))
        XCTAssertFalse(ProgressionResolver.fits(.cMajor, root: 7, quality: .major), "the root must be in the bass")
    }

    // MARK: - My chords (D6)

    func testASavedChordThatFitsIsUsedWhenAskedAndKeepsItsName() {
        let cadd9 = ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil])
        let withMine = resolve(ProgressionStep(5), tonic: 7, mine: [cadd9])
        XCTAssertEqual(withMine.voicing, cadd9, "IV in G is C, and the saved Cadd9 plays it")
        XCTAssertTrue(withMine.isYours)

        let without = resolve(ProgressionStep(5), tonic: 7)
        XCTAssertEqual(without.voicing.frets, ChordVoicing.cMajor.frets)
        XCTAssertFalse(without.isYours)
    }

    func testASavedChordThatDoesNotFitOrIsForTheOtherNeckIsIgnored() {
        let savedSeventh = ChordVoicing("My C7", frets: ChordVoicing.cDom7.frets)
        XCTAssertFalse(resolve(ProgressionStep(5), tonic: 7, mine: [savedSeventh]).isYours, "a C7 can't play the IV")

        let guitarC = ChordVoicing("My C", frets: ChordVoicing.cMajor.frets)
        let onBass = resolve(ProgressionStep(5), tonic: 7, instrument: .bass, mine: [guitarC])
        XCTAssertFalse(onBass.isYours, "a six-string shape never lands in a bass drill")
        XCTAssertTrue(onBass.voicing.isBass)
    }
}
