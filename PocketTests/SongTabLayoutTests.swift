import XCTest
@testable import Pocket

/// The song map's Tab view (ADR 0232 D10): where its rows break, what each tap draws as, and how the
/// columns are spaced so nothing prints over anything else. Pure arithmetic over plain values (AGENTS.md).
final class SongTabLayoutTests: XCTestCase {

    // MARK: - Fixtures

    /// 120 BPM in 4/4: a bar every 2 s, the first downbeat at 0.
    private func grid(duration: TimeInterval) -> SongMapInput.Grid {
        SongMapInput.Grid(downbeats: Array(stride(from: 0, to: duration, by: 2)), barSeconds: 2)
    }

    private func loop(_ start: TimeInterval, _ end: TimeInterval, type: LoopType = .unset,
                      piece: PieceTranscription? = nil, handTagged: Bool = false,
                      uid: UUID = UUID()) -> SongMapInput.LoopInput {
        .init(uid: uid, name: "Loop", start: start, end: end, type: type, piece: piece, handTagged: handTagged)
    }

    private func piece(_ taps: [(TimeInterval, PieceLabel?)], openMidi: [Int]? = nil) -> PieceTranscription {
        PieceTranscription(taps: taps.map { PieceTranscription.Tap(seconds: $0.0, label: $0.1) }, openMidi: openMidi)
    }

    private func tab(duration: TimeInterval = 64, grid: SongMapInput.Grid? = nil,
                     markers: [SongMapInput.MarkerInput] = [], loops: [SongMapInput.LoopInput] = [],
                     spelling: NoteSpelling = .flats) -> SongTab {
        let map = SongMapLayout.build(SongMapInput(duration: duration, grid: grid, markers: markers, loops: loops))
        return SongTabLayout.build(map, spelling: spelling)
    }

    private let standard = [64, 59, 55, 50, 45, 40]

    private func column(_ time: TimeInterval, _ mark: SongTab.Mark) -> SongTab.Column {
        SongTab.Column(time: time, piece: UUID(), mark: mark, name: nil)
    }

    private let eightSeconds = SongTab.Row(start: 0, end: 8, widthFraction: 1, ticks: [], lines: [], pieces: [])

    // MARK: - Rows

    func testRowsAreFourBarsWithAGrid() {
        let rows = tab(grid: grid(duration: 64)).sections[0].rows
        XCTAssertEqual(rows.map(\.start), [0, 8, 16, 24, 32, 40, 48, 56])
        XCTAssertEqual(rows[0].ticks.map(\.bar), [1, 2, 3, 4])
    }

    func testRowsAreEightSecondsWithoutAGridAndTheLastDrawsShort() {
        let rows = tab(duration: 20).sections[0].rows
        XCTAssertEqual(rows.map(\.start), [0, 8, 16])
        XCTAssertEqual(rows[2].widthFraction, 0.5, accuracy: 1e-9)
        XCTAssertEqual(rows[0].ticks.map(\.time), [0, 2, 4, 6])
        XCTAssertEqual(rows[0].ticks.map(\.bar), [nil, nil, nil, nil])
    }

    func testRowsRestartAtEachSection() {
        let chorus = SongMapInput.MarkerInput(uid: UUID(), seconds: 10, label: "Chorus", startsSection: true)
        let sections = tab(grid: grid(duration: 64), markers: [chorus]).sections
        XCTAssertEqual(sections[0].rows.map(\.start), [0, 8])
        XCTAssertEqual(sections[1].rows.map(\.start), [10, 18, 26, 34, 42, 50, 58])
    }

    // MARK: - What a tap draws as (D4, D10)

    func testChordsSitAtTheirTapsAsSymbols() {
        let chords = piece([(1, .chord(root: 7, suffix: "m7")), (3, .chord(root: 0, suffix: "7"))])
        let line = tab(loops: [loop(0, 8, piece: chords)]).sections[0].rows[0].lines
        XCTAssertEqual(line.count, 1)
        XCTAssertEqual(line[0].layer, .chords)
        XCTAssertFalse(line[0].isTab)
        XCTAssertEqual(line[0].columns.map(\.mark), [.name("Gm7"), .name("C7")])
        XCTAssertEqual(line[0].columns.map(\.time), [1, 3])
    }

