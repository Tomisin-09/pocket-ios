import XCTest
@testable import Pocket

/// What a touch on the neck does (ADR 0235 D9), pinned as Name the notes did it before the rules moved out
/// of the sheet: placing moves on and the marks stay behind (0234 D3), Chords and the last note stay put,
/// the marks go on the marked note, and *Into it* joins, starts inside, or waits (0227 D5, 0230).
final class NeckEditingTests: XCTestCase {

    private func note(_ string: Int, _ fret: Int, bend: Int = 0, leadIn: LeadIn? = nil) -> FrettedNote {
        FrettedNote(string: string, fret: fret, bend: bend, leadIn: leadIn)
    }

    private func fretted(_ string: Int, _ fret: Int, into join: Join? = nil) -> PieceLabel {
        .fretted([note(string, fret)], into: join)
    }

    // MARK: - Placing

    func testPlacingANoteMovesOnAndLeavesTheMarksOnIt() {
        let edit = NeckEditing.place(string: 2, fret: 5, labels: [nil, nil, nil], cursor: NeckCursor(active: 0))
        XCTAssertEqual(edit.labels, [fretted(2, 5), nil, nil])
        XCTAssertEqual(edit.cursor.active, 1, "on to the next note")
        XCTAssertEqual(edit.cursor.placedNote, 0, "the marks stay on the note just placed")
        XCTAssertEqual(edit.cursor.ringed, 2)
        XCTAssertEqual(edit.cursor.marked(count: 3), 0)
    }

    func testTheLastNoteStaysWithItsOwnMarks() {
        let edit = NeckEditing.place(string: 1, fret: 3, labels: [fretted(2, 5), nil], cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.cursor.active, 1, "nowhere to go")
        XCTAssertNil(edit.cursor.placedNote)
    }

    func testWithChordsOnATapAddsAStringAndStays() {
        let cursor = NeckCursor(active: 0, ringed: 2, chordsOn: true)
        let edit = NeckEditing.place(string: 1, fret: 5, labels: [fretted(2, 5), nil], cursor: cursor)
        XCTAssertEqual(edit.labels[0]?.frettedNotes.map(\.string).sorted(), [1, 2], "one note per string")
        XCTAssertEqual(edit.cursor.active, 0, "a shape takes several taps")
        XCTAssertNil(edit.cursor.placedNote)
    }

    func testAPlacedNoteReplacesAnotherAndKeepsItsMarks() {
        let bent = PieceLabel.fretted([note(2, 5, bend: 2)], into: nil)
        let edit = NeckEditing.place(string: 2, fret: 7, labels: [bent, nil], cursor: NeckCursor(active: 0, ringed: 2))
        XCTAssertEqual(edit.labels[0]?.frettedNotes.first?.fret, 7)
        XCTAssertEqual(edit.labels[0]?.frettedNotes.first?.bend, 2, "the note keeps its bend")
    }

    func testANameByEarGivesWayToTheNeck() {
        let edit = NeckEditing.place(string: 2, fret: 5, labels: [.pitchClass(9), nil], cursor: NeckCursor(active: 0))
        XCTAssertEqual(edit.labels[0], fretted(2, 5))
        XCTAssertEqual(edit.cursor.active, 1)
    }

    func testNothingToPlaceOnIsNoChange() {
        let cursor = NeckCursor(active: 0)
        XCTAssertEqual(NeckEditing.place(string: 2, fret: 5, labels: [], cursor: cursor),
                       NeckEditing.Edit(labels: [], cursor: cursor))
    }

    // MARK: - Marks

    func testMarksGoOnTheNoteJustPlacedNotTheOneTheStripMovedTo() {
        let labels: [PieceLabel?] = [fretted(2, 5), fretted(2, 7)]
        let cursor = NeckCursor(active: 1, placedNote: 0, ringed: 2)
        XCTAssertEqual(NeckEditing.ringedNote(labels: labels, cursor: cursor), note(2, 5))
        let bent = NeckEditing.mark({ $0.bend = 1 }, labels: labels, cursor: cursor)
        XCTAssertEqual(bent[0]?.frettedNotes.first?.bend, 1)
        XCTAssertEqual(bent[1], labels[1], "the note the strip is on is untouched")
    }

