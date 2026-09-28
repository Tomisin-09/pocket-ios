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