    func testACountWithNoNamesIsSlashes() {
        let counted = piece([(1, nil), (2, nil), (3, nil)])
        let line = tab(loops: [loop(0, 8, type: .chords, piece: counted)]).sections[0].rows[0].lines[0]
        XCTAssertEqual(line.layer, .chords, "no names: the loop's type decides (D3)")
        XCTAssertEqual(line.columns.map(\.mark), [.slash, .slash, .slash])
        XCTAssertEqual(line.columns.map(\.name), [nil, nil, nil])
    }

    func testNotesOnTheNeckAreTabOnTheirStrings() {
        let riff = piece([(1, .fretted(string: 3, fret: 3)), (2, .fretted(string: 2, fret: 5))], openMidi: standard)
        let line = tab(loops: [loop(0, 8, type: .riff, piece: riff)]).sections[0].rows[0].lines[0]
        XCTAssertEqual(line.layer, .notes)
        XCTAssertEqual(line.strings, ["e", "B", "G", "D", "A", "E"])
        XCTAssertFalse(line.hasWordsAboveTab)
        XCTAssertEqual(line.columns.map(\.mark), [.frets([SongTab.FretCell(string: 3, text: "3")]),
                                                  .frets([SongTab.FretCell(string: 2, text: "5")])])
        XCTAssertEqual(line.columns.map(\.name), ["F", "C"], "spoken as the notes they sound")
    }

    func testNamesAndSlashesInATabLineSitAboveTheStrings() {
        let mixed = piece([(1, .fretted(string: 3, fret: 3)), (2, .pitchClass(10)), (3, nil)], openMidi: standard)
        let line = tab(loops: [loop(0, 8, piece: mixed)]).sections[0].rows[0].lines[0]
        XCTAssertTrue(line.isTab)
        XCTAssertTrue(line.hasWordsAboveTab)
        XCTAssertEqual(line.columns.map(\.mark), [.frets([SongTab.FretCell(string: 3, text: "3")]),
                                                  .name("B♭"), .slash])
    }

    func testANotesPieceNamedByEarIsALineOfNames() {
        let byEar = piece([(1, .pitchClass(0)), (2, .pitchClass(3))])
        let line = tab(loops: [loop(0, 8, type: .lick, piece: byEar)], spelling: .sharps)
            .sections[0].rows[0].lines[0]
        XCTAssertFalse(line.isTab)
        XCTAssertEqual(line.columns.map(\.mark), [.name("C"), .name("D♯")])
    }

    func testAJoinAndABendAreWrittenAsTabWritesThem() {
        let legato = piece([(1, .fretted(string: 2, fret: 5)),
                            (2, .fretted([FrettedNote(string: 2, fret: 7)], into: .legato)),
                            (3, .fretted([FrettedNote(string: 1, fret: 8, bend: 2)], into: nil))],
                           openMidi: standard)
        let marks = tab(loops: [loop(0, 8, piece: legato)]).sections[0].rows[0].lines[0].columns.map(\.mark)
        XCTAssertEqual(marks, [.frets([SongTab.FretCell(string: 2, text: "5")]),
                               .frets([SongTab.FretCell(string: 2, text: "h7")]),
                               .frets([SongTab.FretCell(string: 1, text: "8b10")])])
    }

    func testAShapeInTheChordsLayerIsItsSymbolNotItsFrets() {
        let openC = PieceLabel.fretted([FrettedNote(string: 4, fret: 3), FrettedNote(string: 3, fret: 2),
                                        FrettedNote(string: 2, fret: 0), FrettedNote(string: 1, fret: 1),
                                        FrettedNote(string: 0, fret: 0)], into: nil)
        let line = tab(loops: [loop(0, 8, piece: piece([(1, openC)], openMidi: standard))])
            .sections[0].rows[0].lines[0]
        XCTAssertEqual(line.layer, .chords)
        XCTAssertFalse(line.isTab)
        XCTAssertEqual(line.columns.map(\.mark), [.name("C")])
    }

    func testANoteOnAStringTheTuningLacksFallsBackToItsName() {
        let offTheNeck = piece([(1, .fretted(string: 6, fret: 3))], openMidi: standard)
        let line = tab(loops: [loop(0, 8, piece: offTheNeck)]).sections[0].rows[0].lines[0]
        XCTAssertFalse(line.isTab)
        XCTAssertEqual(line.columns.map(\.mark), [.slash], "no string to draw it on, and no note it sounds")
    }

