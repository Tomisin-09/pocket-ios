import XCTest
@testable import Pocket

/// The playing marks (ADR 0227 D5, D9): the sounding pitch with a bend, the join rule, the tab they write,
/// and a stored label that older data, and older builds, can still read.
final class NeckMarksTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func note(_ string: Int, _ fret: Int, bend: Int = 0, vibrato: Bool = false) -> FrettedNote {
        FrettedNote(string: string, fret: fret, bend: bend, vibrato: vibrato)
    }

    private func placed(_ notes: FrettedNote..., into: Join? = nil) -> PieceLabel {
        .fretted(notes, into: into)
    }

    // MARK: - A bend changes the note

    func testABentNoteSoundsWhereItLands() {
        let bent = placed(note(2, 7, bend: 2))   // G7 up a whole step
        XCTAssertEqual(bent.midiNote(openMidi: guitar), 64)
        XCTAssertEqual(bent.name(openMidi: guitar, spelling: .sharps), "E")
        XCTAssertEqual(bent.earReading(openMidi: guitar), EarReading(root: 4, kind: .note), "By ear reads the bend")
    }

    // MARK: - Joins

    func testAJoinGoesTheWayTheNoteMoved() {
        let rising: [PieceLabel?] = [placed(note(2, 5)), placed(note(2, 7), into: .legato)]
        XCTAssertEqual(NeckJoin.direction(into: 1, of: rising), .upward)
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: rising), "h")
        let down: [PieceLabel?] = [placed(note(2, 7)), placed(note(2, 5), into: .legato)]
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: down), "p")
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: [placed(note(1, 8)), placed(note(1, 10), into: .slide)]), "/")
        XCTAssertEqual(NeckJoin.symbol(into: 1, of: [placed(note(1, 10)), placed(note(1, 8), into: .slide)]), "\\")
    }

    func testAJoinNeedsTheTapBeforeOnTheSameStrings() {
        let second = placed(note(2, 7))
        XCTAssertEqual(NeckJoin.blocker(into: 0, of: [second]), .first)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [nil, second]), .previousUnnamed)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [.pitchClass(2), second]), .previousByEar)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [placed(note(1, 5)), second]), .otherStrings)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [placed(note(2, 7)), second]), .sameFret)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [placed(note(2, 5)), .pitchClass(1)]), .notPlaced)
        XCTAssertNil(NeckJoin.blocker(into: 1, of: [placed(note(2, 5)), second]))
    }

    func testAShapeJoinsOnlyWhenEveryNoteMovesTheSameWay() {
        let sixths = placed(note(1, 8), note(3, 7))
        let slidUp = placed(note(1, 10), note(3, 9), into: .slide)
        XCTAssertEqual(NeckJoin.direction(into: 1, of: [sixths, slidUp]), .upward)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [sixths, placed(note(1, 10), note(3, 7))]), .mixedDirections)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [sixths, placed(note(1, 10), note(3, 5))]), .mixedDirections)
        XCTAssertEqual(NeckJoin.blocker(into: 1, of: [sixths, placed(note(1, 10), note(2, 9))]), .otherStrings)
    }

    func testAJoinThatStopsFittingIsDropped() {
        // The note before moves onto the same fret: the hammer-on into this one is no longer one.
        let labels: [PieceLabel?] = [placed(note(2, 7)), placed(note(2, 7), into: .legato),
                                     placed(note(2, 5), into: .legato)]
        XCTAssertEqual(NeckJoin.tidied(labels), [placed(note(2, 7)), placed(note(2, 7)),
                                                 placed(note(2, 5), into: .legato)])
        XCTAssertEqual(NeckJoin.tidied(NeckJoin.tidied(labels)), NeckJoin.tidied(labels), "and tidying settles")
    }

    // MARK: - The tab

    func testMarksAreWrittenTheUsualWay() {
        XCTAssertEqual(TabLine.cell(note(2, 7, bend: 2)), "7b9")
        XCTAssertEqual(TabLine.cell(note(2, 7, vibrato: true)), "7~")
        XCTAssertEqual(TabLine.cell(note(2, 7, bend: 1, vibrato: true)), "7b8~")
        XCTAssertEqual(TabLine.cell(note(2, 12)), "12")
    }

    func testAJoinTakesThePlaceOfTheDashes() throws {
        let tab = try XCTUnwrap(TabLine.render([placed(note(1, 5)), placed(note(1, 7), into: .legato),
                                                placed(note(1, 8, vibrato: true)), placed(note(2, 7, bend: 2))],
                                               openMidi: guitar))
        XCTAssertEqual(tab, """
        e|---------------|
        B|-5h7--8~-------|
        G|----------7b9--|
        D|---------------|
        A|---------------|
        E|---------------|
        """)
    }

    func testAJoinThatDoesntFitIsNotWritten() throws {
        // Stored, but the note before is on another string: the tab doesn't claim it.
        let tab = try XCTUnwrap(TabLine.render([placed(note(2, 5)), placed(note(1, 7), into: .legato)],
                                               openMidi: guitar))
        XCTAssertFalse(tab.contains("h"), tab)
    }

    func testAShapeStacksInOneColumn() throws {
        let tab = try XCTUnwrap(TabLine.render([placed(note(1, 8), note(3, 7)), placed(note(1, 10), note(3, 9),
                                                                                       into: .slide)],
                                               openMidi: guitar))
        XCTAssertEqual(tab, """
        e|-------|
        B|-8/10--|
        G|-------|
        D|-7/9---|
        A|-------|
        E|-------|
        """)
        XCTAssertEqual(Set(tab.split(separator: "\n").map(\.count)).count, 1, tab)
    }

    // MARK: - Storage (D9)

    func testAMarkedNoteRoundTrips() throws {
        let labels: [PieceLabel] = [placed(note(2, 7, bend: 2, vibrato: true), into: .legato),
                                    placed(note(1, 8), note(0, 8), into: .slide)]
        let data = try JSONEncoder().encode(labels)
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: data), labels)
    }

    func testAnUnmarkedNoteIsWrittenExactlyAs0225WroteIt() throws {
        let json = try XCTUnwrap(String(data: JSONEncoder.sorted.encode(PieceLabel.fretted(string: 1, fret: 5)),
                                        encoding: .utf8))
        XCTAssertEqual(json, #"{"fret":5,"kind":"fret","string":1}"#)
    }

    func testA0225PieceStillReads() throws {
        let json = #"[{"kind":"fret","string":1,"fret":5},{"kind":"note","pitchClass":2}]"#
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: Data(json.utf8)),
                       [.fretted(string: 1, fret: 5), .pitchClass(2)])
    }

    func testAnOlderBuildKeepsAMarkedNotesFretAndDropsTheShape() throws {
        let marked = try JSONEncoder().encode(placed(note(2, 7, bend: 2, vibrato: true), into: .slide))
        let old = try JSONDecoder().decode(Label0225.self, from: marked)
        XCTAssertEqual([old.string, old.fret], [2, 7], "a note without its bend is still where it was played")
        let shape = try JSONEncoder().encode(placed(note(1, 8), note(0, 8)))
        XCTAssertThrowsError(try JSONDecoder().decode(Label0225.self, from: shape),
                             "an unknown kind, which the older piece reads as an unnamed tap")
    }

    func testOddStoredMarksReadSafely() throws {
        let json = #"[{"kind":"fret","string":1,"fret":5,"bend":9,"into":"tap"}]"#
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: Data(json.utf8)),
                       [.fretted(string: 1, fret: 5)], "a bend past 1½ steps and an unknown join read as none")
        let lonely = #"{"seconds": 1, "label": {"kind":"shape","notes":[{"string":1,"fret":5}]}}"#
        XCTAssertNil(try JSONDecoder().decode(PieceTranscription.Tap.self, from: Data(lonely.utf8)).label,
                     "a one-note shape isn't a shape")
    }
}

