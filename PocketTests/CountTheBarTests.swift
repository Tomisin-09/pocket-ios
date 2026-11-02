import XCTest
@testable import Pocket

/// Counting the bar by choosing (B4, ADR 0283 D2–D3): which beat is the 1, moved along the grid Done
/// would leave, and the three choices for a bar.
final class CountTheBarTests: XCTestCase {

    /// A hand-tapped map, uneven on purpose so a step along it can't pass for a step of one tempo.
    private let map: [TimeInterval] = [0.5, 1.0, 1.6, 2.1, 2.8, 3.3]

    // MARK: Moving the 1

    func testMovingByNoneIsThePlacedOne() {
        XCTAssertEqual(BeatGrid.one(0.73, movedBy: 0, bpm: nil, map: [], duration: 30), 0.73)
    }

    func testOneTempoMovesByWholeBeats() throws {
        let moved = try XCTUnwrap(BeatGrid.one(0.5, movedBy: 2, bpm: 120, map: [], duration: 30))
        XCTAssertEqual(moved, 1.5, accuracy: 1e-9)
    }

    func testWithoutATempoThereIsNothingToStepAlong() {
        XCTAssertNil(BeatGrid.one(0.5, movedBy: 1, bpm: nil, map: [], duration: 30))
        XCTAssertNil(BeatGrid.one(0.5, movedBy: 1, bpm: 0, map: [], duration: 30))
    }

    /// From the beat nearest the placed 1 (1.0), two of the map's own beats on is 2.1. One tempo of
    /// 120 would have put it at 2.02.
    func testAMapMovesAlongItsOwnBeats() {
        XCTAssertEqual(BeatGrid.one(1.02, movedBy: 2, bpm: 120, map: map, duration: 3.3), 2.1)
    }

    func testAMapStopsAtTheSongsLastBeat() {
        XCTAssertEqual(BeatGrid.one(1.0, movedBy: 40, bpm: nil, map: map, duration: 3.3), 3.3)
    }

    // MARK: The 1 as the sheet holds it

    func testTheChosenBeatMovesTheOne() throws {
        var one = DownbeatChoice(placed: 0.5)
        one.beat = 3
        let seconds = try XCTUnwrap(one.seconds(beatsPerBar: 4, bpm: 60, map: [], duration: 30))
        XCTAssertEqual(seconds, 2.5, accuracy: 1e-9)
    }

    /// A beat chosen against one placing is never applied to another.
    func testPlacingTheOneAgainCountsFromIt() {
        var one = DownbeatChoice(placed: 0.5)
        one.beat = 3
        one.placed = 2
        XCTAssertEqual(one.beat, 1)
        XCTAssertEqual(one.seconds(beatsPerBar: 4, bpm: 60, map: [], duration: 30), 2)
    }

    /// A 4 chosen, then 3 beats a bar: there is no fourth beat, so the placed 1 stands.
    func testABeatPastTheBarCountsAsTheFirst() {
        var one = DownbeatChoice(placed: 0.5)
        one.beat = 4
        XCTAssertEqual(one.beat(inBarOf: 3), 1)
        XCTAssertEqual(one.seconds(beatsPerBar: 3, bpm: 60, map: [], duration: 30), 0.5)
    }

    func testWithoutATempoThePlacedOneStands() {
        var one = DownbeatChoice(placed: 0.5)
        one.beat = 2
        XCTAssertEqual(one.seconds(beatsPerBar: 4, bpm: nil, map: [], duration: 30), 0.5)
    }

    func testNothingPlacedIsNoOne() {
        XCTAssertNil(DownbeatChoice(placed: nil).seconds(beatsPerBar: 4, bpm: 120, map: [], duration: 30))
    }

    // MARK: Beats in a bar

    func testThreeAndFourAreOfferedAndTheRestAreMore() {
        let choices = Dictionary(uniqueKeysWithValues: TimeSignature.presets.map { ($0.name, BarChoice($0)) })
        XCTAssertEqual(choices, ["4/4": .four, "3/4": .three, "2/4": .more, "6/8": .more, "12/8": .more,
                                 "5/4": .more, "7/8": .more])
    }

    func testEachChoiceSetsItsOwnSignature() {
        XCTAssertEqual(BarChoice.three.signature?.name, "3/4")
        XCTAssertEqual(BarChoice.four.signature?.name, "4/4")
        XCTAssertNil(BarChoice.more.signature)
    }
}
