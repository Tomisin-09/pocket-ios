import XCTest
@testable import Pocket

/// A tab being written (ADR 0235 D3, D4): the one open slot, a +, where a tap on the neck writes a new note;
/// a picked note the neck changes instead; *Insert before* and *Take note N out*; bar lines and sections at
/// the lit chip; and what the shared neck editor sees.
final class TabDraftTests: XCTestCase {

    private func note(_ string: Int, _ fret: Int, into join: Join? = nil) -> PieceLabel {
        .fretted([FrettedNote(string: string, fret: fret)], into: join)
    }

    private func draft(_ count: Int, bars: [Int] = [], sections: [TabSection] = []) -> TabDraft {
        TabDraft(content: TabContent(labels: (0..<count).map { note(2, 3 + $0) }, bars: bars, sections: sections))
    }

    // MARK: - Opening

    func testItOpensAtTheEndWithTheMarksOnTheLastNote() {
        let opened = draft(4)
        XCTAssertEqual(opened.slot, 4)
        XCTAssertNil(opened.selected)
        XCTAssertEqual(opened.marked, 3)
        XCTAssertEqual(opened.position, 4, "Bar line and Section act before the next note written")
    }

    func testANewTabOpensOnTheFirstNote() {
        let empty = TabDraft(content: TabContent())
        XCTAssertEqual(empty.slot, 0)
        XCTAssertNil(empty.marked)
        XCTAssertEqual(empty.editorLabels, [nil], "the editor sees the + as an empty note")
        XCTAssertEqual(empty.cursor.active, 0)
    }

    // MARK: - Writing at the +

    func testATapOnTheNeckWritesANoteAndTheMovesOn() {
        var writing = draft(2)
        writing.place(string: 1, fret: 8)
        XCTAssertEqual(writing.content.labels, [note(2, 3), note(2, 4), note(1, 8)])
        XCTAssertEqual(writing.slot, 3, "the + moves on past it")
        XCTAssertNil(writing.selected)
        XCTAssertEqual(writing.marked, 2, "the marks go on it")
        XCTAssertEqual(writing.cursor, NeckCursor(active: 3, placedNote: 2, ringed: 1))
        XCTAssertEqual(writing.editorLabels, [note(2, 3), note(2, 4), note(1, 8), nil])
    }

    func testWithChordsOnTheStripStaysOnTheNewNote() {
        var writing = draft(1)
        writing.chordsOn = true
        writing.place(string: 1, fret: 5)
        XCTAssertEqual(writing.selected, 1, "a shape takes several taps")
        writing.place(string: 2, fret: 5)
        XCTAssertEqual(writing.count, 2, "the second tap adds to the shape, not a new note")
        XCTAssertEqual(writing.content.labels[1]?.frettedNotes.map(\.string).sorted(), [1, 2])
    }

    func testInsertBeforeOpensTheHereAndEachTapAddsOneMore() {
        var writing = draft(4, bars: [2])
        writing.insertBefore(1)
        XCTAssertEqual(writing.slot, 1)
        XCTAssertEqual(writing.editorLabels[1], nil)
        writing.place(string: 0, fret: 1)
        writing.place(string: 0, fret: 2)
        XCTAssertEqual(writing.content.labels.prefix(4), [note(2, 3), note(0, 1), note(0, 2), note(2, 4)])
        XCTAssertEqual(writing.slot, 3)
        XCTAssertEqual(writing.content.bars, [4], "the bar line moves along with its note")
    }

    func testTheHereInFrontOfANoteLightsWhereItIs() {
        var writing = draft(4)
        writing.insertBefore(2)
        writing.chordsOn = true
        writing.place(string: 1, fret: 5)
        XCTAssertEqual(writing.selected, 2, "Chords keeps the strip on the shape")
        writing.lightSlot()
        XCTAssertNil(writing.selected)
        XCTAssertEqual(writing.slot, 3, "still in front of the note it was before")
    }

    // MARK: - Picking a note

    func testPickingANoteSendsTheHereBackToTheEnd() {
        var writing = draft(5)
        writing.insertBefore(2)
        writing.pick(3)
        XCTAssertEqual(writing.slot, 5)
        XCTAssertEqual(writing.selected, 3)
        XCTAssertEqual(writing.position, 3)
        XCTAssertEqual(writing.cursor.active, 3)
    }

    func testATapChangesThePickedNoteAndMovesOn() {
        var writing = draft(4)
        writing.pick(1)
        writing.place(string: 0, fret: 12)
        XCTAssertEqual(writing.content.labels[1], note(0, 12))
        XCTAssertEqual(writing.count, 4, "a change, not a new note")
        XCTAssertEqual(writing.selected, 2)
        XCTAssertEqual(writing.marked, 1)
    }

    func testChangingTheLastNoteMovesOnToTheHere() {
        var writing = draft(3)
        writing.pick(2)
        writing.place(string: 0, fret: 12)
        XCTAssertNil(writing.selected, "the + is lit again")
        XCTAssertEqual(writing.slot, 3)
    }

