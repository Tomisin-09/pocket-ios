import XCTest
@testable import Pocket

/// A written tab laid out for reading (ADR 0235 D5): each section on rows of its own under its heading,
/// whole bars kept on a row while they fit, a bar too long for a row broken at the edge, and bar lines as
/// columns of their own.
final class PieceStaffBarsTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi

    private func tab(_ count: Int, bars: [Int] = [], sections: [TabSection] = []) -> PieceNotes {
        PieceNotes(labels: (0..<count).map { .fretted(string: 2, fret: 5 + $0 % 3) }, openMidi: guitar,
                   tuningLabel: "Guitar · Standard", bars: bars, sections: sections)
    }

    /// The notes on a row, bar lines as `|`.
    private func picture(_ row: PieceStaff.Row) -> String {
        row.columns.map { $0.isBar ? "|" : "\($0.note)" }.joined(separator: " ")
    }

    func testNotesBeforeTheFirstHeadingAreASectionWithoutOne() {
        let ranges = PieceStaff.sectionRanges(of: tab(10, sections: [TabSection(start: 4, name: "Verse")]))
        XCTAssertEqual(ranges.map(\.heading), [nil, "Verse"])
        XCTAssertEqual(ranges.map(\.notes), [0..<4, 4..<10])
    }

    func testAHeadingWaitingForTheNextNoteIsNotDrawn() {
        let ranges = PieceStaff.sectionRanges(of: tab(4, sections: [TabSection(start: 0, name: "Intro"),
                                                                     TabSection(start: 4, name: "Outro")]))
        XCTAssertEqual(ranges.map(\.heading), ["Intro"])
    }

    func testBarLinesSitBetweenWholeBarsOnARow() {
        let systems = PieceStaff.systems(of: tab(8, bars: [4]), spelling: .sharps, fitting: 80)
        XCTAssertEqual(systems.count, 1)
        XCTAssertEqual(systems[0].rows.map(picture), ["0 1 2 3 | 4 5 6 7"])
        XCTAssertEqual(systems[0].rows[0].notes, 1...8, "a bar line doesn't count as a note")
    }

    func testEachSectionStartsARowOfItsOwn() {
        let notes = tab(8, bars: [2, 6], sections: [TabSection(start: 0, name: "Intro"),
                                                     TabSection(start: 4, name: "Verse")])
        let systems = PieceStaff.systems(of: notes, spelling: .sharps, fitting: 80)
        XCTAssertEqual(systems.map(\.heading), ["Intro", "Verse"])
        XCTAssertEqual(systems.map { $0.rows.map(picture) }, [["0 1 | 2 3"], ["4 5 | 6 7"]],
                       "no bar line opens a section: the heading is the bar")
    }

    /// A column is a character wide plus a gap of two, so 3 each; a bar line is 3 too.
    func testABarThatDoesntFitStartsTheNextRow() {
        let systems = PieceStaff.systems(of: tab(8, bars: [4]), spelling: .sharps, fitting: 20)
        XCTAssertEqual(systems[0].rows.map(picture), ["0 1 2 3", "4 5 6 7"], "whole bars, not split")
    }

    func testABarTooLongForAnyRowBreaksAtTheEdge() {
        let systems = PieceStaff.systems(of: tab(10, bars: [8]), spelling: .sharps, fitting: 12)
        XCTAssertEqual(systems[0].rows.map(picture), ["0 1 2 3", "4 5 6 7", "8 9"])
    }

    func testWhatsLeftOfABrokenBarSharesItsRowWithTheNext() {
        let systems = PieceStaff.systems(of: tab(8, bars: [5]), spelling: .sharps, fitting: 18)
        XCTAssertEqual(systems[0].rows.map(picture), ["0 1 2 3 4", "5 6 7"])
        let wider = PieceStaff.systems(of: tab(9, bars: [7]), spelling: .sharps, fitting: 18)
        XCTAssertEqual(wider[0].rows.map(picture), ["0 1 2 3 4 5", "6 | 7 8"])
    }

    func testAJoinAcrossABarLineIsStillWritten() {
        var notes = tab(4, bars: [2])
        notes.labels[2] = .fretted([FrettedNote(string: 2, fret: 9)], into: .legato)
        let columns = PieceStaff.systems(of: notes, spelling: .sharps, fitting: 80)[0].rows[0].columns
        XCTAssertEqual(columns.filter { !$0.isBar }.map { $0.cells.first?.text }, ["5", "6", "h9", "5"])
    }

    func testBarColumnsHaveIdsOfTheirOwn() {
        let columns = PieceStaff.systems(of: tab(8, bars: [4]), spelling: .sharps, fitting: 80)[0].rows[0].columns
        XCTAssertEqual(Set(columns.map(\.id)).count, columns.count)
    }
}