    func testInAShapeTheRingedNoteTakesTheMark() {
        let shape = PieceLabel.fretted([note(1, 5), note(2, 5)], into: nil)
        let marked = NeckEditing.mark({ $0.vibrato = true }, labels: [shape], cursor: NeckCursor(active: 0, ringed: 1))
        XCTAssertEqual(marked[0]?.frettedNotes.map(\.vibrato), [true, false])
    }

    func testAPlacedNoteOutOfRangeFallsBackToTheActiveOne() {
        XCTAssertEqual(NeckCursor(active: 1, placedNote: 9).marked(count: 3), 1)
        XCTAssertEqual(NeckCursor(active: 1, placedNote: nil).marked(count: 3), 1)
    }

    func testNoMarkOnANoteNotOnTheNeck() {
        let labels: [PieceLabel?] = [.pitchClass(4), nil]
        XCTAssertEqual(NeckEditing.mark({ $0.bend = 2 }, labels: labels, cursor: NeckCursor(active: 0)), labels)
        XCTAssertNil(NeckEditing.ringedNote(labels: labels, cursor: NeckCursor(active: 0)))
    }

    // MARK: - Into it

    func testAHammerOnJoinsFromTheNoteBeforeWhenItFits() {
        let labels: [PieceLabel?] = [fretted(2, 5), fretted(2, 7)]
        let edit = NeckEditing.choose(.hammerOn, labels: labels, cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.labels[1], fretted(2, 7, into: .legato))
        XCTAssertNil(edit.cursor.awaitingStart)
    }

    func testAHammerOnThatDoesntFitWaitsForWhereItStarted() {
        let labels: [PieceLabel?] = [fretted(0, 5), fretted(2, 7)]
        let edit = NeckEditing.choose(.hammerOn, labels: labels, cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.labels, labels, "nothing changes until the neck says where")
        XCTAssertEqual(edit.cursor.awaitingStart, LeadInRequest(join: .legato, direction: .upward))
    }

    func testChoosingWhatItAlreadyHoldsChangesNothing() {
        let labels: [PieceLabel?] = [fretted(2, 5), fretted(2, 7, into: .legato)]
        let edit = NeckEditing.choose(.hammerOn, labels: labels, cursor: NeckCursor(active: 1))
        XCTAssertEqual(edit.labels, labels)
        XCTAssertNil(edit.cursor.awaitingStart)
    }

    func testPickedTakesTheJoinAndAnyLeadInOff() {
        let leadIn = LeadIn(from: .fret(5), join: .legato)
        let labels: [PieceLabel?] = [.fretted([note(2, 7, leadIn: leadIn)], into: nil)]
        let edit = NeckEditing.choose(.picked, labels: labels, cursor: NeckCursor(active: 0))
        XCTAssertEqual(edit.labels[0], fretted(2, 7))
        XCTAssertEqual(NeckEditing.setInto(.slide, at: 0, of: labels)[0], fretted(2, 7, into: .slide),
                       "a join from before and a lead-in are never both")
    }

    func testTheStartIsTakenFromTheNeck() {
        let request = LeadInRequest(join: .legato, direction: .upward)
        let labels: [PieceLabel?] = [fretted(2, 7)]
        let cursor = NeckCursor(active: 0, awaitingStart: request)

        let started = NeckEditing.place(string: 2, fret: 5, labels: labels, cursor: cursor)
        XCTAssertEqual(started.labels[0], .fretted([note(2, 7, leadIn: LeadIn(from: .fret(5), join: .legato))],
                                                   into: nil))
        XCTAssertNil(started.cursor.awaitingStart)
        XCTAssertEqual(started.cursor.active, 0, "a tap that says where a note started never moves on")

        let above = NeckEditing.place(string: 2, fret: 9, labels: labels, cursor: cursor)
        XCTAssertEqual(above.labels, labels, "a hammer-on can't start above")
        XCTAssertEqual(above.cursor.awaitingStart, request, "and it keeps waiting")

        let own = NeckEditing.place(string: 2, fret: 7, labels: labels, cursor: cursor)
        XCTAssertEqual(own.labels, labels)
        XCTAssertNil(own.cursor.awaitingStart, "a tap on the note itself gives up")
    }

