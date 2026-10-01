import XCTest
@testable import Pocket

/// A tab as the text and PDF it leaves in (ADR 0236 D9): a written tab from My tabs, and a song's tab from
/// Map the song, laid out by the same code the screens draw with. Pure, over plain values (AGENTS.md),
/// except the PDF's smoke test at the end.
final class TabDocumentTests: XCTestCase {

    private let guitar = Instrument.guitar.standardTuning.engineOpenMidi
    private let standard = [64, 59, 55, 50, 45, 40]

    // MARK: - A written tab

    private func written(_ labels: [PieceLabel?], bars: [Int] = [], sections: [TabSection] = []) -> TabDocument {
        TabDocument.written(title: "Riff idea",
                            notes: PieceNotes(labels: labels, openMidi: guitar, tuningLabel: "Guitar · Standard",
                                              bars: bars, sections: sections),
                            spelling: .flats)
    }

    /// The strings thinnest first, a cell per note with `--` between, as `TabLine` writes tab.
    func testAWrittenRowIsAStringPerLine() {
        let doc = written([.fretted(string: 5, fret: 0), .fretted(string: 4, fret: 7), .fretted(string: 3, fret: 5)])
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].lines.map(\.text), [
            "e|---------|",
            "B|---------|",
            "G|---------|",
            "D|-------5-|",
            "A|----7----|",
            "E|-0-------|"
        ])
        XCTAssertEqual(doc.blocks[0].lines.map(\.kind), Array(repeating: .strings, count: 6))
    }

    func testTheTitleAndWhatItHoldsHeadTheDocument() {
        let doc = written([.fretted(string: 5, fret: 0)])
        XCTAssertEqual(doc.title, "Riff idea")
        XCTAssertEqual(doc.subtitle, "1 note · Guitar · Standard")
        XCTAssertTrue(doc.text.hasPrefix("Riff idea\n1 note · Guitar · Standard\n\n"))
        XCTAssertTrue(doc.text.hasSuffix("how long each lasts isn't written.\n"))
    }

    /// A bar line is a column of its own, drawn down every string.
    func testABarLineIsDrawnDownEveryString() {
        let doc = written([.fretted(string: 5, fret: 0), .fretted(string: 5, fret: 3)], bars: [1])
        for line in doc.blocks[0].lines {
            XCTAssertEqual(line.text.filter { $0 == "|" }.count, 3, "a bar line between the notes: \(line.text)")
        }
    }

    /// Each section starts a block under its heading.
    func testASectionHeadsItsFirstRow() {
        let doc = written((0..<6).map { .fretted(string: 2, fret: $0) },
                          sections: [TabSection(start: 0, name: "Intro"), TabSection(start: 3, name: "Verse")])
        XCTAssertEqual(doc.blocks.map(\.heading), ["Intro", "Verse"])
        XCTAssertTrue(doc.text.contains("\n\nIntro\ne|"))
    }

    /// A long tab wraps at the width, every row's strings the same length as each other.
    func testALongTabWrapsAndItsStringsLineUp() {
        let doc = written((0..<80).map { .fretted(string: $0 % 6, fret: $0 % 12) })
        XCTAssertGreaterThan(doc.blocks.count, 1)
        for block in doc.blocks {
            let lengths = Set(block.lines.filter { $0.kind == .strings }.map(\.text.count))
            XCTAssertEqual(lengths.count, 1, "a row's strings line up")
            XCTAssertLessThanOrEqual(lengths.first ?? 0, TabDocument.width + 6)
        }
    }

    /// What the neck can't say goes above the strings, in its column.
    func testAnUnnamedNoteIsADotAboveTheStrings() {
        let doc = written([.fretted(string: 5, fret: 0), nil, .fretted(string: 5, fret: 3)])
        let lines = doc.blocks[0].lines
        XCTAssertEqual(lines[0].kind, .names)
        XCTAssertEqual(lines[0].text, "      ·")
        XCTAssertEqual(lines.count, 7)
    }

    func testATabWithNothingOnTheNeckIsItsNamesInFours() {
        let doc = written([.pitchClass(0), .pitchClass(4), nil, .pitchClass(7), .pitchClass(9)])
        XCTAssertEqual(doc.blocks[0].lines.map(\.text), ["1 C   2 E   3 –   4 G", "5 A"])
    }

    func testAnEmptyTabIsItsTitleAlone() {
        let doc = written([])
        XCTAssertTrue(doc.blocks.isEmpty)
        XCTAssertEqual(TabDocument.written(title: "  ", notes: PieceNotes(labels: []), spelling: .flats).title,
                       "Untitled tab")
    }

    // MARK: - A song's tab

    /// 120 BPM in 4/4: a bar every 2 s.
    private func songTab(markers: [SongMapInput.MarkerInput] = [],
                         loops: [SongMapInput.LoopInput], duration: TimeInterval = 16) -> SongTab {
        let grid = SongMapInput.Grid(downbeats: Array(stride(from: 0, to: duration, by: 2)), barSeconds: 2)
        let map = SongMapLayout.build(SongMapInput(duration: duration, grid: grid, markers: markers, loops: loops))
        return SongTabLayout.build(map, spelling: .flats)
    }

    private func loop(_ start: TimeInterval, _ end: TimeInterval, type: LoopType,
                      taps: [(TimeInterval, PieceLabel?)]) -> SongMapInput.LoopInput {
        let piece = PieceTranscription(taps: taps.map { PieceTranscription.Tap(seconds: $0.0, label: $0.1) },
                                       openMidi: standard)
        return .init(uid: UUID(), name: "Loop", start: start, end: end, type: type, piece: piece, handTagged: false)
    }

    private var chorus: SongMapInput.MarkerInput {
        SongMapInput.MarkerInput(uid: UUID(), seconds: 0, label: "Chorus", startsSection: true)
    }

    func testASongsTabIsHeadedByItsSectionsAndBars() {
        let chords = loop(0, 8, type: .chords, taps: [(1, .chord(root: 9, suffix: "m"))])
        let tab = songTab(markers: [chorus], loops: [chords])
        let doc = TabDocument.song(title: "Slow Bend", artist: "Jack Trader", tab: tab)
        XCTAssertEqual(doc.title, "Slow Bend")
        XCTAssertEqual(doc.subtitle, "Jack Trader")
        XCTAssertEqual(doc.blocks.first?.heading, "Chorus · Bars 1–8")
        XCTAssertEqual(doc.blocks.count, 2, "two rows of four bars, the second under no heading")
        XCTAssertNil(doc.blocks[1].heading)
    }

    /// The ruler names each bar over its line, and a chord sits over its time.
    func testBarNumbersAndChordsSitWhereTheyPlay() throws {
        let tab = songTab(loops: [loop(0, 8, type: .chords, taps: [(0.1, .chord(root: 9, suffix: "m")),
                                                                    (4.1, .chord(root: 0, suffix: ""))])])
        let lines = TabDocument.song(title: "Slow Bend", artist: "", tab: tab).blocks[0].lines
        XCTAssertEqual(lines[0].kind, .ruler)
        XCTAssertEqual(lines[0].text.split(separator: " "), ["1", "2", "3", "4"])
        XCTAssertEqual(lines[1].kind, .chords)
        XCTAssertNotNil(lines[1].text.range(of: "Am"))
        // Bar 3 starts at 4 s, and C is struck just after it, so it sits over the 3 or a column past it.
        let chordC = try XCTUnwrap(lines[1].text.firstIndex(of: "C"))
        let three = try XCTUnwrap(lines[0].text.firstIndex(of: "3"))
        let cColumn = lines[1].text.distance(from: lines[1].text.startIndex, to: chordC)
        let barColumn = lines[0].text.distance(from: lines[0].text.startIndex, to: three)
        XCTAssertTrue((barColumn...barColumn + 1).contains(cColumn), "C at \(cColumn), bar 3 at \(barColumn)")
    }

    /// A lane on the neck is its strings, the bar lines down them, every string the same length.
    func testNotesOnTheNeckAreStringsThatLineUp() {
        let tab = songTab(loops: [loop(0, 8, type: .riff, taps: [(1, .fretted(string: 3, fret: 3)),
                                                                  (5, .fretted(string: 2, fret: 5))])])
        let lines = TabDocument.song(title: "Slow Bend", artist: "", tab: tab).blocks[0].lines
        let strings = lines.filter { $0.kind == .strings }
        XCTAssertEqual(strings.map { String($0.text.prefix(2)) }, ["e|", "B|", "G|", "D|", "A|", "E|"])
        XCTAssertEqual(Set(strings.map(\.text.count)).count, 1)
        XCTAssertTrue(strings[3].text.contains("3"))
        XCTAssertTrue(strings[2].text.contains("5"))
        XCTAssertEqual(strings[0].text.filter { $0 == "|" }.count, 5, "the edges, and bars 2, 3 and 4")
    }

    func testARowWithNothingInItIsItsBarsAlone() {
        let tab = songTab(loops: [loop(0, 8, type: .riff, taps: [(1, .fretted(string: 3, fret: 3))])])
        let doc = TabDocument.song(title: "Slow Bend", artist: "", tab: tab)
        let gap = doc.blocks[1].lines
        XCTAssertEqual(gap.map(\.kind), [.ruler, .strings])
        XCTAssertFalse(gap[1].text.contains("-"))
    }

    func testWithoutAGridTheRulerAndHeadingsAreTimes() {
        XCTAssertEqual(TabDocument.clock(65), "1:05")
        XCTAssertEqual(TabDocument.clock(0), "0:00")
    }

    // MARK: - The files

    func testTheFileIsNamedForTheTab() {
        let source = TabDocument.Source.written(title: "Riff idea", notes: PieceNotes(labels: []), spelling: .flats)
        XCTAssertEqual(ExportedTabFile(source: source, format: .text).fileName, "Riff idea.txt")
        XCTAssertEqual(ExportedTabFile(source: source, format: .pdf).fileName, "Riff idea.pdf")
    }

    func testThePlainTextFileIsTheDocument() async throws {
        let notes = PieceNotes(labels: [.fretted(string: 5, fret: 0)], openMidi: guitar,
                               tuningLabel: "Guitar · Standard")
        let file = ExportedTabFile(source: .written(title: "Riff idea", notes: notes, spelling: .flats), format: .text)
        let url = try await file.written()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(url.lastPathComponent, "Riff idea.txt")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       TabDocument.written(title: "Riff idea", notes: notes, spelling: .flats).text)
    }

    @MainActor
    func testThePDFIsAPDFOnThePapersOfTheLocale() {
        let doc = written((0..<200).map { .fretted(string: $0 % 6, fret: $0 % 12) })
        let data = TabPDF.data(for: doc, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(String(bytes: data.prefix(5), encoding: .ascii), "%PDF-")
        XCTAssertEqual(TabPDF.pageSize(for: Locale(identifier: "en_US")).width, 612)
        XCTAssertEqual(TabPDF.pageSize(for: Locale(identifier: "en_GB")).width, 595.28, accuracy: 0.01)
    }
}