    func testPickEndLightsTheHereWithTheMarksOnTheLastNote() {
        var writing = draft(3)
        writing.pick(0)
        writing.pickEnd()
        XCTAssertNil(writing.selected)
        XCTAssertEqual(writing.marked, 2)
    }

    // MARK: - Taking a note out

    func testTakingANoteOutStaysOnTheNoteThatTakesItsPlace() {
        var writing = TabDraft(content: TabContent(labels: [note(2, 3), note(2, 5), note(2, 7, into: .legato)]))
        writing.takeOut(1)
        XCTAssertEqual(writing.content.labels, [note(2, 3), note(2, 7)], "the note after drops its join")
        XCTAssertEqual(writing.selected, 1)
        writing.takeOut(1)
        XCTAssertNil(writing.selected, "the last one out lights the +")
        XCTAssertEqual(writing.slot, 1)
    }

    // MARK: - Bar lines and sections at the lit chip

    func testBarLineAndSectionActAtTheLitChip() {
        var writing = draft(4)
        writing.toggleBar()
        XCTAssertEqual(writing.content.bars, [4], "before the next note written")
        writing.pick(2)
        writing.setSection("Verse")
        XCTAssertEqual(writing.content.sections, [TabSection(start: 2, name: "Verse")])
        writing.setSection(nil)
        XCTAssertEqual(writing.content.bars, [2, 4], "the heading comes off and leaves its bar line")
    }

    func testNoBarLineBeforeTheFirstNote() {
        var writing = draft(3)
        writing.pick(0)
        writing.toggleBar()
        XCTAssertEqual(writing.content.bars, [])
    }

    // MARK: - The shared editor

    func testTheEditorsMarksComeBackWithoutTheHere() {
        var writing = draft(2)
        writing.place(string: 1, fret: 8)
        let bent = NeckEditing.mark({ $0.bend = 2 }, labels: writing.editorLabels, cursor: writing.cursor)
        writing.write(editorLabels: bent)
        XCTAssertEqual(writing.count, 3)
        XCTAssertEqual(writing.content.labels[2]?.frettedNotes.first?.bend, 2, "on the note just written")
    }

    func testIntoItWaitsForTheStartAndTheNextTapSaysIt() {
        var writing = TabDraft(content: TabContent(labels: [note(0, 3), note(2, 7)]))
        writing.pick(1)
        let waiting = NeckEditing.choose(.hammerOn, labels: writing.editorLabels, cursor: writing.cursor)
        writing.adopt(waiting.cursor)
        XCTAssertNotNil(writing.awaitingStart)
        writing.place(string: 2, fret: 5)
        XCTAssertEqual(writing.count, 2, "the tap said where the note started, it wrote nothing new")
        XCTAssertEqual(writing.content.labels[1]?.frettedNotes.first?.leadIn, LeadIn(from: .fret(5), join: .legato))
        XCTAssertNil(writing.awaitingStart)
    }

    func testANewInstrumentKeepsTheTabsShape() {
        var writing = draft(4, bars: [2], sections: [TabSection(start: 0, name: "Intro")])
        writing.retune([nil, nil, nil, nil])
        XCTAssertEqual(writing.count, 4)
        XCTAssertEqual(writing.content.bars, [2])
        XCTAssertEqual(writing.content.sections, [TabSection(start: 0, name: "Intro")])
        writing.retune([nil])
        XCTAssertEqual(writing.count, 4, "the wrong number of notes is refused")
    }

    // MARK: - Undo

    func testUndoLandsOnTheNoteThatChanged() throws {
        var writing = draft(4)
        var history = EditHistory<TabStep>()
        let before = writing.step
        writing.pick(1)
        writing.place(string: 0, fret: 12)
        history.record(before, now: writing.step)
        let back = try XCTUnwrap(history.undo(from: writing.step))
        writing.restore(back)
        XCTAssertEqual(writing.content.labels[1], note(2, 4))
        XCTAssertEqual(writing.selected, 1, "on the note it put back")
    }

    func testUndoingABarLineAloneReturnsToTheHere() throws {
        var writing = draft(4)
        var history = EditHistory<TabStep>()
        let before = writing.step
        writing.toggleBar()
        history.record(before, now: writing.step)
        writing.restore(try XCTUnwrap(history.undo(from: writing.step)))
        XCTAssertEqual(writing.content.bars, [])
        XCTAssertNil(writing.selected, "back at the + at the end, not on the last note")
    }

    func testANewInstrumentIsAStepEvenWithNoNotesChanged() {
        let before = TabStep(content: TabContent(), active: 0, openMidi: [64, 59, 55, 50, 45, 40],
                             tuningLabel: "Guitar · Standard")
        var after = before
        after.openMidi = [43, 38, 33, 28]
        XCTAssertTrue(before.changes(after), "undo has to bring the strings back")
        after = before
        after.tuningLabel = "Renamed"
        XCTAssertFalse(before.changes(after), "the strings are what count, not what they're called")
    }

    func testMovingAroundIsNoStep() {
        var writing = draft(4)
        var history = EditHistory<TabStep>()
        let before = writing.step
        writing.pick(2)
        history.record(before, now: writing.step)
        XCTAssertFalse(history.canUndo)
    }
}
