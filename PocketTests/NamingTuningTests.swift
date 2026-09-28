import XCTest
@testable import Pocket

/// A piece's own instrument and tuning (ADR 0227 D3): how it's labelled and recognised, and what a move
/// to another tuning or instrument does to the answers already given.
final class NamingTuningTests: XCTestCase {

    private let placed: [PieceLabel?] = [.fretted(string: 1, fret: 5), nil, .chord(root: 9, suffix: "m"),
                                         .pitchClass(4), .fretted(string: 5, fret: 0)]

    func testACuratedTuningIsHighestFirstAndLabelledLikeTheTuner() {
        let dropD = Instrument.guitar.tuning(named: "Drop D")
        let tuning = NamingTuning(instrument: .guitar, tuning: dropD)
        XCTAssertEqual(tuning.openMidi, [64, 59, 55, 50, 45, 38])
        XCTAssertEqual(tuning.label, "Guitar · Drop D")
        XCTAssertEqual(tuning.tuning, dropD, "and it's recognised again from its strings")
    }

    func testASavedPieceKnowsItsInstrumentFromItsStrings() {
        XCTAssertEqual(NamingTuning(openMidi: [43, 38, 33, 28], label: "Bass · Standard").instrument, .bass)
        XCTAssertEqual(NamingTuning(openMidi: [64, 59, 55, 50, 45, 40], label: "Guitar · Standard").instrument,
                       .guitar)
    }

    func testStringsThatMatchNoCuratedTuningHaveNone() {
        XCTAssertNil(NamingTuning(openMidi: [64, 59, 55, 50, 45, 41], label: "Guitar · Odd").tuning)
    }

    func testANewTuningKeepsTheFrets() {
        let standard = NamingTuning(instrument: .guitar, tuning: Instrument.guitar.standardTuning)
        let dadgad = NamingTuning(instrument: .guitar, tuning: Instrument.guitar.tuning(named: "DADGAD"))
        XCTAssertEqual(standard.carrying(placed, to: dadgad), placed)
    }

    func testANewInstrumentClearsTheFretsButNotTheNamesByEar() {
        let guitar = NamingTuning(instrument: .guitar, tuning: Instrument.guitar.standardTuning)
        let bass = NamingTuning(instrument: .bass, tuning: Instrument.bass.standardTuning)
        XCTAssertEqual(guitar.carrying(placed, to: bass),
                       [nil, nil, .chord(root: 9, suffix: "m"), .pitchClass(4), nil])
    }

    func testTheCountOfPlacedNotesIsWhatASwitchWouldClear() {
        XCTAssertEqual(NamingTuning.placed(in: placed), 2)
        XCTAssertEqual(NamingTuning.placed(in: [nil, .pitchClass(1)]), 0)
    }

    func testATuningReadsLowestStringFirst() {
        XCTAssertEqual(NamingInstrumentSheet.stringLetters(Instrument.guitar.tuning(named: "DADGAD")),
                       "D A D G A D")
        XCTAssertEqual(NamingInstrumentSheet.stringLetters(Instrument.bass.standardTuning), "E A D G")
    }
}
