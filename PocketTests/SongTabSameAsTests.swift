import XCTest
@testable import Pocket

/// A section that's the same as an earlier one has the earlier one's bars written out in the tab (ADR 0232
/// D19): where they land, how far they run, and what they leave to the section's own pieces.
final class SongTabSameAsTests: SongMapSlice3Case {

    private let verse = UUID()
    private let chorus = UUID()

    /// Verse 1 8–24 (8 bars), a Chorus 24–40, and Verse 2 from `again` to the end, the same as Verse 1.
    private func tab(again: TimeInterval = 40, bars: Bool = true, loops: [SongMapInput.LoopInput]) -> SongTab {
        let markers = [marker(8, "Verse 1", uid: verse), marker(24, "Chorus", uid: chorus),
                       marker(again, "Verse 2", sameAs: verse)]
        return SongTabLayout.build(build(grid: bars ? grid() : nil, markers: markers, loops: loops), spelling: .flats)
    }

    private func verseTwo(_ tab: SongTab) throws -> SongTab.Section {
        try XCTUnwrap(tab.sections.last)
    }

    /// Gm7 C7 Gm7 D7, a bar each, in Verse 1's first four bars.
    private func changes(uid: UUID = UUID(), repeats: Bool = false) -> SongMapInput.LoopInput {
        let names: [(Int, String)] = [(7, "m7"), (0, "7"), (7, "m7"), (2, "7")]
        let taps = names.enumerated().map { index, chord in
            PieceTranscription.Tap(seconds: 8 + Double(index) * 2, label: .chord(root: chord.0, suffix: chord.1))
        }
        return loop(8, 16, piece: PieceTranscription(taps: taps), repeats: repeats, uid: uid)
    }

    func testTheEarlierSectionsBarsAreWrittenOutBarForBar() throws {
        let uid = UUID()
        let rows = try verseTwo(tab(loops: [changes(uid: uid)])).rows
        XCTAssertEqual(rows.map(\.start), [40, 48, 56])
        let line = try XCTUnwrap(rows[0].lines.first)
        XCTAssertTrue(line.isSameAs)
        XCTAssertEqual(line.columns.map(\.name), ["Gm7", "C7", "Gm7", "D7"])
        XCTAssertEqual(line.columns.map(\.time), [40, 42, 44, 46])
        XCTAssertEqual(rows[0].pieces, [uid], "the pieces that drew it are Verse 1's")
        XCTAssertEqual(rows[0].sourceStart, 8, "tapping it goes to Verse 1, where they are")
        XCTAssertEqual(rows[1].lines, [], "Verse 1's second row is empty, so this one is")
        XCTAssertEqual(rows[2].lines, [], "Verse 2 is longer: past Verse 1's end there's nothing to write")
    }

    func testAMarkerSetAHairOffTheOneMovesNoChord() throws {
        let line = try XCTUnwrap(verseTwo(tab(again: 39.8, loops: [changes()])).rows.first?.lines.first)
        XCTAssertEqual(line.columns.map(\.time), [40, 42, 44, 46], "from the 1 nearest each section's start")
    }

    func testWithoutBarsItsWrittenMarkerToMarker() throws {
        let line = try XCTUnwrap(verseTwo(tab(again: 39.8, bars: false, loops: [changes()])).rows.first?.lines.first)
        XCTAssertEqual(line.columns.count, 4)
        for (time, expected) in zip(line.columns.map(\.time), [39.8, 41.8, 43.8, 45.8]) {
            XCTAssertEqual(time, expected, accuracy: 0.000_001)
        }
    }

    func testAShorterSectionIsWrittenOnlyAsFarAsItRuns() throws {
        // Verse 2 is 4 s: two bars of Verse 1's four.
        let markers = [marker(8, "Verse 1", uid: verse), marker(24, "Verse 2", sameAs: verse), marker(28, "Outro")]
        let tab = SongTabLayout.build(build(grid: grid(), markers: markers, loops: [changes()]), spelling: .flats)
        let section = try XCTUnwrap(tab.sections.first { $0.start == 24 })
        XCTAssertEqual(section.rows.flatMap(\.lines).flatMap(\.columns).map(\.name), ["Gm7", "C7"])
    }

    func testTheSectionsOwnPiecesDrawOnTheirOwnLinesUnderIt() throws {
        let lick = PieceTranscription(taps: [.init(seconds: 45, label: .fretted(string: 1, fret: 5))],
                                      openMidi: standard)
        let turnaround = PieceTranscription(taps: [.init(seconds: 46.5, label: .chord(root: 9, suffix: "7"))])
        let rows = try verseTwo(tab(loops: [changes(), loop(44, 46, type: .lick, piece: lick, name: "Lick"),
                                            loop(46, 48, piece: turnaround, name: "Turn")])).rows
        let lines = rows[0].lines
        XCTAssertEqual(lines.map(\.layer), [.chords, .chords, .notes])
        XCTAssertEqual(lines.map(\.isSameAs), [true, false, false], "Verse 1's chords first, then its own")
        XCTAssertEqual(lines[1].columns.map(\.name), ["A7"])
        XCTAssertEqual(Set(lines.map(\.id)).count, 3, "a written line and its own on one lane stay apart")
        XCTAssertNil(rows[0].sourceStart, "it has pieces of its own, so it goes to its own stretch")
    }

    func testARepeatInTheEarlierSectionIsWrittenOutToo() throws {
        let rows = try verseTwo(tab(loops: [changes(repeats: true)])).rows
        let columns = rows.prefix(2).flatMap(\.lines).flatMap(\.columns)
        XCTAssertEqual(columns.filter { $0.mark == .repeats(2) }.map(\.time), [48], "Verse 1's sign, bar for bar")
        XCTAssertEqual(columns.filter { $0.mark != .repeats(2) }.map(\.time), [40, 42, 44, 46, 48, 50, 52, 54])
    }

    func testOnlyTheEarlierSectionsOwnStretchIsWritten() throws {
        // Verse 1's changes play on through the chorus, and stop where Verse 2 starts.
        let rows = try verseTwo(tab(loops: [loop(8, 16, piece: changes().piece, repeats: true, to: .through(chorus))]))
            .rows
        XCTAssertEqual(rows[1].lines.first?.columns.map(\.time), [48, 48, 50, 52, 54], "the sign, then a pass")
        XCTAssertEqual(rows[2].lines, [], "the chorus's passes are the chorus's, not Verse 1's")
    }

    func testARepeatPlayingOnThroughBothIsntWrittenTwice() throws {
        let rows = try verseTwo(tab(loops: [
            loop(8, 16, piece: changes().piece, repeats: true, to: .songEnd)
        ])).rows
        XCTAssertEqual(rows[0].lines.map(\.isSameAs), [false], "it draws in Verse 2 as itself, once")
        XCTAssertEqual(rows[0].lines.first?.columns.map(\.time), [40, 42, 44, 46])
    }
}
