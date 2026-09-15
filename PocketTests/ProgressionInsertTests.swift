import XCTest
@testable import Pocket

/// **What the sheet inserts** (ADR 0218) — the preview's chords with their numerals, lengths, marks and
/// hand swaps. The sheet draws exactly these values, so a wrong chip here is a wrong row in the drill.
final class ProgressionInsertTests: XCTestCase {

    private func template(_ id: String) -> ProgressionTemplate {
        guard let found = ProgressionTemplate.catalog.first(where: { $0.id == id }) else {
            XCTFail("no built-in progression \(id)")
            return ProgressionTemplate(id: id, title: nil, detail: "", steps: [])
        }
        return found
    }

    private func chords(_ id: String, tonic: Int, hold: ProgressionHold = .bar, beatsPerBar: Int = 4,
                        instrument: Instrument = .guitar, mine: [ChordVoicing] = [],
                        swaps: [Int: ChordVoicing] = [:]) -> [ProgressionInsert.Chord] {
        let progression = template(id)
        let placement = ProgressionInsert.Placement(tonic: tonic, hold: hold, beatsPerBar: beatsPerBar,
                                                    instrument: instrument, myChords: mine, preference: .sharps)
        return ProgressionInsert.chords(for: progression.steps, fixedLengths: progression.hasFixedLengths,
                                        placement: placement, swaps: swaps)
    }

    func testTheFourChordLoopInGIsWhatItSays() {
        let loop = chords("one-five-six-four", tonic: 7)
        XCTAssertEqual(loop.map(\.voicing.name), ["G", "D", "Em", "C"])
        XCTAssertEqual(loop.map(\.numeral), ["I", "V", "vi", "IV"])
        XCTAssertEqual(loop.map(\.beats), [4, 4, 4, 4])
        XCTAssertFalse(loop.contains { $0.isYours || $0.isSwapped })
        XCTAssertEqual(loop.map(\.id), [0, 1, 2, 3], "slots are positions — swaps are keyed by them")
    }

    func testTheHoldScalesEveryChord() {
        XCTAssertEqual(chords("one-five-six-four", tonic: 7, hold: .oneBeat).map(\.beats), [1, 1, 1, 1])
        XCTAssertEqual(chords("two-five-one", tonic: 0, hold: .twoBeats).map(\.beats), [2, 2, 4],
                       "the two-bar I stays twice as long as the chords before it")
        XCTAssertEqual(chords("one-four-five", tonic: 0, beatsPerBar: 3).map(\.beats), [3, 3, 3],
                       "one bar of a 3/4 drill is three beats")
    }

    func testTheBluesKeepsItsOwnLengthsWhateverTheHold() {
        let blues = chords("twelve-bar-blues", tonic: 9, hold: .oneBeat)
        XCTAssertEqual(blues.map(\.voicing.name), ["A7", "D7", "A7", "E7", "D7", "A7", "E7"])
        XCTAssertEqual(blues.map(\.beats), [16, 8, 8, 4, 4, 4, 4])
    }

    func testASwapReplacesTheShapeButKeepsItsPlaceAndLength() {
        let swapped = chords("one-five-six-four", tonic: 7, hold: .twoBeats, swaps: [2: .aMinor])
        XCTAssertEqual(swapped.map(\.voicing.name), ["G", "D", "Am", "C"])
        XCTAssertEqual(swapped[2].numeral, "vi", "the slot is still the vi chord")
        XCTAssertEqual(swapped[2].beats, 2)
        XCTAssertEqual(swapped.map(\.isSwapped), [false, false, true, false])
    }

    func testASavedChordThatFitsIsMarkedYours() {
        let cadd9 = ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil])
        let loop = chords("one-five-six-four", tonic: 7, mine: [cadd9])
        XCTAssertEqual(loop.map(\.voicing.name), ["G", "D", "Em", "Cadd9"])
        XCTAssertEqual(loop.map(\.isYours), [false, false, false, true])
    }

    func testABassDrillGetsBassShapesThroughout() {
        XCTAssertTrue(chords("one-five-six-four", tonic: 4, instrument: .bass).allSatisfy(\.voicing.isBass))
    }

    func testAPairIsItsTwoShapesHeldForTheHoldWithNoNumerals() {
        let pair = ProgressionInsert.chords(for: [.aMinor, .eMajor], hold: .twoBeats, beatsPerBar: 4)
        XCTAssertEqual(pair.map(\.voicing), [.aMinor, .eMajor])
        XCTAssertEqual(pair.map(\.beats), [2, 2])
        XCTAssertEqual(pair.map(\.numeral), [nil, nil], "a pair has no key, so no numerals")
        XCTAssertEqual(ProgressionInsert.changes(pair),
                       [ChordChange(.aMinor, beats: 2), ChordChange(.eMajor, beats: 2)])
    }

    func testTheAddButtonCountsWhatItWillAdd() {
        XCTAssertEqual(ProgressionInsert.addLabel(count: 1), "Add 1 chord")
        XCTAssertEqual(ProgressionInsert.addLabel(count: 7), "Add 7 chords")
    }
}
