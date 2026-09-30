import XCTest
@testable import Pocket

/// The song map's board (ADR 0232): where sections and rows break, which layer and lane each loop takes,
/// and what it holds. Pure arithmetic over plain values, the kind that breaks silently (AGENTS.md).
final class SongMapLayoutTests: XCTestCase {

    // MARK: - Fixtures

    /// 120 BPM in 4/4: a bar every 2 s, the first downbeat at 0.
    private func grid(duration: TimeInterval, firstDownbeat: TimeInterval = 0) -> SongMapInput.Grid {
        SongMapInput.Grid(downbeats: Array(stride(from: firstDownbeat, to: duration, by: 2)), barSeconds: 2)
    }

    private func marker(_ seconds: TimeInterval, _ label: String, section: Bool = true,
                        uid: UUID = UUID()) -> SongMapInput.MarkerInput {
        .init(uid: uid, seconds: seconds, label: label, startsSection: section)
    }

    private func loop(_ start: TimeInterval, _ end: TimeInterval, type: LoopType = .unset,
                      piece: PieceTranscription? = nil, handTagged: Bool = false,
                      uid: UUID = UUID()) -> SongMapInput.LoopInput {
        .init(uid: uid, name: "Loop", start: start, end: end, type: type, piece: piece, handTagged: handTagged)
    }

    private func build(duration: TimeInterval = 64, grid: SongMapInput.Grid? = nil,
                       markers: [SongMapInput.MarkerInput] = [],
                       loops: [SongMapInput.LoopInput] = []) -> SongMap {
        SongMapLayout.build(SongMapInput(duration: duration, grid: grid, markers: markers, loops: loops))
    }

    private let standard = [64, 59, 55, 50, 45, 40]

    // MARK: - Sections (D6, D7)

    func testNoSectionMarkersIsOneStrip() {
        let map = build(markers: [marker(10, "M1", section: false)])
        XCTAssertEqual(map.sections.count, 1)
        XCTAssertEqual(map.sections[0].heading, .none)
        XCTAssertEqual(map.sections[0].start, 0)
        XCTAssertEqual(map.sections[0].end, 64)
    }

    func testSectionMarkersCutTheSongAndALongLeadIsHeadedStart() {
        let verse = UUID(), chorus = UUID()
        let map = build(markers: [marker(40, "Chorus", uid: chorus), marker(8, "Verse", uid: verse)])
        XCTAssertEqual(map.sections.map(\.heading),
                       [.start, .marker(uid: verse, label: "Verse"), .marker(uid: chorus, label: "Chorus")])
        XCTAssertEqual(map.sections.map(\.start), [0, 8, 40])
        XCTAssertEqual(map.sections.map(\.end), [8, 40, 64])
    }

    func testAShortLeadFoldsIntoTheFirstSection() {
        let intro = UUID()
        let map = build(markers: [marker(0.4, "Intro", uid: intro)])
        XCTAssertEqual(map.sections.map(\.heading), [.marker(uid: intro, label: "Intro")])
        XCTAssertEqual(map.sections[0].start, 0, "the section starts the song, not 0.4 s in")
    }

    func testALeadOfExactlyTheShortestIsKept() {
        let map = build(markers: [marker(SongMapLayout.shortestLead, "Verse")])
        XCTAssertEqual(map.sections.first?.heading, .start)
    }

    func testTwoSectionMarkersAtOneTimeMakeOneSectionAndThePinKeepsTheOther() {
        let first = UUID(), second = UUID()
        let map = build(markers: [marker(8, "Verse", uid: first), marker(8.005, "Verse again", uid: second)])
        XCTAssertEqual(map.sections.map(\.heading).last, .marker(uid: first, label: "Verse"))
        XCTAssertEqual(map.sections.count, 2)
        XCTAssertEqual(map.sections.flatMap(\.rows).flatMap(\.pins).map(\.uid), [second])
    }

