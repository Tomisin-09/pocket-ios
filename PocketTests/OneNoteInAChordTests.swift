import XCTest
@testable import Pocket

/// **One note moves inside a chord** (ADR 0252 D1, D2): a hammer-on or pull-off in a chord moves the note
/// on the string tapped, and the rest are held. The start is always tapped, never worked out from the
/// barre: the Dmaj7's B is hammered from the barre, but a D shape's minor-to-major B starts a fret above
/// it, and an m7's B sits under the middle finger. *The whole chord moved?* moves them all.
final class OneNoteInAChordTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func note(_ string: Int, _ fret: Int) -> FrettedNote {
        FrettedNote(string: string, fret: fret)
    }

    private func lead(_ string: Int, _ fret: Int, from start: LeadIn.Start, _ join: Join = .legato) -> FrettedNote {
        FrettedNote(string: string, fret: fret, leadIn: LeadIn(from: start, join: join))
    }

    /// The Dmaj7 from Tomisin's screenshot, from the A string: A5 D7 G6 B7 e5.
    private var dmaj7: [FrettedNote] { [note(4, 5), note(3, 7), note(2, 6), note(1, 7), note(0, 5)] }

    /// The same with its B hammered from the barre: `5h7`.
    private var hammered: [FrettedNote] { [note(4, 5), note(3, 7), note(2, 6), lead(1, 7, from: .fret(5)), note(0, 5)] }

    private let hammer = LeadInRequest(join: .legato, direction: .upward)
    private let pull = LeadInRequest(join: .legato, direction: .downward)

    // MARK: - The rule

    func testTheBHammeredFromTheBarreMovesAloneAndTheRestAreHeld() throws {
        XCTAssertEqual(NeckJoin.start(string: 1, fret: 5, of: dmaj7, join: .legato), hammered)
        XCTAssertTrue(NeckJoin.leadInsFit(hammered))
        XCTAssertFalse(NeckJoin.movesAsOne(hammered), "one moves, four are held")
        XCTAssertEqual(NeckJoin.tidied([.fretted(hammered, into: nil)])[0], .fretted(hammered, into: nil), "kept")
        let tab = try XCTUnwrap(TabLine.render([.fretted(hammered, into: nil)], openMidi: guitar))
        XCTAssertEqual(tab, """
        e|-5----|
        B|-5h7--|
        G|-6----|
        D|-7----|
        A|-5----|
        E|------|
        """)
    }

    func testTheMinorToMajorHammerStartsAboveTheBarre() throws {
        // A D shape barred at 5: A5 D7 G7 B7 e5, its B hammered 6→7, minor 3rd to major.
        let shape = [note(4, 5), note(3, 7), note(2, 7), note(1, 7), note(0, 5)]
        let started = try XCTUnwrap(NeckJoin.started(string: 1, fret: 6, of: shape, for: hammer))
        XCTAssertEqual(started[3], lead(1, 7, from: .fret(6)))
        XCTAssertTrue(NeckJoin.leadInsFit(started))
        let tab = try XCTUnwrap(TabLine.render([.fretted(started, into: nil)], openMidi: guitar))
        XCTAssertTrue(tab.contains("B|-6h7--|"), tab)
    }

    func testAnM7sBIsHammeredFromAndPulledOffOntoTheMiddleFingerAsTapped() throws {
        // Dm7 from the A string: A5 D7 G5 B6 e5, the B under the middle finger at 6, the barre at 5.
        let rising = [note(4, 5), note(3, 7), note(2, 5), note(1, 8), note(0, 5)]
        let edit = NeckEditing.place(string: 1, fret: 6, labels: [.fretted(rising, into: nil)],
                                     cursor: NeckCursor(active: 0, ringed: 1, chordsOn: true, awaitingStart: hammer))
        let hammeredOn = try XCTUnwrap(edit.labels[0]?.frettedNotes)
        XCTAssertEqual(hammeredOn[3], lead(1, 8, from: .fret(6)), "from the fret tapped, never the barre")
        XCTAssertEqual(hammeredOn.filter { $0.leadIn != nil }.count, 1)
        XCTAssertTrue(try XCTUnwrap(TabLine.render(edit.labels, openMidi: guitar)).contains("B|-6h8--|"))

        let down = [note(4, 5), note(3, 7), note(2, 5), note(1, 6), note(0, 5)]
        let pulled = try XCTUnwrap(NeckJoin.started(string: 1, fret: 8, of: down, for: pull))
        XCTAssertEqual(pulled[3], lead(1, 6, from: .fret(8)))
        XCTAssertEqual(NeckJoin.tidied([.fretted(pulled, into: nil)])[0], .fretted(pulled, into: nil), "kept")
        XCTAssertTrue(try XCTUnwrap(TabLine.render([.fretted(pulled, into: nil)], openMidi: guitar))
            .contains("B|-8p6--|"))
    }

    func testAStartMovesOnlyTheStringTappedAndOnlyThatNoteHasToFit() {
        XCTAssertTrue(NeckJoin.accepts(string: 1, fret: 5, asStartOf: dmaj7, for: hammer))
        XCTAssertTrue(NeckJoin.accepts(string: 2, fret: 4, asStartOf: dmaj7, for: hammer), "any string of the chord")
        XCTAssertFalse(NeckJoin.accepts(string: 1, fret: 9, asStartOf: dmaj7, for: hammer), "a hammer-on starts lower")
        XCTAssertFalse(NeckJoin.accepts(string: 1, fret: 7, asStartOf: dmaj7, for: hammer), "its own fret")
        XCTAssertFalse(NeckJoin.accepts(string: 5, fret: 3, asStartOf: dmaj7, for: hammer), "not one of its strings")
        XCTAssertTrue(NeckJoin.accepts(string: 1, fret: 9, asStartOf: dmaj7, for: pull))
        // The G at 1 would start off the neck if the shape moved, but it's held: the B's start isn't dimmed.
        let low = [note(2, 1), note(1, 3)]
        XCTAssertTrue(NeckJoin.accepts(string: 1, fret: 1, asStartOf: low, for: hammer))
        XCTAssertFalse(NeckJoin.accepts(string: 1, fret: 1, asStartOf: low,
                                        for: LeadInRequest(join: .legato, direction: .upward, together: true)),
                       "moving the shape would take the G off the neck")
    }

    func testTheMovingNotesShareOneJoinAndOneWay() {
        let twoWays = [lead(1, 7, from: .fret(5)), lead(0, 5, from: .fret(7)), note(2, 6)]
        XCTAssertFalse(NeckJoin.leadInsFit(twoWays), "one hammered, one pulled")
        XCTAssertEqual(NeckJoin.tidied([.fretted(twoWays, into: nil)])[0],
                       .fretted([note(1, 7), note(0, 5), note(2, 6)], into: nil))
        let twoJoins = [lead(1, 7, from: .fret(5)), lead(0, 7, from: .fret(5), .slide), note(2, 6)]
        XCTAssertFalse(NeckJoin.leadInsFit(twoJoins), "one hammered, one slid")
    }

    func testWhatsLitIsTheMovingNotesChoice() {
        let labels: [PieceLabel?] = [.fretted(hammered, into: nil)]
        XCTAssertTrue(NeckJoin.holds(.hammerOn, into: 0, of: labels), "the B moves; the A, first, is held")
        XCTAssertFalse(NeckJoin.holds(.picked, into: 0, of: labels))
        XCTAssertFalse(NeckJoin.holds(.pullOff, into: 0, of: labels))
    }

    func testASlideAlwaysMovesTheShape() {
        XCTAssertTrue(LeadInRequest(join: .slide, direction: nil).together, "a hand slides the shape")
        XCTAssertFalse(hammer.together, "a finger hammers")
        XCTAssertEqual(NeckJoin.route(.hammerOn, into: 0, of: [.fretted(dmaj7, into: nil)]), .inside(hammer))
    }

    func testAChordWithOneNoteMovingIsStoredAsItIs() throws {
        // New data in the keys 0230 D7 already has: one note's `leadIn`, none on the rest.
        let label = PieceLabel.fretted(hammered, into: nil)
        let read = try JSONDecoder().decode(PieceLabel.self, from: JSONEncoder().encode(label))
        XCTAssertEqual(read, label)
        XCTAssertEqual(read.frettedNotes.filter { $0.leadIn != nil }.map(\.string), [1], "only the B moves")
    }

    // MARK: - Moved or added, in a chord where one note moves

    func testAHeldNoteMovedStaysHeld() {
        let moved = NeckPlacement.tap(string: 2, fret: 7, on: .fretted(hammered, into: nil), ringed: 1, chords: true)
        XCTAssertEqual(moved.label.frettedNotes[2], note(2, 7))
        XCTAssertEqual(moved.label.frettedNotes[3], lead(1, 7, from: .fret(5)), "the B keeps its own start")
    }

    func testTheMovingNoteMovedKeepsItsOwnStartAsALoneNoteDoes() {
        let moved = NeckPlacement.tap(string: 1, fret: 9, on: .fretted(hammered, into: nil), ringed: 1, chords: true)
        XCTAssertEqual(moved.label.frettedNotes[3], lead(1, 9, from: .fret(5)))
        XCTAssertEqual(moved.label.frettedNotes.filter { $0.leadIn != nil }.count, 1)
    }

    func testANoteAddedToAChordWhereOneMovesIsHeld() {
        let added = NeckPlacement.tap(string: 5, fret: 5, on: .fretted(hammered, into: nil), ringed: 1, chords: true)
        XCTAssertEqual(added.label.frettedNotes.last, note(5, 5))
    }

    func testALoneNoteWithAStartStillPassesItOnAsItGrows() {
        let alone = PieceLabel.fretted([lead(2, 13, from: .fret(11))], into: nil)
        XCTAssertEqual(NeckPlacement.tap(string: 1, fret: 14, on: alone, ringed: 2, chords: true).label,
                       .fretted([lead(2, 13, from: .fret(11)), lead(1, 14, from: .fret(12))], into: nil),
                       "a double-stop hammered as one (0230 D6)")
    }

    // MARK: - The whole chord moved? (D2)

    func testTheWholeChordMovedGivesEveryNoteTheSameMove() {
        let all = [lead(4, 5, from: .fret(3)), lead(3, 7, from: .fret(5)), lead(2, 6, from: .fret(4)),
                   lead(1, 7, from: .fret(5)), lead(0, 5, from: .fret(3))]
        XCTAssertEqual(NeckJoin.movedAsOne(hammered), all)
        XCTAssertTrue(NeckJoin.movesAsOne(all))
        XCTAssertNil(NeckJoin.movedAsOne(all), "already moving as one")
        XCTAssertNil(NeckJoin.movedAsOne(dmaj7), "nothing moves")
        XCTAssertNil(NeckJoin.movedAsOne([note(2, 1), lead(1, 3, from: .fret(1))]), "the G would start off the neck")
        XCTAssertNil(NeckJoin.movedAsOne([note(2, 6), lead(1, 7, from: .below, .slide)]), "not a hammer-on or pull-off")
    }
}
