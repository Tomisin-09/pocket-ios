import XCTest
@testable import Pocket

/// Picking on the song map (ADR 0308 D1–D3, D8): what a section's name shows and picks, what watching the
/// picks plays and lights, what stays dark, and what the bar and the sheet call it. Pure arithmetic over
/// plain values (AGENTS.md).
final class SongMapPickingTests: SongMapSlice3Case {

    /// Verse 8–24, Solo 24–40, Chorus 40–56, Outro 56–64, with a *Start* before the verse.
    private func fourSections() -> [SongMapInput.MarkerInput] {
        [marker(8, "Verse"), marker(24, "Solo"), marker(40, "Chorus"), marker(56, "Outro")]
    }

    /// A piece placed on the neck: one fretted note at each of `taps`.
    private func placed(_ taps: [TimeInterval]) -> PieceTranscription {
        PieceTranscription(taps: taps.map { .init(seconds: $0, label: .fretted(string: 2, fret: 5)) },
                           openMidi: Instrument.guitar.standardTuning.engineOpenMidi)
    }

    private func notes(_ start: TimeInterval, _ end: TimeInterval, _ name: String, uid: UUID = UUID(),
                       onTheNeck: Bool = true) -> SongMapInput.LoopInput {
        loop(start, end, type: .riff, piece: onTheNeck ? placed([start + 0.5]) : nil, name: name, uid: uid)
    }

    /// A chords piece with an open C placed on the neck: a shape that spells a chord puts it in the chords
    /// layer (ADR 0232 D3). A single note there would read as notes, whatever the loop's type.
    private func chords(_ start: TimeInterval, _ end: TimeInterval, _ name: String,
                        uid: UUID = UUID()) -> SongMapInput.LoopInput {
        let openC = PieceLabel.fretted([FrettedNote(string: 4, fret: 3), FrettedNote(string: 3, fret: 2),
                                        FrettedNote(string: 2, fret: 0), FrettedNote(string: 1, fret: 1),
                                        FrettedNote(string: 0, fret: 0)], into: nil)
        let piece = PieceTranscription(taps: [.init(seconds: start + 0.5, label: openC)],
                                       openMidi: Instrument.guitar.standardTuning.engineOpenMidi)
        return loop(start, end, type: .chords, piece: piece, name: name, uid: uid)
    }

    private func watch(_ picked: [UUID], _ map: SongMap) throws -> SongMapPicking.Watch {
        try XCTUnwrap(SongMapPicking.watch(Set(picked), in: map))
    }

    // MARK: - A section's name (D1)

    func testASectionsNameShowsHowMuchOfItIsPicked() throws {
        let (riff, lick, hook) = (UUID(), UUID(), UUID())
        let map = build(markers: verseAndChorus(), loops: [notes(8, 12, "Riff", uid: riff),
                                                           notes(12, 16, "Lick", uid: lick),
                                                           notes(40, 44, "Hook", uid: hook)])
        let verse = try section(map, "Verse")
        XCTAssertEqual(SongMapPicking.mark(of: verse, picked: [], in: map), .empty)
        XCTAssertEqual(SongMapPicking.mark(of: verse, picked: [riff, hook], in: map), .part)
        XCTAssertEqual(SongMapPicking.mark(of: verse, picked: [riff, lick], in: map), .all)
        let start = try XCTUnwrap(map.sections.first)
        XCTAssertEqual(SongMapPicking.mark(of: start, picked: [riff, lick, hook], in: map), .empty,
                       "a section with no pieces shows the empty circle")
    }

    func testTappingASectionsNamePicksItAllThenLetsItAllGo() throws {
        let (riff, lick, hook) = (UUID(), UUID(), UUID())
        let map = build(markers: verseAndChorus(), loops: [notes(8, 12, "Riff", uid: riff),
                                                           notes(12, 16, "Lick", uid: lick),
                                                           notes(40, 44, "Hook", uid: hook)])
        let verse = try section(map, "Verse")
        let all = SongMapPicking.toggle(verse, picked: [riff, hook], in: map)
        XCTAssertEqual(all, [riff, lick, hook], "some picked: a tap picks the rest")
        XCTAssertEqual(SongMapPicking.toggle(verse, picked: all, in: map), [hook],
                       "all picked: a tap lets the section go and keeps the other picks")
    }

