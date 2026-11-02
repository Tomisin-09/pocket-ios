import XCTest
@testable import Pocket

/// The grid from a beat map (ADR 0281): the map's beats, counted into bars from the 1, through the
/// one entry point every reader of the grid uses.
final class BeatGridMapTests: XCTestCase {

    /// Eight beats that speed up: 0.6 s gaps easing to 0.5 s, in a 4 s song.
    private let drifting: [TimeInterval] = [0.2, 0.8, 1.38, 1.94, 2.48, 3.0, 3.5, 4.0]

    private func seconds(_ beats: [BeatGrid.Beat], duration: TimeInterval) -> [TimeInterval] {
        beats.map { $0.fraction * duration }
    }

    // MARK: - The beats

    func testTheBeatsAreTheMapsOwn() {
        let beats = BeatGrid.beats(map: drifting, duration: 4, anchors: [0.2])
        let times = seconds(beats, duration: 4)
        XCTAssertEqual(times.count, drifting.count)
        for (got, want) in zip(times, drifting) { XCTAssertEqual(got, want, accuracy: 1e-9) }
    }

    func testNoOneNoGrid() {
        // The map knows where the beats are, not which starts a bar (ADR 0022).
        XCTAssertTrue(BeatGrid.beats(map: drifting, duration: 4, anchors: []).isEmpty)
    }

    func testNoSongNoGrid() {
        XCTAssertTrue(BeatGrid.beats(map: drifting, duration: 0, anchors: [0.2]).isEmpty)
    }

    // MARK: - Bars

    func testBarsCountFromTheOne() {
        // The 1 is the third beat; bars of 4 put downbeats there and four beats on.
        let beats = BeatGrid.beats(map: drifting, duration: 4, anchors: [1.38])
        XCTAssertEqual(beats.map(\.isDownbeat), [false, false, true, false, false, false, true, false])
    }

    func testTheOneMarksTheNearestBeat() {
        // Placed 30 ms after beat 3, as a 1 dropped by hand would be.
        let beats = BeatGrid.beats(map: drifting, duration: 4, anchors: [1.41])
        XCTAssertEqual(beats.map(\.isDownbeat), [false, false, true, false, false, false, true, false])
    }

    func testBarsFollowTheTimeSignature() {
        let beats = BeatGrid.beats(map: drifting, duration: 4, anchors: [0.2], beatsPerBar: 3)
        XCTAssertEqual(beats.map(\.isDownbeat), [true, false, false, true, false, false, true, false])
    }

    func testACorrectionRestartsTheBarCount() {
        // A 1 at beat 1 and a correction at beat 6: a bar of four, a bar of one, then a new count.
        let beats = BeatGrid.beats(map: drifting, duration: 4, anchors: [0.2, 3.0])
        XCTAssertEqual(beats.map(\.isDownbeat), [true, false, false, false, true, true, false, false])
    }

    func testTwoAnchorsOnOneBeatAreOne() {
        let one = BeatGrid.beats(map: drifting, duration: 4, anchors: [1.38])
        let two = BeatGrid.beats(map: drifting, duration: 4, anchors: [1.38, 1.40])
        XCTAssertEqual(one, two)
    }

    func testTheCountRunsBackFromTheOneIntoThePreRoll() {
        // A tap-through that started at 2 s in a 4 s song: the pre-roll is carried back at the
        // head's 0.5 s, and the bar count runs back from the 1 at 2.5 s through it. The 1 is the
        // sixth beat, so counting from the song's first beat instead would put the bars elsewhere.
        let map: [TimeInterval] = [2.0, 2.5, 3.0, 3.5]
        let beats = BeatGrid.beats(map: map, duration: 4, anchors: [2.5])
        let times = seconds(beats, duration: 4)
        XCTAssertEqual(times.count, 9)
        XCTAssertEqual(times.first ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(beats.map(\.isDownbeat), [false, true, false, false, false, true, false, false, false])
    }

    // MARK: - The one entry point

    func testAMapWinsOverTheTempo() {
        let fromMap = BeatGrid.beats(bpm: 120, map: drifting, duration: 4, anchors: [0.2])
        XCTAssertEqual(fromMap, BeatGrid.beats(map: drifting, duration: 4, anchors: [0.2]))
    }

    func testWithoutAMapItIsTheTempoGrid() {
        // Three beats is not a map, so the song's one tempo grids it, exactly as before ADR 0281.
        let grid = BeatGrid.beats(bpm: 120, map: [0.2, 0.8, 1.38], duration: 4, anchors: [0.2, 2.1])
        XCTAssertEqual(grid, BeatGrid.beats(bpm: 120, duration: 4, anchors: [0.2, 2.1]))
        XCTAssertFalse(grid.isEmpty)
    }

    func testNoMapAndNoTempoIsNoGrid() {
        XCTAssertTrue(BeatGrid.beats(bpm: nil, map: [], duration: 4, anchors: [0.2]).isEmpty)
    }

    // MARK: - The song

    private func song(map: [TimeInterval], bpm: Double?, one: TimeInterval?) -> Song {
        let song = Song(title: "Binta", artist: "Jack Trader", preciseBPM: bpm, downbeatSeconds: one,
                        duration: 4, ref: SongRef(id: "binta", source: .localFile, bookmark: nil))
        song.beatTimes = map
        return song
    }

    func testASongsGridFollowsItsMap() {
        let song = song(map: drifting, bpm: 110, one: 0.2)
        XCTAssertTrue(song.hasBeatMap)
        XCTAssertEqual(song.gridBeats(duration: 4), BeatGrid.beats(map: drifting, duration: 4, anchors: [0.2]))
    }

    func testASongWithoutAMapKeepsItsStraightGrid() {
        let song = song(map: [], bpm: 120, one: 0.2)
        XCTAssertFalse(song.hasBeatMap)
        XCTAssertEqual(song.gridBeats(duration: 4), BeatGrid.beats(bpm: 120, duration: 4, downbeat: 0.2))
    }

    func testTheMapIsTheTempoOnlyWhenNothingElseIs() throws {
        XCTAssertEqual(song(map: drifting, bpm: 110, one: nil).tempoBPM, 110)
        let fromMap = try XCTUnwrap(song(map: drifting, bpm: nil, one: nil).tempoBPM)
        XCTAssertEqual(fromMap, try XCTUnwrap(BeatMap.medianBPM(drifting)), accuracy: 1e-9)
    }

    // MARK: - Count the notes

    /// Count the notes divides taps by the beat *here*: on a map that's the region's own gap, not the
    /// song's median, or a slot near the edge of a fast stretch would take the next beat's taps.
    func testCountTheNotesUsesTheBeatHere() throws {
        // Slow (0.6 s) for two bars, then fast (0.4 s) for two.
        let slow = (0..<9).map { Double($0) * 0.6 }
        let fast = (1...8).map { 4.8 + Double($0) * 0.4 }
        let grid = try XCTUnwrap(CountGrid(tempo: 120, beatMap: slow + fast, anchors: [0], beatsPerBar: 4,
                                           duration: 10, regionStart: 5.9, regionEnd: 7.5))
        XCTAssertEqual(grid.interval, 0.4, accuracy: 1e-9)
        // Beats 12 to 15 of the song, at 6.0 to 7.2 s; beat 13 starts bar 4.
        XCTAssertEqual(grid.marks.count, 4)
        XCTAssertEqual(grid.marks.map(\.isDownbeat), [false, true, false, false])
    }
}