    func testASlideCanComeInFromNowhere() {
        let cursor = NeckCursor(active: 0, awaitingStart: LeadInRequest(join: .slide, direction: nil))
        let edit = NeckEditing.slideIn(from: .below, labels: [fretted(2, 7, into: .slide)], cursor: cursor)
        XCTAssertEqual(edit.labels[0], .fretted([note(2, 7, leadIn: LeadIn(from: .below, join: .slide))], into: nil))
        XCTAssertNil(edit.cursor.awaitingStart)
    }

    // MARK: - One note in a chord (ADR 0252)

    /// The Dmaj7 from the A string: A5 D7 G6 B7 e5.
    private let dmaj7 = PieceLabel.fretted([FrettedNote(string: 4, fret: 5), FrettedNote(string: 3, fret: 7),
                                            FrettedNote(string: 2, fret: 6), FrettedNote(string: 1, fret: 7),
                                            FrettedNote(string: 0, fret: 5)], into: nil)

    func testAChordsHammerOnIsOneTapAndMovesOneNote() throws {
        let cursor = NeckCursor(active: 0, ringed: 1, chordsOn: true)
        let asked = NeckEditing.choose(.hammerOn, labels: [dmaj7, nil], cursor: cursor)
        XCTAssertEqual(asked.cursor.awaitingStart, LeadInRequest(join: .legato, direction: .upward))
        let done = NeckEditing.place(string: 1, fret: 5, labels: asked.labels, cursor: asked.cursor)
        let notes = try XCTUnwrap(done.labels[0]?.frettedNotes)
        XCTAssertEqual(notes.filter { $0.leadIn != nil }, [note(1, 7, leadIn: LeadIn(from: .fret(5), join: .legato))])
        XCTAssertNil(done.cursor.awaitingStart, "one tap, and it's done")
        XCTAssertEqual(done.cursor.active, 0)
    }

    func testASlideAndMovedIntoPlaceAsOneMoveTheWholeShape() throws {
        let slide = NeckEditing.choose(.slide, labels: [dmaj7],
                                       cursor: NeckCursor(active: 0, ringed: 1, chordsOn: true))
        let slid = try XCTUnwrap(NeckEditing.place(string: 1, fret: 6, labels: [dmaj7], cursor: slide.cursor)
            .labels[0]?.frettedNotes)
        XCTAssertEqual(slid.map(\.leadIn), dmaj7.frettedNotes.map { LeadIn(from: .fret($0.fret - 1), join: .slide) })

        let asOne = NeckCursor(active: 0, chordsOn: true,
                               awaitingStart: LeadInRequest(join: .legato, direction: .upward, together: true))
        let moved = try XCTUnwrap(NeckEditing.place(string: 1, fret: 5, labels: [dmaj7], cursor: asOne)
            .labels[0]?.frettedNotes)
        XCTAssertEqual(moved.map(\.leadIn), dmaj7.frettedNotes.map { LeadIn(from: .fret($0.fret - 2), join: .legato) })
    }

    func testTheWholeChordMovedMovesThemAllOrNothing() throws {
        let hammered = NeckEditing.place(string: 1, fret: 5, labels: [dmaj7], cursor: NeckCursor(
            active: 0, chordsOn: true, awaitingStart: LeadInRequest(join: .legato, direction: .upward))).labels
        let all = NeckEditing.moveTogether(labels: hammered, cursor: NeckCursor(active: 0, chordsOn: true))
        XCTAssertEqual(try XCTUnwrap(all.labels[0]?.frettedNotes).map(\.leadIn),
                       dmaj7.frettedNotes.map { LeadIn(from: .fret($0.fret - 2), join: .legato) })

        let low: [PieceLabel?] = [.fretted([note(2, 1), note(1, 3, leadIn: LeadIn(from: .fret(1), join: .legato))],
                                           into: nil)]
        let refused = NeckEditing.moveTogether(labels: low, cursor: NeckCursor(active: 0, chordsOn: true))
        XCTAssertEqual(refused.labels, low, "the G would start off the neck")
    }

    func testWaitingForAStartOnANoteNotOnTheNeckGivesUp() {
        let cursor = NeckCursor(active: 0, awaitingStart: LeadInRequest(join: .slide, direction: nil))
        let edit = NeckEditing.takeStart(string: 2, fret: 5, for: LeadInRequest(join: .slide, direction: nil),
                                         labels: [nil], cursor: cursor)
        XCTAssertNil(edit.cursor.awaitingStart)
    }
}
