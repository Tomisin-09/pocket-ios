import XCTest
@testable import Pocket

/// *Put it together* (ADR 0232 D11): which selections make a shape, and the routine each shape makes. Pure
/// arithmetic over plain values, the kind that breaks silently (AGENTS.md).
final class SongMapTogetherTests: SongMapSlice3Case {

    private func notes(_ start: TimeInterval, _ end: TimeInterval, _ name: String = "Riff",
                       uid: UUID = UUID()) -> SongMapInput.LoopInput {
        loop(start, end, type: .riff, name: name, uid: uid)
    }

    private func read(_ selected: [UUID], _ loops: [SongMapInput.LoopInput],
                      markers: [SongMapInput.MarkerInput] = []) -> SongMapTogether.Reading {
        SongMapTogether.read(Set(selected), in: build(markers: markers, loops: loops))
    }

    // MARK: - Which shape

    func testOnePieceOrNoneIsTooFew() {
        let first = UUID()
        XCTAssertEqual(read([first], [notes(8, 12, uid: first)]), .tooFew)
        XCTAssertEqual(read([], [notes(8, 12)]), .tooFew)
        XCTAssertEqual(read([UUID(), first], [notes(8, 12, uid: first)]), .tooFew, "a loop that's gone isn't counted")
    }

    func testPiecesOnOneLayerAreInARowInTheOrderTheyPlay() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        let loops = [notes(16, 20, uid: third), notes(8, 12, uid: first), notes(12, 16, uid: second)]
        XCTAssertEqual(read([third, first, second], loops), .shape(.inARow([first, second, third])))
    }

    func testALoopDrawnAHairLongStillCountsAsNextToItsNeighbour() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(read([first, second], [notes(8, 13, uid: first), notes(12, 16, uid: second)]),
                       .shape(.inARow([first, second])), "a second over is a hair")
        XCTAssertEqual(read([first, second], [notes(8, 13.5, uid: first), notes(12, 16, uid: second)]),
                       .overlapping, "a second and a half over is two pieces at once")
    }

    func testAPieceInsideAnotherOrOnTopOfItIsntInARow() {
        let (outer, inner) = (UUID(), UUID())
        XCTAssertEqual(read([outer, inner], [notes(8, 16, uid: outer), notes(10, 14, uid: inner)]), .overlapping)
        XCTAssertEqual(read([outer, inner], [notes(8, 16, uid: outer), notes(8, 16, uid: inner)]), .overlapping)
        XCTAssertEqual(read([outer, inner], [notes(8, 16, uid: outer), notes(8, 18, uid: inner)]), .overlapping,
                       "starting together isn't following on")
    }

    func testTwoShortPiecesStartingTogetherArentInARow() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(read([first, second], [notes(8, 8.5, uid: first), notes(8, 9, uid: second)]), .overlapping,
                       "shorter than the second's allowance, but still two at once")
    }

    func testAPieceInsideTheLastSecondOfAnotherIsntInARow() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(read([first, second], [notes(8, 16, uid: first), notes(15.5, 16, uid: second)]),
                       .overlapping, "it ends no later, so there's nothing to join it to")
    }

    func testAGapBetweenPiecesIsAllowed() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(read([first, second], [notes(8, 10, uid: first), notes(14, 16, uid: second)]),
                       .shape(.inARow([first, second])))
    }

    func testChordsPiecesAreInARowToo() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(read([first, second], [loop(8, 16, uid: first), loop(16, 24, uid: second)]),
                       .shape(.inARow([first, second])))
    }

    func testALineAndTheChordsUnderItAreALineOverItsChords() {
        let (chords, line) = (UUID(), UUID())
        XCTAssertEqual(read([line, chords], [loop(8, 16, uid: chords), notes(10, 12, uid: line)]),
                       .shape(.lineOverChords(line: line, chords: chords)))
    }

    func testChordsThatPlayUnderTheLineOnlyThroughTheirRepeatsCount() {
        let (chords, line) = (UUID(), UUID())
        let markers = [marker(8, "Verse"), marker(40, "Chorus")]
        XCTAssertEqual(read([line, chords], [loop(8, 16, repeats: true, uid: chords), notes(20, 22, uid: line)],
                            markers: markers),
                       .shape(.lineOverChords(line: line, chords: chords)))
        XCTAssertEqual(read([line, chords], [loop(8, 16, uid: chords), notes(20, 22, uid: line)], markers: markers),
                       .notUnder)
    }

    func testChordsThatOnlyTouchTheLineDontPlayUnderIt() {
        let (chords, line) = (UUID(), UUID())
        XCTAssertEqual(read([line, chords], [loop(8, 16, uid: chords), notes(16, 18, uid: line)]), .notUnder)
    }

    func testThreePiecesAcrossBothLayersAreMixed() {
        let (chords, first, second) = (UUID(), UUID(), UUID())
        let loops = [loop(8, 16, uid: chords), notes(8, 12, uid: first), notes(12, 16, uid: second)]
        XCTAssertEqual(read([chords, first, second], loops), .mixed)
    }

    // MARK: - The routine

    private func plan(_ shape: SongMapTogether.Shape, _ loops: [SongMapInput.LoopInput], title: String = "Slow Bend",
                      existing: [String] = []) -> SongMapTogether.Plan {
        SongMapTogether.plan(shape, in: build(loops: loops), songTitle: title, existingNames: existing)
    }

    func testInARowPractisesEachPieceThenTheStretchFromTheFirstToIt() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        let loops = [notes(8, 12, "Verse riff", uid: first), notes(12, 16, "Verse riff 2", uid: second),
                     notes(16, 20, "Verse riff 3", uid: third)]
        let made = plan(.inARow([first, second, third]), loops)
        XCTAssertEqual(made.blocks, [.practise(.piece(first)), .practise(.piece(second)), .practise(.join(0)),
                                     .practise(.piece(third)), .practise(.join(1))])
        XCTAssertEqual(made.joins, [
            SongMapTogether.Join(parts: [first, second], name: "Verse riff to Verse riff 2", start: 8, end: 16,
                                 layer: .notes),
            SongMapTogether.Join(parts: [first, second, third], name: "Verse riff to Verse riff 3", start: 8, end: 20,
                                 layer: .notes)
        ])
        XCTAssertEqual(made.name, "Slow Bend: Verse riff to Verse riff 3")
        XCTAssertEqual(made.practised, [first, second, third], "each needs a command tempo")
        XCTAssertNil(made.backing)
    }

    func testAJoinedLoopsNameIsClearOfTheSongsLoopsAndOfEachOther() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        let loops = [notes(8, 12, "A", uid: first), notes(12, 16, "B", uid: second), notes(16, 20, "B", uid: third)]
        let made = plan(.inARow([first, second, third]), loops, existing: ["A to B"])
        XCTAssertEqual(made.joins.map(\.name), ["A to B 2", "A to B 3"])
    }

    func testAJoinedStretchOfChordsStaysOnTheChordsLayer() {
        let (first, second) = (UUID(), UUID())
        let made = plan(.inARow([first, second]), [loop(8, 16, uid: first), loop(16, 24, uid: second)])
        XCTAssertEqual(made.joins.map(\.layer), [.chords])
    }

    func testALineOverItsChordsPractisesTheLineThenPlaysTheChordsAsABacking() {
        let (chords, line) = (UUID(), UUID())
        let loops = [loop(8, 16, name: "Intro chords", uid: chords), notes(10, 12, "Intro lick", uid: line)]
        let made = plan(.lineOverChords(line: line, chords: chords), loops)
        XCTAssertEqual(made.blocks, [.practise(.piece(line)), .improvise(chords)])
        XCTAssertEqual(made.joins, [])
        XCTAssertEqual(made.practised, [line], "the backing holds one tempo, and needs none")
        XCTAssertEqual(made.backing, chords)
        XCTAssertEqual(made.name, "Slow Bend: Intro lick over Intro chords")
        XCTAssertEqual(plan(.lineOverChords(line: line, chords: chords), loops, title: "").name,
                       "Intro lick over Intro chords")
    }

    func testTheBlocksRunTheJoinedLoopsOnceTheyreMade() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        let loops = [notes(8, 12, uid: first), notes(12, 16, uid: second), notes(16, 20, uid: third)]
        let made = plan(.inARow([first, second, third]), loops)
        let (firstJoin, secondJoin) = (UUID(), UUID())
        XCTAssertEqual(SongMapTogether.runs(made, joined: [firstJoin, secondJoin]).map(\.uid),
                       [first, second, firstJoin, third, secondJoin])
        XCTAssertEqual(Set(SongMapTogether.runs(made, joined: [firstJoin]).map(\.mode)), [.trainer])
        XCTAssertEqual(SongMapTogether.runs(made, joined: [firstJoin]).map(\.uid), [first, second, firstJoin, third],
                       "a joined loop that wasn't made is left out")

        let (chords, line) = (UUID(), UUID())
        let over = plan(.lineOverChords(line: line, chords: chords),
                        [loop(8, 16, uid: chords), notes(10, 12, uid: line)])
        XCTAssertEqual(SongMapTogether.runs(over, joined: []),
                       [.init(uid: line, mode: .trainer), .init(uid: chords, mode: .improvise)])
    }

    // MARK: - What the bar says

    func testTheBarSaysWhatTheSelectionMakesOrWhyItCant() {
        let (chords, line) = (UUID(), UUID())
        let map = build(loops: [loop(8, 16, name: "Intro chords", uid: chords), notes(10, 12, "Intro lick", uid: line)])
        func said(_ reading: SongMapTogether.Reading) -> String { SongMapTogether.line(for: reading, in: map) }
        XCTAssertEqual(said(.shape(.inARow([UUID(), UUID(), UUID()]))),
                       "In a row: 3 pieces, each on its own, then joined. 5 blocks.")
        XCTAssertEqual(said(.shape(.lineOverChords(line: line, chords: chords))),
                       "Intro lick on its own, then over Intro chords as a backing.")
        XCTAssertEqual(said(.overlapping), "Pieces in a row can't overlap.")
        XCTAssertEqual(said(.notUnder), "The chords have to play under the line.")
    }
}