    func testMarkersOutsideTheSongAreIgnored() {
        let map = build(markers: [marker(-1, "Before"), marker(64, "At the end"), marker(90, "After")])
        XCTAssertEqual(map.sections.map(\.heading), [.none])
        XCTAssertTrue(map.sections.flatMap(\.rows).flatMap(\.pins).isEmpty)
    }

    func testAMarkerThatIsNotASectionIsAPinInItsRow() {
        let pin = UUID()
        let map = build(markers: [marker(20, "Tricky bend", section: false, uid: pin)])
        let rows = map.sections[0].rows
        XCTAssertEqual(rows[1].pins, [SongMap.Pin(uid: pin, time: 20, label: "Tricky bend")])
        XCTAssertTrue(rows[0].pins.isEmpty)
    }

    func testASongWithNoLengthHasNoSections() {
        XCTAssertTrue(build(duration: 0).sections.isEmpty)
    }

    // MARK: - Rows (D2, D5)

    func testWithoutAGridRowsAreSixteenSecondsAndMarksEveryFour() {
        let map = build(duration: 40)
        XCTAssertEqual(map.scale, .seconds)
        let rows = map.sections[0].rows
        XCTAssertEqual(rows.map(\.start), [0, 16, 32])
        XCTAssertEqual(rows.map(\.end), [16, 32, 40])
        XCTAssertEqual(rows.map(\.widthFraction), [1, 1, 0.5])
        XCTAssertEqual(rows[0].ticks.map(\.time), [0, 4, 8, 12])
        XCTAssertTrue(rows[0].ticks.allSatisfy { $0.bar == nil })
    }

    func testSecondsMarksFallOnSongTimeNotTheSectionsStart() {
        let map = build(duration: 40, markers: [marker(5, "Verse")])
        XCTAssertEqual(map.sections[1].rows[0].ticks.map(\.time), [8, 12, 16, 20])
    }

    func testWithAGridRowsAreEightBarsNumberedFromTheFirstDownbeat() {
        let map = build(duration: 40, grid: grid(duration: 40))
        XCTAssertEqual(map.scale, .bars)
        let rows = map.sections[0].rows
        XCTAssertEqual(rows.map(\.start), [0, 16, 32])
        XCTAssertEqual(rows[1].ticks.map(\.bar), [9, 10, 11, 12, 13, 14, 15, 16])
        XCTAssertEqual(rows[2].widthFraction, 0.5)
        XCTAssertEqual(map.sections[0].bars, 1...20)
    }

    func testAPickupRidesInTheFirstRow() {
        // The 1 is at 1.5 s: the half-bar before it is a pickup, not a row of its own.
        let map = build(duration: 40, grid: grid(duration: 40, firstDownbeat: 1.5))
        let rows = map.sections[0].rows
        XCTAssertEqual(rows[0].start, 0)
        XCTAssertEqual(rows[0].end, 17.5, "the pickup plus eight bars")
        XCTAssertEqual(rows[0].widthFraction, 1, "a row a little over full draws full")
        XCTAssertEqual(rows[0].ticks.first?.bar, 1)
    }

    func testRowsRestartAtEachSection() {
        let map = build(duration: 64, grid: grid(duration: 64), markers: [marker(10, "Verse")])
        XCTAssertEqual(map.sections[0].rows.map(\.end), [10])
        XCTAssertEqual(map.sections[1].rows.map(\.start), [10, 26, 42, 58])
        XCTAssertEqual(map.sections[1].bars, 6...32)
    }

    func testAnEmptyGridDrawsSeconds() {
        let map = build(grid: SongMapInput.Grid(downbeats: [], barSeconds: 2))
        XCTAssertEqual(map.scale, .seconds)
    }

    func testPositionAcrossARow() {
        let row = build(duration: 40).sections[0].rows[1]
        XCTAssertEqual(row.position(of: 20), 0.25)
    }