/// **A note heard as one** (ADR 0230): a hammer-on, pull-off or slide inside one tap, as its lead-in, for
/// one note or a shape moving as one; and the four ways in under the neck.
final class LeadInTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi   // [64, 59, 55, 50, 45, 40]

    private func note(_ string: Int, _ fret: Int) -> FrettedNote {
        FrettedNote(string: string, fret: fret)
    }

    private func lead(_ string: Int, _ fret: Int, from start: LeadIn.Start, _ join: Join) -> FrettedNote {
        FrettedNote(string: string, fret: fret, leadIn: LeadIn(from: start, join: join))
    }

    private func placed(_ notes: FrettedNote..., into: Join? = nil) -> PieceLabel {
        .fretted(notes, into: into)
    }

    func testALeadInIsWrittenInsideItsColumn() {
        XCTAssertEqual(TabLine.cell(lead(2, 13, from: .fret(11), .legato)), "11h13")
        XCTAssertEqual(TabLine.cell(lead(2, 11, from: .fret(13), .legato)), "13p11")
        XCTAssertEqual(TabLine.cell(lead(2, 13, from: .fret(11), .slide)), "11/13")
        XCTAssertEqual(TabLine.cell(lead(2, 11, from: .fret(13), .slide)), "13\\11")
        XCTAssertEqual(TabLine.cell(lead(2, 13, from: .below, .slide)), "/13", "a slide in from nowhere")
        XCTAssertEqual(TabLine.cell(lead(2, 13, from: .above, .slide)), "\\13")
        var marked = lead(2, 13, from: .fret(11), .legato)
        marked.bend = 2
        marked.vibrato = true
        XCTAssertEqual(TabLine.cell(marked), "11h13b15~")
    }

    func testANoteHeardAsOneSoundsWhereItLandsAndTakesNoJoinFromTheTapBefore() throws {
        let labels: [PieceLabel?] = [placed(note(2, 9)), placed(lead(2, 13, from: .fret(11), .legato))]
        XCTAssertEqual(labels[1]?.midiNote(openMidi: guitar), 55 + 13, "read as the note it lands on")
        XCTAssertNil(NeckJoin.symbol(into: 1, of: labels), "its join is inside it")
        let untidied: [PieceLabel?] = [placed(note(2, 9)),
                                       .fretted([lead(2, 13, from: .fret(11), .legato)], into: .legato)]
        XCTAssertNil(NeckJoin.symbol(into: 1, of: untidied), "never a join from the tap before as well")
        let tab = try XCTUnwrap(TabLine.render(labels, openMidi: guitar))
        XCTAssertTrue(tab.contains("G|-9--11h13--|"), tab)
    }

    func testTidyKeepsALeadInOnlyWhereItCanBePlayed() {
        let both: [PieceLabel?] = [placed(note(2, 9)),
                                   .fretted([lead(2, 13, from: .fret(11), .legato)], into: .legato)]
        XCTAssertEqual(NeckJoin.tidied(both)[1], placed(lead(2, 13, from: .fret(11), .legato)),
                       "heard as one, so no join from the tap before as well")
        XCTAssertEqual(NeckJoin.tidied([placed(lead(2, 11, from: .fret(11), .legato))])[0], placed(note(2, 11)),
                       "moved onto its own start")
        XCTAssertEqual(NeckJoin.tidied([placed(lead(2, 13, from: .below, .legato))])[0], placed(note(2, 13)),
                       "a hammer-on from nowhere")
        let oneOfTwo = placed(lead(2, 13, from: .below, .slide), note(1, 14))
        XCTAssertEqual(NeckJoin.tidied([oneOfTwo])[0], oneOfTwo,
                       "one note of a shape moves and the other is held (ADR 0252 D1)")
    }

    func testTheFourWaysIn() {
        let rising: [PieceLabel?] = [placed(note(2, 11)), placed(note(2, 13))]
        XCTAssertEqual(NeckJoin.route(.picked, into: 1, of: rising), .clear)
        XCTAssertEqual(NeckJoin.route(.hammerOn, into: 1, of: rising), .fromBefore(.legato))
        XCTAssertEqual(NeckJoin.route(.pullOff, into: 1, of: rising),
                       .inside(LeadInRequest(join: .legato, direction: .downward)),
                       "pulled off from above, heard as one")
        XCTAssertEqual(NeckJoin.route(.slide, into: 1, of: rising), .fromBefore(.slide))
        let apart: [PieceLabel?] = [placed(note(3, 13)), placed(note(2, 13))]
        XCTAssertEqual(NeckJoin.route(.hammerOn, into: 1, of: apart),
                       .inside(LeadInRequest(join: .legato, direction: .upward)))
        XCTAssertEqual(NeckJoin.route(.slide, into: 1, of: apart), .inside(LeadInRequest(join: .slide, direction: nil)))
        let shape: [PieceLabel?] = [placed(note(3, 13)), placed(note(2, 13), note(1, 14))]
        XCTAssertEqual(NeckJoin.route(.slide, into: 1, of: shape), .inside(LeadInRequest(join: .slide, direction: nil)),
                       "a shape slides in as one")
        XCTAssertEqual(NeckJoin.route(.hammerOn, into: 0, of: [nil]), .unavailable, "nothing placed")
    }

    func testWhatANoteHoldsLightsItsChoice() {
        let pulled: [PieceLabel?] = [placed(lead(2, 11, from: .fret(13), .legato))]
        XCTAssertTrue(NeckJoin.holds(.pullOff, into: 0, of: pulled))
        XCTAssertFalse(NeckJoin.holds(.hammerOn, into: 0, of: pulled))
        XCTAssertFalse(NeckJoin.holds(.picked, into: 0, of: pulled))
        let hammered: [PieceLabel?] = [placed(note(2, 11)), placed(note(2, 13), into: .legato)]
        XCTAssertTrue(NeckJoin.holds(.hammerOn, into: 1, of: hammered))
        XCTAssertTrue(NeckJoin.holds(.picked, into: 0, of: hammered))
        XCTAssertEqual(LeadInRequest(join: .legato, direction: .downward).choice, .pullOff)
        XCTAssertEqual(LeadInRequest(join: .legato, direction: .upward).choice, .hammerOn)
        XCTAssertEqual(LeadInRequest(join: .slide, direction: nil).choice, .slide)
    }

    func testAStartIsOnTheNotesStringOnTheSideItMovesFrom() {
        let target = note(2, 13)
        let hammer = LeadInRequest(join: .legato, direction: .upward)
        XCTAssertTrue(NeckJoin.accepts(string: 2, fret: 11, asStartOf: [target], for: hammer))
        XCTAssertFalse(NeckJoin.accepts(string: 2, fret: 15, asStartOf: [target], for: hammer),
                       "a hammer-on starts lower")
        XCTAssertFalse(NeckJoin.accepts(string: 3, fret: 11, asStartOf: [target], for: hammer), "another string")
        XCTAssertFalse(NeckJoin.accepts(string: 2, fret: 13, asStartOf: [target], for: hammer), "its own fret")
        XCTAssertTrue(NeckJoin.accepts(string: 2, fret: 15, asStartOf: [target],
                                       for: LeadInRequest(join: .slide, direction: nil)), "a slide, either side")
    }

    func testMovingTheNoteAlongItsStringKeepsItsLeadIn() {
        let start = placed(lead(2, 13, from: .fret(11), .legato))
        XCTAssertEqual(NeckPlacement.tap(string: 2, fret: 14, on: start, ringed: 2, chords: false).label,
                       placed(lead(2, 14, from: .fret(11), .legato)))
        XCTAssertEqual(NeckPlacement.tap(string: 1, fret: 14, on: start, ringed: 2, chords: false).label,
                       placed(note(1, 14)), "on another string its start means nothing")
    }

    // MARK: - A shape moving as one (ADR 0230 D6)

    func testADoubleStopSlidAsOneKeepsItsLeadInsAndStacksInTheTab() throws {
        let slid = placed(lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(6), .slide))
        XCTAssertEqual(NeckJoin.tidied([slid])[0], slid, "both notes two frets up")
        let tab = try XCTUnwrap(TabLine.render([slid], openMidi: guitar))
        XCTAssertTrue(tab.contains("B|-6/8--|") && tab.contains("G|-5/7--|"), tab)
        let fromBelow = placed(lead(2, 7, from: .below, .slide), lead(1, 8, from: .below, .slide))
        XCTAssertEqual(NeckJoin.tidied([fromBelow])[0], fromBelow)
        let apart = placed(lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(7), .slide))
        XCTAssertEqual(NeckJoin.tidied([apart])[0], placed(note(2, 7), note(1, 8)), "not moving as one")
        let mixed = placed(lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(6), .legato))
        XCTAssertEqual(NeckJoin.tidied([mixed])[0], placed(note(2, 7), note(1, 8)), "one slid, one hammered")
        XCTAssertTrue(NeckJoin.holds(.slide, into: 0, of: [slid]))
    }

    func testAShapesStartIsTappedOnAnyOfItsStringsAndTheRestFollow() throws {
        let shape = [note(2, 7), note(1, 8)]
        let started = try XCTUnwrap(NeckJoin.starts(string: 1, fret: 6, of: shape, join: .slide))
        XCTAssertEqual(started, [lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(6), .slide)])
        let slide = LeadInRequest(join: .slide, direction: nil)
        XCTAssertFalse(NeckJoin.accepts(string: 3, fret: 5, asStartOf: shape, for: slide), "not one of its strings")
        XCTAssertFalse(NeckJoin.accepts(string: 2, fret: 7, asStartOf: shape, for: slide), "its own fret")
        XCTAssertFalse(NeckJoin.accepts(string: 1, fret: 0, asStartOf: [note(2, 1), note(1, 3)], for: slide),
                       "the G string's note would start off the neck")
        let hammer = LeadInRequest(join: .legato, direction: .upward)
        XCTAssertFalse(NeckJoin.accepts(string: 2, fret: 9, asStartOf: shape, for: hammer), "a hammer-on starts lower")
    }

    func testANoteMovedOrAddedInAShapeTakesItsMove() {
        let slid = placed(lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(6), .slide))
        XCTAssertEqual(NeckPlacement.tap(string: 1, fret: 9, on: slid, ringed: 1, chords: true).label,
                       placed(lead(2, 7, from: .fret(5), .slide), lead(1, 9, from: .fret(7), .slide)), "moved")
        XCTAssertEqual(NeckPlacement.tap(string: 0, fret: 7, on: slid, ringed: 1, chords: true).label,
                       placed(lead(2, 7, from: .fret(5), .slide), lead(1, 8, from: .fret(6), .slide),
                              lead(0, 7, from: .fret(5), .slide)), "added")
        let alone = placed(lead(2, 13, from: .fret(11), .legato))
        XCTAssertEqual(NeckPlacement.tap(string: 2, fret: 14, on: alone, ringed: 2, chords: true).label,
                       placed(lead(2, 14, from: .fret(11), .legato)), "a lone note keeps the fret it started from")
    }

    func testALeadInRoundTripsAndOddOnesReadSafely() throws {
        let labels: [PieceLabel] = [placed(lead(2, 13, from: .fret(11), .legato)),
                                    placed(lead(1, 8, from: .below, .slide))]
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: JSONEncoder().encode(labels)), labels)
        let json = try XCTUnwrap(String(data: JSONEncoder.sorted.encode(labels[0]), encoding: .utf8))
        XCTAssertEqual(json, #"{"fret":13,"kind":"fret","leadIn":{"from":11,"join":"legato"},"string":2}"#)
        let odd = #"[{"kind":"fret","string":2,"fret":13,"leadIn":{"from":13,"join":"legato"}},"#
            + #"{"kind":"fret","string":2,"fret":13,"leadIn":{"from":"below","join":"legato"}},"#
            + #"{"kind":"fret","string":2,"fret":13,"leadIn":{"from":"sideways","join":"slide"}}]"#
        XCTAssertEqual(try JSONDecoder().decode([PieceLabel].self, from: Data(odd.utf8)),
                       Array(repeating: .fretted(string: 2, fret: 13), count: 3),
                       "its own fret, a hammer-on from nowhere and an unknown start read as a plain note")
        let old = try JSONDecoder().decode(Label0225.self, from: JSONEncoder().encode(labels[0]))
        XCTAssertEqual([old.string, old.fret], [2, 13], "0225 keeps the note it lands on")
    }
}

/// 0225's decoder, copied from `f10bb05`, standing in for an older build meeting this one's data.
private struct Label0225: Decodable, Equatable {
    enum Kind: String, Decodable { case note, fret, chord }
    enum Keys: String, CodingKey { case kind, pitchClass, string, fret, root, suffix }
    let kind: Kind
    let string: Int?
    let fret: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        string = kind == .fret ? try container.decode(Int.self, forKey: .string) : nil
        fret = kind == .fret ? try container.decode(Int.self, forKey: .fret) : nil
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}
