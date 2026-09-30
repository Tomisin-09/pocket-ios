import XCTest
@testable import Pocket

/// A written tab's notes, and the bar lines and sections between them (ADR 0235 D4): stored against note
/// positions, kept to their rules by `normalised`, and moved along when a note goes in or comes out.
final class TabContentTests: XCTestCase {

    private func note(_ fret: Int, into join: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: 2, fret: fret)], into: join)
    }

    private func notes(_ count: Int) -> [PieceLabel?] { (0..<count).map { note(3 + $0 % 5) } }

    // MARK: - The rules

    func testBarsAreSortedOnceEachAndNeverAtTheStartOrPastTheEnd() {
        let content = TabContent(labels: notes(6), bars: [4, 0, 2, 4, 7, 6])
        XCTAssertEqual(content.bars, [2, 4, 6], "6 is before the next note written, so it stays")
    }

    func testASectionIsItsOwnBarLine() {
        let content = TabContent(labels: notes(8), bars: [4, 6], sections: [TabSection(start: 4, name: "Verse")])
        XCTAssertEqual(content.bars, [6], "no bar line where a section starts: the heading is the bar")
    }

    func testSectionNamesAreTrimmedAndEmptyOnesGo() {
        let content = TabContent(labels: notes(8), sections: [TabSection(start: 0, name: "  Intro "),
                                                              TabSection(start: 4, name: "   ")])
        XCTAssertEqual(content.sections, [TabSection(start: 0, name: "Intro")])
    }

    func testTwoSectionsOnOneNoteKeepTheLater() {
        let content = TabContent(labels: notes(8), sections: [TabSection(start: 4, name: "Verse"),
                                                              TabSection(start: 4, name: "Chorus")])
        XCTAssertEqual(content.sections, [TabSection(start: 4, name: "Chorus")])
    }

    func testASectionCanWaitForTheNextNoteButNoFurther() {
        let content = TabContent(labels: notes(4), sections: [TabSection(start: 4, name: "Outro"),
                                                              TabSection(start: 9, name: "Coda")])
        XCTAssertEqual(content.sections, [TabSection(start: 4, name: "Outro")])
        XCTAssertNil(content.section(of: 3), "no heading over the notes before it")
    }

    func testAJoinThatNoLongerFitsIsDropped() {
        let content = TabContent(labels: [note(5), .fretted([FrettedNote(string: 0, fret: 7)], into: .legato)])
        XCTAssertEqual(content.labels[1], .fretted([FrettedNote(string: 0, fret: 7)], into: nil))
    }

    // MARK: - A note in, a note out

    func testANoteInJoinsTheBarAndSectionOfTheNoteItWentBefore() {
        let content = TabContent(labels: notes(8), bars: [2, 6], sections: [TabSection(start: 4, name: "Verse")])
        let inserted = content.inserting(note(9), at: 4)
        XCTAssertEqual(inserted.count, 9)
        XCTAssertEqual(inserted.labels[4], note(9))
        XCTAssertEqual(inserted.sections, [TabSection(start: 4, name: "Verse")], "it heads the Verse now")
        XCTAssertEqual(inserted.bars, [2, 7], "the bar after it moves along one")
    }

    func testANoteInDropsTheJoinOfTheNoteAfterIt() {
        let content = TabContent(labels: [note(5), note(7, into: .legato)])
        let inserted = content.inserting(note(9), at: 1)
        XCTAssertEqual(inserted.labels[2], note(7), "it follows a different note now")
    }

    func testANoteOutMovesEverythingAfterItBack() {
        let content = TabContent(labels: notes(8), bars: [2, 6], sections: [TabSection(start: 4, name: "Verse")])
        let removed = content.removing(at: 1)
        XCTAssertEqual(removed.count, 7)
        XCTAssertEqual(removed.bars, [1, 5])
        XCTAssertEqual(removed.sections, [TabSection(start: 3, name: "Verse")])
    }

    func testTakingOutASectionsFirstNoteMovesItsHeadingOn() {
        let content = TabContent(labels: notes(8), sections: [TabSection(start: 4, name: "Verse")])
        XCTAssertEqual(content.removing(at: 4).sections, [TabSection(start: 4, name: "Verse")])
    }

    func testASectionThatLosesItsOnlyNoteGoes() {
        let content = TabContent(labels: notes(8), sections: [TabSection(start: 0, name: "Intro"),
                                                              TabSection(start: 4, name: "Verse"),
                                                              TabSection(start: 5, name: "Chorus")])
        XCTAssertEqual(content.removing(at: 4).sections, [TabSection(start: 0, name: "Intro"),
                                                          TabSection(start: 4, name: "Chorus")])
    }

    func testTheLastSectionWaitsForTheNextNoteInstead() {
        let content = TabContent(labels: notes(8), sections: [TabSection(start: 0, name: "Intro"),
                                                              TabSection(start: 7, name: "Outro")])
        XCTAssertEqual(content.removing(at: 7).sections, [TabSection(start: 0, name: "Intro"),
                                                          TabSection(start: 7, name: "Outro")])
    }

    func testANoteOutDropsTheJoinOfTheNoteAfterIt() {
        let content = TabContent(labels: [note(3), note(5), note(7, into: .legato)])
        XCTAssertEqual(content.removing(at: 1).labels, [note(3), note(7)])
    }

    // MARK: - Bar lines and headings

    func testABarLineGoesInAndComesOut() {
        let content = TabContent(labels: notes(6))
        let barred = content.togglingBar(at: 3)
        XCTAssertEqual(barred.bars, [3])
        XCTAssertEqual(barred.togglingBar(at: 3).bars, [])
        XCTAssertEqual(content.togglingBar(at: 6).bars, [6], "before the next note written")
    }

    func testNoBarLineBeforeTheFirstNoteOrWhereASectionStarts() {
        let content = TabContent(labels: notes(6), sections: [TabSection(start: 3, name: "Verse")])
        XCTAssertEqual(content.togglingBar(at: 0), content)
        XCTAssertEqual(content.togglingBar(at: 3), content)
        XCTAssertEqual(content.togglingBar(at: 7), content, "nowhere past the next note")
    }

    func testASectionStartsRenamesAndComesOffKeepingItsBar() {
        let content = TabContent(labels: notes(8), bars: [4])
        let verse = content.settingSection(at: 4, name: "Verse")
        XCTAssertEqual(verse.sections, [TabSection(start: 4, name: "Verse")])
        XCTAssertEqual(verse.bars, [], "the heading is the bar now")
        XCTAssertEqual(verse.settingSection(at: 4, name: "Chorus").sections, [TabSection(start: 4, name: "Chorus")])
        let off = verse.settingSection(at: 4, name: nil)
        XCTAssertEqual(off.sections, [])
        XCTAssertEqual(off.bars, [4], "taking the heading off keeps its bar line")
        XCTAssertEqual(TabContent(labels: notes(8)).settingSection(at: 0, name: "Intro")
                        .settingSection(at: 0, name: " ").bars, [],
                       "no bar line is left before the first note")
    }

    func testASectionForTheNextNoteWritten() {
        let content = TabContent(labels: notes(4)).settingSection(at: 4, name: "Solo")
        XCTAssertEqual(content.sections, [TabSection(start: 4, name: "Solo")])
        XCTAssertEqual(content.inserting(note(5), at: 4).section(of: 4)?.name, "Solo",
                       "the note written next starts it")
    }
}