    // MARK: - Layers (D3)

    func testAPieceNamedInChordsIsOnTheChordsLayer() {
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .chord(root: 9, suffix: "m7")),
                                              .init(seconds: 3)])
        XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, type: .lick, piece: piece)), .chords,
                       "the names decide, not the loop's type")
    }

    func testAShapeThatSpellsAChordIsOnTheChordsLayer() {
        // An open A minor on the neck: x02210.
        let shape: [FrettedNote] = [.init(string: 0, fret: 0), .init(string: 1, fret: 1),
                                    .init(string: 2, fret: 2), .init(string: 3, fret: 2),
                                    .init(string: 4, fret: 0)]
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .fretted(shape, into: nil))],
                                       openMidi: standard)
        XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, piece: piece)), .chords)
    }

    func testOneNoteAmongChordsPutsThePieceWithTheNotes() {
        let piece = PieceTranscription(taps: [.init(seconds: 1, label: .chord(root: 9, suffix: "m")),
                                              .init(seconds: 2, label: .pitchClass(4))])
        XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, type: .chords, piece: piece)), .notes)
    }

    func testWithNoNamesTheTypeDecides() {
        let counted = PieceTranscription(taps: [.init(seconds: 1), .init(seconds: 2)])
        XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, type: .chords, piece: counted)), .chords)
        XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, type: .chords)), .chords)
        for type in [LoopType.unset, .lick, .riff, .passage] {
            XCTAssertEqual(SongMapLayout.layer(of: loop(0, 4, type: type)), .notes, "\(type)")
        }
    }

    func testReadsAsChord() {
        XCTAssertTrue(PieceLabel.chord(root: 0, suffix: "").readsAsChord(openMidi: []))
        XCTAssertFalse(PieceLabel.pitchClass(0).readsAsChord(openMidi: []))
        XCTAssertFalse(PieceLabel.fretted(string: 1, fret: 5).readsAsChord(openMidi: standard))
    }

    // MARK: - Content (D4)

    func testWhatALoopHolds() {
        let piece = PieceTranscription(taps: [.init(seconds: 1)])
        XCTAssertEqual(SongMapLayout.content(of: loop(0, 4)), .empty)
        XCTAssertEqual(SongMapLayout.content(of: loop(0, 4, handTagged: true)), .handTagged)
        XCTAssertEqual(SongMapLayout.content(of: loop(0, 4, piece: piece, handTagged: true)), .piece(piece),
                       "a saved piece is what's drawn, whatever the notes say")
    }

    // MARK: - Lanes (D2)

    func testOverlappingPiecesInOneLayerTakeASecondLane() {
        let first = UUID(), second = UUID(), third = UUID()
        let pieces = SongMapLayout.placePieces([loop(0, 10, uid: first), loop(5, 12, uid: second),
                                                loop(10, 14, uid: third)], duration: 64)
        let lanes = Dictionary(uniqueKeysWithValues: pieces.map { ($0.uid, $0.lane) })
        XCTAssertEqual(lanes[first], 0)
        XCTAssertEqual(lanes[second], 1)
        XCTAssertEqual(lanes[third], 0, "a piece starting where another ends reuses its lane")
    }

    func testLayersHaveLanesOfTheirOwn() {
        let chords = UUID(), notes = UUID()
        let pieces = SongMapLayout.placePieces([loop(0, 10, type: .chords, uid: chords),
                                                loop(2, 6, type: .lick, uid: notes)], duration: 64)
        XCTAssertEqual(pieces.map(\.lane), [0, 0], "a lick over its chords doesn't overlap them")
    }

    func testTheShorterOfTwoStartingTogetherTakesTheFirstLane() {
        let short = UUID(), long = UUID(), next = UUID()
        let pieces = SongMapLayout.placePieces([loop(0, 12, uid: long), loop(0, 4, uid: short),
                                                loop(4, 8, uid: next)], duration: 64)
        XCTAssertEqual(pieces.first { $0.uid == short }?.lane, 0)
        XCTAssertEqual(pieces.first { $0.uid == long }?.lane, 1, "a loop joining pieces sits under them (D11)")
        XCTAssertEqual(pieces.first { $0.uid == next }?.lane, 0, "and the next piece keeps to the first lane")
    }

    func testEveryRowHasAChordsAndANotesLaneAndExtraLanesOnlyWhereNeeded() {
        let map = build(duration: 48, loops: [loop(0, 10), loop(5, 12)])
        let rows = map.sections[0].rows
        XCTAssertEqual(rows[0].lanes.map(\.id), ["0-0", "1-0", "1-1"])
        XCTAssertEqual(rows[1].lanes.map(\.id), ["0-0", "1-0"])
    }

    func testLoopsOutsideTheSongOrWithNoLengthAreLeftOut() {
        let pieces = SongMapLayout.placePieces([loop(70, 80), loop(5, 5), loop(60, 70)], duration: 64)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(pieces[0].end, 64, "a loop past the end is cut at the end")
    }

    // MARK: - Placement across rows

    func testAPieceCrossingARowIsDrawnInBothWithItsCutEdgesMarked() throws {
        let uid = UUID()
        let piece = PieceTranscription(taps: [.init(seconds: 12), .init(seconds: 15.9), .init(seconds: 16),
                                              .init(seconds: 19)])
        let map = build(duration: 48, loops: [loop(10, 20, piece: piece, uid: uid)])
        let rows = map.sections[0].rows
        let first = try XCTUnwrap(rows[0].lanes.first { $0.layer == .notes }?.placements.first)
        let second = try XCTUnwrap(rows[1].lanes.first { $0.layer == .notes }?.placements.first)
        XCTAssertEqual([first.start, first.end], [10, 16])
        XCTAssertEqual([first.continuesBefore, first.continuesAfter], [false, true])
        XCTAssertEqual(first.taps, [12, 15.9])
        XCTAssertEqual([second.start, second.end], [16, 20])
        XCTAssertEqual([second.continuesBefore, second.continuesAfter], [true, false])
        XCTAssertEqual(second.taps, [16, 19], "a tap on the break belongs to the row it starts")
    }

    func testTapsOutsideTheLoopAreNotDrawn() throws {
        // The loop was narrowed after it was counted: the taps still hold their song time.
        let piece = PieceTranscription(taps: [.init(seconds: 1), .init(seconds: 5), .init(seconds: 9)])
        let map = build(duration: 48, loops: [loop(4, 8, piece: piece)])
        let placed = try XCTUnwrap(map.sections[0].rows[0].lanes.first { $0.layer == .notes }?.placements.first)
        XCTAssertEqual(placed.taps, [5])
    }

    func testAPiecesBarsRunFromTheBarItStartsInToTheBarItEndsIn() throws {
        let uid = UUID()
        let map = build(duration: 40, grid: grid(duration: 40), loops: [loop(3, 8, uid: uid)])
        XCTAssertEqual(map.bars(of: try XCTUnwrap(map.pieces[uid])), 2...4,
                       "3 s is in bar 2; a piece ending on bar 5's line ends in bar 4")
    }

    func testAPieceHasNoBarsInSecondsScale() throws {
        let uid = UUID()
        let map = build(duration: 40, loops: [loop(3, 8, uid: uid)])
        XCTAssertNil(map.bars(of: try XCTUnwrap(map.pieces[uid])))
    }

    func testAPieceIsNeverSnapped() throws {
        let map = build(duration: 40, grid: grid(duration: 40), loops: [loop(3.3, 7.7)])
        let placed = try XCTUnwrap(map.sections[0].rows[0].lanes.first { $0.layer == .notes }?.placements.first)
        XCTAssertEqual([placed.start, placed.end], [3.3, 7.7])
    }
}