    func testAPieceStartingABeatEarlyBelongsToTheSectionItPlaysIn() throws {
        let early = UUID()
        let map = build(markers: verseAndChorus(), loops: [notes(7, 14, "Pickup", uid: early)])
        XCTAssertEqual(SongMapPicking.pieces(in: try section(map, "Verse"), of: map), [early])
        XCTAssertTrue(SongMapPicking.pieces(in: try XCTUnwrap(map.sections.first), of: map).isEmpty,
                      "not the Start it begins in")
    }

    // MARK: - What it's called (D2)

    func testWholeSectionsInARowAreCalledByTheirNames() throws {
        let (verse, solo, chorus, outro) = (UUID(), UUID(), UUID(), UUID())
        let map = build(markers: fourSections(), loops: [notes(8, 12, "Riff", uid: verse),
                                                         notes(24, 28, "Solo 1", uid: solo),
                                                         notes(40, 44, "Hook", uid: chorus),
                                                         notes(56, 60, "Tag", uid: outro)])
        XCTAssertEqual(try watch([solo], map).title, "Solo", "one whole section is its name")
        XCTAssertEqual(try watch([verse, solo], map).title, "Verse and Solo")
        XCTAssertEqual(try watch([verse, solo, chorus], map).title, "Verse to Chorus")
        XCTAssertEqual(try watch([verse, chorus], map).title, "Riff and Hook",
                       "two sections apart aren't in a row: the pieces are named")
    }

    func testASectionWithNoPiecesBetweenTwoPickedOnesKeepsTheRow() throws {
        let (verse, chorus) = (UUID(), UUID())
        let map = build(markers: fourSections(), loops: [notes(8, 12, "Riff", uid: verse),
                                                         notes(40, 44, "Hook", uid: chorus)])
        XCTAssertEqual(try watch([verse, chorus], map).title, "Verse to Chorus", "the empty Solo plays between")
    }

    func testOtherwiseThePiecesAreNamedAndFourOrMoreAsARange() throws {
        let uids = (0..<4).map { _ in UUID() }
        let map = build(markers: verseAndChorus(), loops: (0..<4).map {
            notes(8 + Double($0) * 4, 12 + Double($0) * 4, "Solo \($0 + 3)", uid: uids[$0])
        } + [notes(30, 34, "Fill")])
        XCTAssertEqual(try watch([uids[1]], map).title, "Solo 4")
        XCTAssertEqual(try watch([uids[1], uids[2]], map).title, "Solo 4 and Solo 5")
        XCTAssertEqual(try watch([uids[2], uids[0], uids[1]], map).title, "Solo 3, Solo 4 and Solo 5",
                       "in the order they play, not the order picked")
        XCTAssertEqual(try watch(uids, map).title, "Solo 3 to Solo 6")
    }

    // MARK: - What it plays (D2)

    func testItPlaysFromTheFirstPickToTheEndOfTheLastsRepeats() throws {
        let (riff, lick) = (UUID(), UUID())
        let map = build(grid: grid(), loops: [
            notes(8, 12, "Riff", uid: riff),
            loop(16, 20, type: .riff, piece: placed([16.5]), repeats: true, name: "Lick", uid: lick)
        ])
        let picks = try watch([lick, riff], map)
        XCTAssertEqual(picks.start, 8)
        XCTAssertEqual(picks.end, 64, "the lick repeats to the end of the song, which has no sections")
        XCTAssertEqual(picks.bars, 5...32)
        XCTAssertEqual(picks.barLine, "Riff and Lick · Bars 5–32")
        XCTAssertEqual(picks.sheetLine, "Bars 5–32 · starts at 0:08")
        XCTAssertEqual(picks.playLabel, "Play from bar 5")
    }

    func testTheBarCounterCountsFromTheSongsFirstBar() throws {
        let riff = UUID()
        let map = build(grid: grid(), loops: [notes(8, 12, "Riff", uid: riff)])
        let picks = try watch([riff], map)
        XCTAssertEqual(picks.bar(at: 8), 5)
        XCTAssertEqual(picks.bar(at: 9.9), 5)
        XCTAssertEqual(picks.bar(at: 10), 6)
        XCTAssertEqual(picks.bars, 5...6)
        XCTAssertEqual(picks.place, "Bars 5–6")
    }