    func testEmptyAndHandTaggedLoopsReadAsAGap() {
        let tab = tab(loops: [loop(0, 4), loop(4, 8, handTagged: true)])
        XCTAssertEqual(tab.sections[0].rows[0].lines, [])
        XCTAssertEqual(tab.sections[0].rows[0].pieces, [])
        XCTAssertTrue(tab.isEmpty)
    }

    // MARK: - Lines and rows

    func testChordsAreAboveNotesAndOverlappingNotesTakeTwoLines() {
        let one = UUID(), two = UUID(), chords = UUID()
        let row = tab(loops: [loop(0, 8, piece: piece([(5, nil)]), uid: one),
                              loop(2, 8, piece: piece([(3, nil)]), uid: two),
                              loop(0, 8, piece: piece([(6, .chord(root: 2, suffix: ""))]), uid: chords)])
            .sections[0].rows[0]
        XCTAssertEqual(row.lines.map(\.id), ["0-0", "1-0", "1-1"])
        XCTAssertEqual(row.pieces, [two, one, chords], "in the order their first taps come")
    }

    func testATapBelongsToTheRowItFallsIn() {
        let straddle = piece([(7.9, nil), (8, nil), (12, nil)])
        let rows = tab(duration: 16, loops: [loop(4, 12, piece: straddle)]).sections[0].rows
        XCTAssertEqual(rows[0].lines[0].columns.map(\.time), [7.9])
        XCTAssertEqual(rows[1].lines[0].columns.map(\.time), [8], "12 is where the loop ends, so it's out")
    }

    // MARK: - Spacing

    func testAColumnSitsJustAfterItsTime() {
        let placed = SongTabLayout.spread([column(2, .slash)], in: eightSeconds, width: 40)
        XCTAssertEqual(placed, [10.5])
    }

    func testACrowdedColumnIsPushedJustClearOfTheOneBefore() {
        let placed = SongTabLayout.spread([column(0, .name("Gm7")), column(0.05, .slash)],
                                          in: eightSeconds, width: 40)
        XCTAssertEqual(placed, [0.5, 4.5], "Gm7 is 3 wide, then a gap of 1")
    }

    func testALinePushedPastTheEndIsDrawnBackFromIt() {
        let placed = SongTabLayout.spread([column(7.9, .slash), column(7.95, .slash)],
                                          in: eightSeconds, width: 40)
        XCTAssertEqual(placed, [37, 39])
    }

    func testARowIsAsWideAsItHasUnlessALineNeedsMore() {
        let line = SongTab.Line(layer: .notes, lane: 0, strings: [],
                                columns: [column(1, .slash), column(2, .name("Gm7")), column(3, .slash)])
        let row = SongTab.Row(start: 0, end: 8, widthFraction: 1, ticks: [], lines: [line], pieces: [])
        XCTAssertEqual(SongTabLayout.width(of: row, available: 40), 40)
        XCTAssertEqual(SongTabLayout.width(of: row, available: 5), 7.5, "a lead of 0.5, 1 + 3 + 1, two gaps")
    }

    func testAFastRunNeverOverprintsAtTheWidthItIsGiven() {
        let columns = (0..<30).map { column(Double($0) * 0.02, .frets([SongTab.FretCell(string: 0, text: "12")])) }
        let line = SongTab.Line(layer: .notes, lane: 0, strings: ["e"], columns: columns)
        let row = SongTab.Row(start: 0, end: 8, widthFraction: 1, ticks: [], lines: [line], pieces: [])
        let width = SongTabLayout.width(of: row, available: 40)
        XCTAssertGreaterThan(width, 40, "30 two-digit frets don't fit in 40 characters")
        let placed = SongTabLayout.spread(columns, in: row, width: width)
        XCTAssertGreaterThanOrEqual(placed[0], 0)
        XCTAssertLessThanOrEqual(placed[29] + 2, width + 1e-9)
        for index in 1..<placed.count {
            XCTAssertGreaterThanOrEqual(placed[index], placed[index - 1] + 2 + SongTabLayout.gap - 1e-9)
        }
    }
}
