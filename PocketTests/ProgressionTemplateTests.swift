import XCTest
@testable import Pocket

/// The **pieces of an insert** (ADR 0218): a step's numeral and its encoding, the built-in progressions,
/// the hold lengths, the curated pairs, and how the result lands in a drill that already has chords.
final class ProgressionTemplateTests: XCTestCase {

    // MARK: - Steps

    func testNumeralsReadTheWayPlayersSayThem() {
        XCTAssertEqual(ProgressionStep(10).numeral, "♭VII")
        XCTAssertEqual(ProgressionStep(9, .minor).numeral, "vi")
        XCTAssertEqual(ProgressionStep(2, .min7).numeral, "ii7", "the case already says minor")
        XCTAssertEqual(ProgressionStep(7, .dom7).numeral, "V7")
        XCTAssertEqual(ProgressionStep(0, .maj7).numeral, "Imaj7")
        XCTAssertEqual(ProgressionStep(5, .sus4).numeral, "IVsus4")
        XCTAssertEqual(ProgressionStep(0, .fifth).numeral, "I5")
        let loop = [ProgressionStep(0), ProgressionStep(7), ProgressionStep(9, .minor), ProgressionStep(5)]
        XCTAssertEqual(loop.numerals, "I – V – vi – IV")
    }

    func testAStepStaysInsideTheOctaveAndHoldsForAtLeastABar() {
        XCTAssertEqual(ProgressionStep(-1).semitones, 11)
        XCTAssertEqual(ProgressionStep(13).semitones, 1)
        XCTAssertEqual(ProgressionStep(0, bars: 0).bars, 1)
    }

    func testStepsSurviveAnEncodeAndDecode() throws {
        let steps = [ProgressionStep(2, .min7), ProgressionStep(7, .dom9, bars: 2)]
        let decoded = try JSONDecoder().decode([ProgressionStep].self, from: JSONEncoder().encode(steps))
        XCTAssertEqual(decoded, steps)
    }

    /// A progression saved by a newer build must still open: an unknown quality keeps the chord's place
    /// and length and reads as major, and a missing length is one bar.
    func testAnUnknownQualityOrAMissingLengthDoesNotFailTheDecode() throws {
        let json = Data(#"[{"semitones":7,"quality":"dom13","bars":3},{"semitones":5,"quality":"minor"}]"#.utf8)
        let decoded = try JSONDecoder().decode([ProgressionStep].self, from: json)
        XCTAssertEqual(decoded, [ProgressionStep(7, .major, bars: 3), ProgressionStep(5, .minor)])
    }

    // MARK: - Built-in progressions

    func testTheCatalogIsWellFormed() {
        let ids = ProgressionTemplate.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate progression ids")
        XCTAssertTrue(ProgressionTemplate.catalog.allSatisfy { !$0.steps.isEmpty })
        XCTAssertEqual(ProgressionTemplate.catalog.filter(\.hasFixedLengths).map(\.id), ["twelve-bar-blues"])
        XCTAssertEqual(ProgressionTemplate.catalog.filter(\.steps.readsAsMinor).map(\.id), ["descending-minor"],
                       "vi – IV – I – V starts on a minor chord but isn't in a minor key")
    }

    func testARowReadsAsItsNumeralsUnlessItHasATitle() {
        let loop = ProgressionTemplate.catalog.first { $0.id == "one-five-six-four" }
        XCTAssertEqual(loop?.displayTitle, "I – V – vi – IV")
        let blues = ProgressionTemplate.catalog.first { $0.id == "twelve-bar-blues" }
        XCTAssertEqual(blues?.displayTitle, "12-bar blues")
        XCTAssertEqual(blues?.steps.reduce(0) { $0 + $1.bars }, 12, "the blues is twelve bars")
    }

    // MARK: - Hold

    func testAHoldIsMeasuredInTheDrillsOwnBar() {
        XCTAssertEqual(ProgressionHold.bar.beats(forBars: 1, beatsPerBar: 4), 4)
        XCTAssertEqual(ProgressionHold.bar.beats(forBars: 1, beatsPerBar: 3), 3, "a waltz bar is three beats")
        XCTAssertEqual(ProgressionHold.twoBeats.beats(forBars: 1, beatsPerBar: 3), 2)
        XCTAssertEqual(ProgressionHold.oneBeat.beats(forBars: 1, beatsPerBar: 4), 1)
    }

    func testAShorterHoldKeepsALongChordLonger() {
        XCTAssertEqual(ProgressionHold.twoBeats.beats(forBars: 2, beatsPerBar: 4), 4)
        XCTAssertEqual(ProgressionHold.oneBeat.beats(forBars: 4, beatsPerBar: 4), 4)
        XCTAssertEqual(ProgressionHold.bar.beats(forBars: 0, beatsPerBar: 0), 1, "never a zero-beat chord")
    }

    // MARK: - Pairs (D8)

    func testPairsAreExactShapes() {
        let ids = ChordPair.curated.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate pair ids")
        let amE = ChordPair.curated.first { $0.id == "am-e" }
        XCTAssertEqual(amE?.first, .aMinor)
        XCTAssertEqual(amE?.second, .eMajor)
        XCTAssertEqual(amE?.title, "Am ↔ E")
        XCTAssertTrue(ChordPair.curated.allSatisfy { !$0.first.isBass && !$0.second.isBass },
                      "pairs are guitar shapes")
    }

    // MARK: - Landing in a drill (D9)

    func testAddAfterKeepsTheChordsAndTheKey() {
        let inserted = ChordProgression.gMajorPop.inserting([ChordChange(.aMinor, beats: 2)], mode: .append)
        XCTAssertEqual(inserted.changes.map(\.voicing.name), ["G", "D", "Em", "C", "Am"])
        XCTAssertEqual(inserted.keyRoot, ChordProgression.gMajorPop.keyRoot)
    }

    func testReplaceSwapsEveryChord() {
        let inserted = ChordProgression.gMajorPop.inserting([ChordChange(.aMinor), ChordChange(.eMajor)],
                                                           mode: .replace)
        XCTAssertEqual(inserted.changes.map(\.voicing.name), ["Am", "E"])
    }

    func testAnEmptyDrillIsTheSameEitherWay() {
        let chords = [ChordChange(.cMajor), ChordChange(.gMajor)]
        XCTAssertEqual(ChordProgression.empty.inserting(chords, mode: .append),
                       ChordProgression.empty.inserting(chords, mode: .replace))
    }
}