    func testInSecondsThePlaceIsTimesAndThereIsNoBarToCount() throws {
        let riff = UUID()
        let map = build(duration: 120, loops: [notes(68, 80, "Riff", uid: riff)])
        let picks = try watch([riff], map)
        XCTAssertNil(picks.bars)
        XCTAssertEqual(picks.place, "1:08–1:20")
        XCTAssertEqual(picks.sheetLine, "Starts at 1:08")
        XCTAssertEqual(picks.playLabel, "Play from 1:08")
        XCTAssertNil(picks.bar(at: 70))
    }

    func testNothingPickedIsNothingToWatch() {
        let map = build(loops: [notes(8, 12, "Riff")])
        XCTAssertNil(SongMapPicking.watch([], in: map))
        XCTAssertNil(SongMapPicking.watch([UUID()], in: map), "a loop that's gone isn't counted")
    }

    // MARK: - Only what's picked lights (D3, D4)

    func testAnUnpickedNotesPieceInTheStretchPlaysAndStaysDark() throws {
        let (solo4, solo5) = (UUID(), UUID())
        let map = build(loops: [notes(8, 16, "Solo 4", uid: solo4), notes(12, 20, "Solo 5", uid: solo5)])
        let picks = try watch([solo4], map)
        XCTAssertEqual(picks.lit, [solo4])
        XCTAssertEqual(picks.dark, [.init(name: "Solo 5", start: 12, reach: 16)], "dark only inside the stretch")
        XCTAssertEqual(picks.darkLine, "Solo 5 isn't picked, so it stays dark.")
        XCTAssertNil(picks.notPicked(at: 10))
        XCTAssertEqual(picks.notPicked(at: 13), "Not picked: Solo 5")
    }

    func testWithNotesPickedTheChordsUnderThemNeverLightAndArentDark() throws {
        let (riff, changes, other) = (UUID(), UUID(), UUID())
        let map = build(loops: [notes(8, 16, "Riff", uid: riff), chords(8, 16, "Changes", uid: changes),
                                chords(12, 20, "Turnaround", uid: other)])
        XCTAssertEqual(map.pieces[changes]?.layer, .chords, "the fixture's chords are in the chords layer")
        let picks = try watch([riff, changes], map)
        XCTAssertEqual(picks.lit, [riff], "under notes, a chord colours and is never drawn")
        XCTAssertTrue(picks.dark.isEmpty, "an unpicked chord under notes wouldn't have lit")
    }

    func testWithOnlyChordsPickedTheyLightAndAnUnpickedPieceOfEitherKindStaysDark() throws {
        let (changes, riff, turnaround) = (UUID(), UUID(), UUID())
        let map = build(loops: [chords(8, 16, "Changes", uid: changes), notes(10, 14, "Riff", uid: riff),
                                chords(12, 20, "Turnaround", uid: turnaround)])
        XCTAssertEqual(map.pieces[turnaround]?.layer, .chords)
        let picks = try watch([changes], map)
        XCTAssertEqual(picks.lit, [changes])
        XCTAssertEqual(picks.dark.map(\.name), ["Riff", "Turnaround"])
    }

    func testAPieceWithNothingOnTheNeckIsntCalledDark() throws {
        let riff = UUID()
        let map = build(loops: [notes(8, 16, "Riff", uid: riff), notes(10, 14, "Not counted", onTheNeck: false)])
        XCTAssertNil(try watch([riff], map).darkLine)
    }

    func testTheDarkLineNamesUpToThreeThenCounts() {
        XCTAssertNil(SongMapPicking.darkLine([]))
        XCTAssertEqual(SongMapPicking.darkLine(["Solo 5", "Fill"]), "Solo 5 and Fill aren't picked, so they stay dark.")
        XCTAssertEqual(SongMapPicking.darkLine(["A", "B", "C"]), "A, B and C aren't picked, so they stay dark.")
        XCTAssertEqual(SongMapPicking.darkLine(["A", "B", "C", "D"]),
                       "4 pieces in it aren't picked, so they stay dark.")
    }
}
