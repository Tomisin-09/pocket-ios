import XCTest
@testable import Pocket

/// The **bass chord vocabulary** (ADR 0164 slices 1–2): the tuning `ChordVoicing` derives from its own
/// shape, and the dyad/shell generator built on it.
///
/// The generator is property-tested rather than pinned to a table of expected fingerings. A table
/// would only prove that the twelve transpositions someone typed match the twelve someone typed;
/// asserting the *intervals* at every root on every string proves the thing the type actually
/// promises — that a "Cm10" spells a root and a minor tenth, wherever the hand puts it.
final class BassChordShapeTests: XCTestCase {

    // MARK: - ChordVoicing resolves its own neck

    /// Guitar is byte-identical: the derived tuning must equal the constant every existing voicing has
    /// always been read against. This is the golden that lets the rest of the change be trusted.
    func testSixStringVoicingStillResolvesAgainstGuitarTuning() {
        XCTAssertEqual(ChordVoicing.cMajor.openMidi, ChordVoicing.openMidi)
        XCTAssertFalse(ChordVoicing.cMajor.isBass)
        // C major, open position: C3 E3 G3 C4 E4 — the notes it has always sounded.
        XCTAssertEqual(ChordVoicing.cMajor.midiNotes.sorted(), [48, 52, 55, 60, 64])
        XCTAssertEqual(ChordVoicing.cMajor.rootPitchClass, 0)
    }

    /// A four-slot shape is a bass shape, and nothing else in the app can produce one by accident:
    /// every voicing written before bass existed has six.
    func testFourStringVoicingResolvesAgainstBassTuning() {
        let openE = ChordVoicing("E", frets: [nil, nil, nil, 0])
        XCTAssertTrue(openE.isBass)
        XCTAssertEqual(openE.openMidi, ChordVoicing.bassOpenMidi)
        XCTAssertEqual(openE.midiNotes, [28])          // E1, not the guitar low E at 40
        XCTAssertEqual(openE.rootPitchClass, 4)
    }

    /// `isValid` gated on `count == 6` before this ADR, which would have made every bass voicing
    /// silently invalid — the one line that turns the feature off if it's missed.
    func testValidityAcceptsBothNecksAndRejectsNeither() {
        XCTAssertTrue(ChordVoicing("C", frets: [0, 1, 0, 2, 3, nil]).isValid)
        XCTAssertTrue(ChordVoicing("C5", frets: [nil, 5, 3, nil]).isValid)
        XCTAssertFalse(ChordVoicing("odd", frets: [0, 1, 2, 3, 4]).isValid, "5 strings is neither neck")
        XCTAssertFalse(ChordVoicing("silent", frets: [nil, nil, nil, nil]).isValid, "nothing sounds")
        XCTAssertFalse(ChordVoicing("negative", frets: [-1, 0, 0, 0]).isValid)
    }

    /// Note and degree labels follow the same derived tuning — this is what made an open low E read
    /// as "D" on the fretboard board before ADR 0116 S5, and the chord layer had the same shape of bug
    /// waiting in it.
    func testLabelsReadInTheVoicingsOwnTuning() {
        let cFifth = BassChordShape.fifth.voicing(rootString: 3, rootFret: 8)
        XCTAssertEqual(cFifth?.noteLabels(), [nil, nil, "G", "C"])
        XCTAssertEqual(cFifth?.degreeLabels, [nil, nil, "5", "R"])
    }

    // MARK: - Generation

    /// The property that matters: at **every** root on **every** string, a generated shape spells
    /// exactly the intervals it declares. Nothing else in this file would catch a shape whose string
    /// offsets and intervals disagree.
    func testEveryShapeSpellsItsDeclaredIntervalsAtEveryRoot() {
        for shape in BassChordShape.all {
            for rootString in 0..<ChordVoicing.bassStringCount {
                for rootFret in 0...BassChordShape.maxFret {
                    guard let voicing = shape.voicing(rootString: rootString, rootFret: rootFret) else {
                        continue
                    }
                    let root = ChordVoicing.bassOpenMidi[rootString] + rootFret
                    let expected = shape.intervals.map { root + $0 }.sorted()
                    XCTAssertEqual(voicing.midiNotes.sorted(), expected,
                                   "\(shape.name) at string \(rootString) fret \(rootFret)")
                }
            }
        }
    }

    /// A shape that doesn't fit produces **nothing**, never a clamped shape that quietly spells
    /// different intervals. Both directions: off the top of the neck, and off the end of the strings.
    func testShapeRefusesRatherThanClamps() {
        // The octave needs two strings above the root; rooted on the G string there are none.
        XCTAssertNil(BassChordShape.octave.voicing(rootString: 0, rootFret: 3))
        XCTAssertNil(BassChordShape.octave.voicing(rootString: 1, rootFret: 3))
        // High on the neck the upper note runs past the last fret.
        XCTAssertNil(BassChordShape.majorTenth.voicing(rootString: 3, rootFret: BassChordShape.maxFret))
        // And a shape that does fit is not accidentally refused.
        XCTAssertNotNil(BassChordShape.majorTenth.voicing(rootString: 3, rootFret: 3))
    }

    /// Every generated voicing must be playable as encoded — right neck, no negative frets, something
    /// sounding — or it would be rejected downstream after being offered to the player.
    func testEveryGeneratedVoicingIsValidAndFourStringed() {
        for shape in BassChordShape.all {
            for voicing in shape.voicings() {
                XCTAssertTrue(voicing.isValid, "\(voicing.name) from \(shape.name)")
                XCTAssertEqual(voicing.frets.count, ChordVoicing.bassStringCount)
                XCTAssertTrue(voicing.isBass)
            }
        }
    }

    /// The names players read: the suffix rides on the root, and the octave is the root alone because
    /// that is genuinely all it sounds.
    func testNamingFollowsTheRoot() {
        XCTAssertEqual(BassChordShape.fifth.voicing(rootString: 3, rootFret: 3)?.name, "G5")
        XCTAssertEqual(BassChordShape.octave.voicing(rootString: 3, rootFret: 3)?.name, "G")
        XCTAssertEqual(BassChordShape.minorTenth.voicing(rootString: 3, rootFret: 5)?.name, "Am10")
        XCTAssertEqual(BassChordShape.seventhTenthShell.voicing(rootString: 3, rootFret: 5)?.name, "A7")
    }

    /// Picking by root pitch class lands on a real voicing of that root — the door the picker uses
    /// when the player chooses "C" rather than a fret.
    func testVoicingByRootPitchClassFindsTheLowestPosition() {
        for pitchClass in 0..<12 {
            let voicing = BassChordShape.fifth.voicing(rootPitchClass: pitchClass)
            XCTAssertNotNil(voicing, "no root-\(pitchClass) power dyad")
            XCTAssertEqual(voicing?.rootPitchClass, pitchClass)
        }
    }

    /// The quality readers `ChordNamer` and the Roman-numeral badges rely on must agree with the
    /// shapes: a minor tenth is minor-quality, a major tenth is not.
    func testTenthsCarryTheirQuality() {
        let minor = BassChordShape.minorTenth.voicing(rootString: 3, rootFret: 5)
        let major = BassChordShape.majorTenth.voicing(rootString: 3, rootFret: 5)
        XCTAssertEqual(minor?.isMinorQuality, true)
        XCTAssertEqual(major?.isMinorQuality, false)
    }
}
