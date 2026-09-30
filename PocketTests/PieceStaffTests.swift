import XCTest
@testable import Pocket

/// A piece laid out for reading (ADR 0234 D8): the columns the strings can and can't say, rows that fit
/// the width without splitting a column, the names in fours, and the line over it all.
final class PieceStaffTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func piece(_ labels: [PieceLabel?], fretted: Bool = true) -> PieceTranscription {
        PieceTranscription(taps: labels.enumerated().map { .init(seconds: Double($0.offset), label: $0.element) },
                           openMidi: fretted ? guitar : nil, tuningLabel: fretted ? "Guitar · Standard" : nil)
    }

    private func fret(_ string: Int, _ fret: Int, into join: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: string, fret: fret)], into: join)
    }

    // MARK: - Columns

    func testWhatTheStringsCantSaySitsAboveThem() {
        let columns = PieceStaff.columns(of: piece([fret(2, 5), nil, .pitchClass(9), .chord(root: 9, suffix: "m")]),
                                         spelling: .sharps)
        XCTAssertEqual(columns.map(\.above), [nil, "·", "A", "Am"])
        XCTAssertEqual(columns[0].cells, [PieceStaff.Cell(string: 2, text: "5")])
        XCTAssertEqual(columns.map(\.isQuiet), [false, true, false, false], "only the unnamed is drawn quieter")
        XCTAssertTrue(columns[2].cells.isEmpty, "a name by ear has no fret to write")
    }

    func testFourUnnamedInARowAreACountAndThreeAreDots() {
        let four = PieceStaff.columns(of: piece([fret(2, 5), nil, nil, nil, nil, fret(2, 7)]), spelling: .sharps)
        XCTAssertEqual(four.map(\.above), [nil, "(4)", nil])
        XCTAssertEqual(four.map(\.note), [0, 1, 5], "the note after the run keeps its own number")
        XCTAssertEqual(four[1].span, 4)

        let three = PieceStaff.columns(of: piece([nil, nil, nil, fret(2, 5)]), spelling: .sharps)
        XCTAssertEqual(three.map(\.above), ["·", "·", "·", nil])
        XCTAssertEqual(three.map(\.span), [1, 1, 1, 1])
    }

    func testAJoinIsWrittenInFrontOfItsFret() {
        let columns = PieceStaff.columns(of: piece([fret(2, 5), fret(2, 7, into: .legato), fret(2, 5, into: .legato),
                                                    fret(2, 9, into: .slide)]), spelling: .sharps)
        XCTAssertEqual(columns.flatMap(\.cells).map(\.text), ["5", "h7", "p5", "/9"])
    }

    func testBendsAndVibratoAreTheTabsOwn() {
        let bent = PieceLabel.fretted([FrettedNote(string: 1, fret: 8, bend: 2, vibrato: true)], into: nil)
        XCTAssertEqual(PieceStaff.columns(of: piece([bent]), spelling: .sharps).first?.cells.first?.text, "8b10~")
    }

    func testABigShapeIsNamedAboveAndASmallOneIsNot() {
        let openE = PieceLabel.fretted([(0, 0), (1, 0), (2, 1), (3, 2), (4, 2), (5, 0)]
            .map { FrettedNote(string: $0.0, fret: $0.1) }, into: nil)
        let power = PieceLabel.fretted([FrettedNote(string: 4, fret: 7), FrettedNote(string: 5, fret: 5)], into: nil)
        let columns = PieceStaff.columns(of: piece([openE, power]), spelling: .sharps)
        XCTAssertEqual(columns[0].above, openE.name(openMidi: guitar, spelling: .sharps))
        XCTAssertNotNil(columns[0].above)
        XCTAssertEqual(columns[0].cells.map(\.string), [0, 1, 2, 3, 4, 5], "thinnest string first")
        XCTAssertNil(columns[1].above, "two frets say what they are")
    }

    func testAColumnIsAsWideAsItsWidestCellOrWord() {
        let columns = PieceStaff.columns(of: piece([fret(1, 12), .chord(root: 9, suffix: "m7♭5"), nil]),
                                         spelling: .sharps)
        XCTAssertEqual(columns.map(\.width), [2, 5, 1], "Am7♭5 is five characters")
    }

    // MARK: - Rows

    private func column(_ note: Int, width: Int, span: Int = 1) -> PieceStaff.Column {
        PieceStaff.Column(note: note, span: span, above: String(repeating: "x", count: width), cells: [])
    }

    func testRowsFillToTheWidthAndNeverSplitAColumn() {
        let columns = (0..<5).map { column($0, width: 2) }
        // 2 + (2+2) + (2+2) = 10 fits in 10; a fourth would need 14.
        let rows = PieceStaff.rows(columns, fitting: 10, gap: 2)
        XCTAssertEqual(rows.map { $0.columns.map(\.note) }, [[0, 1, 2], [3, 4]])
        XCTAssertEqual(rows.map(\.notes), [1...3, 4...5])
    }

    func testAColumnTooWideForAnyRowGetsOneOfItsOwn() {
        let rows = PieceStaff.rows([column(0, width: 2), column(1, width: 30), column(2, width: 2)], fitting: 10)
        XCTAssertEqual(rows.map { $0.columns.map(\.note) }, [[0], [1], [2]])
    }

    func testARowCaptionCountsEveryNoteInARun() {
        let rows = PieceStaff.rows([column(0, width: 1), column(1, width: 3, span: 6), column(7, width: 1)],
                                   fitting: 40)
        XCTAssertEqual(rows.first?.notes, 1...8)
    }

    func testNoColumnsIsNoRows() {
        XCTAssertTrue(PieceStaff.rows([], fitting: 10).isEmpty)
    }

    // MARK: - Names in fours

    func testAPieceByEarIsItsNamesInFours() {
        let groups = PieceStaff.groups(of: piece([.pitchClass(0), nil, .pitchClass(4), .pitchClass(7), .pitchClass(9),
                                                  .pitchClass(11)], fretted: false), spelling: .sharps)
        XCTAssertEqual(groups.map { $0.map(\.note) }, [[0, 1, 2, 3], [4, 5]])
        XCTAssertEqual(groups.first?.map(\.name), ["C", nil, "E", "G"])
    }

    // MARK: - The line over it

    func testTheLineSaysTheCountTheTuningAndWhatsLeft() {
        let labels: [PieceLabel?] = [fret(2, 5), nil, fret(2, 7), nil]
        XCTAssertEqual(PieceStaff.meta(of: piece(labels)), "4 notes · Guitar · Standard · 2 unnamed")
        XCTAssertEqual(PieceStaff.meta(of: piece([fret(2, 5)])), "1 note · Guitar · Standard")
    }

    func testAPieceByEarHasNoTuningToSay() {
        let byEar = piece([.pitchClass(0), .pitchClass(4)], fretted: false)
        XCTAssertEqual(PieceStaff.meta(of: byEar), "2 notes")
        var tuned = byEar
        tuned.tuningLabel = "Guitar · Drop D"
        XCTAssertEqual(PieceStaff.meta(of: tuned), "2 notes", "a tuning is only said over frets")
    }

    func testChordsAreCountedAsChordsAndAnUnnamedPieceSaysSo() {
        XCTAssertEqual(PieceStaff.meta(of: piece([.chord(root: 9, suffix: "m"), .chord(root: 2, suffix: "")],
                                                 fretted: false)), "2 chords")
        XCTAssertEqual(PieceStaff.meta(of: piece([nil, nil, nil], fretted: false)), "3 notes · none named yet")
    }
}
