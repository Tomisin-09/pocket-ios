import XCTest
@testable import Pocket

/// Count the notes (ADR 0225): turning a tap into a place in the song, grouping taps into passes, the
/// per-beat split, and the Journal line. Pure logic, so the edges are pinned here rather than trusted.
final class TapTallyTests: XCTestCase {

    private func reading(elapsed: TimeInterval, rate: Double = 1, latency: TimeInterval = 0,
                         regionStart: TimeInterval = 30, passLength: TimeInterval = 4) -> LoopClockReading {
        LoopClockReading(elapsed: elapsed, regionStart: regionStart, passLength: passLength, rate: rate,
                         outputLatency: latency)
    }

    // MARK: - Latency

    func testLatencyIsTakenOffInSongTimeAtFullSpeed() throws {
        // 200 ms of route latency at 1× hides 200 ms of the song.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 1.5, latency: 0.2)))
        XCTAssertEqual(tap.pass, 0)
        XCTAssertEqual(tap.seconds, 31.3, accuracy: 1e-9)
    }

    func testLatencyScalesWithTheRateAtHalfSpeed() throws {
        // At 50% the same 200 ms of wall time is only 100 ms of the song.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 1.5, rate: 0.5, latency: 0.2)))
        XCTAssertEqual(tap.seconds, 31.4, accuracy: 1e-9)
    }

    func testLatencyScalesWithTheRateAboveFullSpeed() throws {
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 1.5, rate: 1.5, latency: 0.2)))
        XCTAssertEqual(tap.seconds, 31.2, accuracy: 1e-9)
    }

    func testATapBeforeAnythingIsHeardLandsAtTheTop() throws {
        // The first render hasn't reached the ear yet: the tap can't be before the region.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 0.05, latency: 0.2)))
        XCTAssertEqual(tap.pass, 0)
        XCTAssertEqual(tap.seconds, 30, accuracy: 1e-9)
    }

    // MARK: - Passes and the wrap

    func testTheRenderedWrapIsNotTheHeardWrap() throws {
        // The engine has rendered past the wrap (elapsed 4.1 of a 4 s pass) but the ear, 200 ms behind,
        // is still near the end of pass 0. `loopIteration` would already say pass 1.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 4.1, latency: 0.2)))
        XCTAssertEqual(tap.pass, 0)
        XCTAssertEqual(tap.seconds, 33.9, accuracy: 1e-9)
    }

    func testATapAfterTheWrapStartsTheNextPassAtTheRegionStart() throws {
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 8.25)))
        XCTAssertEqual(tap.pass, 2)
        XCTAssertEqual(tap.seconds, 30.25, accuracy: 1e-9)
    }

    func testATapJustBeforeTheWrapIsPulledIntoTheNextPass() throws {
        // 40 ms before the loop comes round: that's the player catching the first note, early.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 3.96)))
        XCTAssertEqual(tap.pass, 1)
        XCTAssertEqual(tap.seconds, 30, accuracy: 1e-9)
    }

    func testATapOutsideTheEarlyWindowStaysInItsPass() throws {
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 3.93)))
        XCTAssertEqual(tap.pass, 0)
        XCTAssertEqual(tap.seconds, 33.93, accuracy: 1e-9)
    }

    func testTheEarlyWindowIsWallTimeSoItNarrowsWhenSlowed() throws {
        // At 50% the 60 ms window is only 30 ms of the song: 40 ms before the wrap stays put.
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 3.96, rate: 0.5)))
        XCTAssertEqual(tap.pass, 0)
    }

    func testATinyLoopNeverPullsEveryTapForward() throws {
        let tap = try XCTUnwrap(TapTally.instant(at: reading(elapsed: 0.1, passLength: 0.15)))
        XCTAssertEqual(tap.pass, 0)
    }

    func testNoLengthNoTap() {
        XCTAssertNil(TapTally.instant(at: reading(elapsed: 1, passLength: 0)))
    }

    // MARK: - Per beat

    /// Beats every 0.5 s (120 BPM) from 30 s; the region is exactly two beats' worth × 2, 30…32.
    private let beats: [TimeInterval] = stride(from: 29.5, through: 32.5, by: 0.5).map { $0 }

    private func split(_ taps: [TimeInterval]) -> [Int]? {
        TapTally.perBeatCounts(taps: taps, beats: beats, interval: 0.5, regionStart: 30, regionEnd: 32)
    }

    func testTapsSplitIntoTheirBeats() {
        XCTAssertEqual(split([30.0, 30.25, 30.5, 30.75, 31.0, 31.1, 31.2, 31.5]), [2, 2, 3, 1])
    }

    func testATapExactlyAtTheToleranceBelongsToTheLaterBeat() {
        // The slot for the beat at 30.5 opens 0.12 × 0.5 = 60 ms early, at 30.44.
        let edge = 30.5 - TapTally.beatTolerance * 0.5
        XCTAssertEqual(split([edge]), [0, 1, 0, 0])
        XCTAssertEqual(split([edge - 0.001]), [1, 0, 0, 0])
    }

    func testARegionDrawnJustBeforeABeatHasNoPhantomBeat() {
        // Starting 100 ms before the beat at 30.0, so its slot opens 40 ms in. That sliver folds into
        // the beat rather than reporting a beat of its own.
        let counts = TapTally.perBeatCounts(taps: [29.92, 30.1], beats: beats, interval: 0.5,
                                            regionStart: 29.9, regionEnd: 32)
        XCTAssertEqual(counts, [2, 0, 0, 0])
    }

    func testNoGridNoSplit() {
        XCTAssertNil(TapTally.perBeatCounts(taps: [30], beats: [], interval: 0.5, regionStart: 30, regionEnd: 32))
        XCTAssertNil(TapTally.perBeatCounts(taps: [30], beats: beats, interval: 0, regionStart: 30, regionEnd: 32))
    }

    // MARK: - The grid

    func testASongWithNoTempoHasNoGrid() {
        XCTAssertNil(CountGrid(tempo: nil, anchors: [0], beatsPerBar: 4, duration: 120,
                               regionStart: 30, regionEnd: 32))
    }

    func testASongWithNoOneHasNoGrid() {
        // ADR 0022: a tempo without a placed 1 doesn't guess the phase.
        XCTAssertNil(CountGrid(tempo: 120, anchors: [], beatsPerBar: 4, duration: 120,
                               regionStart: 30, regionEnd: 32))
    }

    func testTheGridMarksTheBeatsInsideTheRegion() throws {
        let grid = try XCTUnwrap(CountGrid(tempo: 120, anchors: [0], beatsPerBar: 4, duration: 120,
                                           regionStart: 30, regionEnd: 32))
        XCTAssertEqual(grid.marks.count, 4)
        for (mark, expected) in zip(grid.marks, [0, 0.25, 0.5, 0.75]) {
            XCTAssertEqual(mark.fraction, expected, accuracy: 1e-9)
        }
        XCTAssertEqual(grid.marks.map(\.isDownbeat), [true, false, false, false])
    }

    /// The reason taps are stored in seconds: correcting the grid re-divides the **same** taps. Here
    /// the music has drifted 300 ms late of a one-anchor grid. The lick is a beat and its "and", a beat,
    /// then the same again, so two notes lie in beats 1 and 3. Against the uncorrected grid each "and"
    /// reads as the next beat's; add the anchor and the untouched taps land where they were played.
    func testTheSameTapsReDivideWhenTheGridIsCorrected() throws {
        let taps: [TimeInterval] = [30.3, 30.55, 30.8, 31.3, 31.55, 31.8]
        let before = try XCTUnwrap(CountGrid(tempo: 120, anchors: [0], beatsPerBar: 4, duration: 120,
                                             regionStart: 30, regionEnd: 32))
        let after = try XCTUnwrap(CountGrid(tempo: 120, anchors: [0, 30.3], beatsPerBar: 4, duration: 120,
                                            regionStart: 30, regionEnd: 32))
        XCTAssertEqual(before.perBeat(taps), [1, 2, 1, 2])
        XCTAssertEqual(after.perBeat(taps), [2, 1, 2, 1])
    }

    // MARK: - The Journal line

    func testTheLineCountsAndNames() {
        let line = TapTally.summary(count: 3, names: ["A", "C", "D"], perBeat: nil, countsChords: false)
        XCTAssertEqual(line, "3 notes. A C D")
    }

    func testAnUnnamedNoteHoldsItsPlace() {
        let line = TapTally.summary(count: 3, names: ["A", nil, "D"], perBeat: nil, countsChords: false)
        XCTAssertEqual(line, "3 notes. A ? D")
    }

    func testALongRunOfUnnamedNotesSaysHowMany() {
        let names: [String?] = ["C♯", "D♯", "A♯"] + Array(repeating: nil, count: 60)
        XCTAssertEqual(TapTally.summary(count: 63, names: names, perBeat: nil, countsChords: false),
                       "63 notes. C♯ D♯ A♯ (60 unnamed)", "not sixty question marks")
        XCTAssertEqual(TapTally.nameList(["A", nil, nil, nil, nil, "E"]), "A (4 unnamed) E")
        XCTAssertEqual(TapTally.nameList(["A", nil, nil, nil, "E"]), "A ? ? ? E", "three still hold their places")
        XCTAssertEqual(TapTally.nameList([nil, nil, nil, nil, nil, "G", nil]), "(5 unnamed) G ?")
    }

    func testNoNamesNoNameList() {
        XCTAssertEqual(TapTally.summary(count: 11, names: Array(repeating: nil, count: 11), perBeat: nil,
                                        countsChords: false), "11 notes.")
    }

    func testOneNoteIsSingular() {
        XCTAssertEqual(TapTally.summary(count: 1, names: [nil], perBeat: nil, countsChords: false), "1 note.")
    }

    func testChordsCountAsChords() {
        XCTAssertEqual(TapTally.summary(count: 4, names: ["Am", "F", "C", "G"], perBeat: nil, countsChords: true),
                       "4 chords. Am F C G")
    }

    func testByBeatFollowsTheNames() {
        let line = TapTally.summary(count: 4, names: ["A", "C", "D", "E"], perBeat: [2, 2], countsChords: false)
        XCTAssertEqual(line, "4 notes. A C D E. By beat: 2 · 2.")
    }

    func testByBeatWithoutNames() {
        XCTAssertEqual(TapTally.summary(count: 4, names: [nil, nil, nil, nil], perBeat: [1, 3], countsChords: false),
                       "4 notes. By beat: 1 · 3.")
    }

    func testASingleBeatSplitWouldRepeatTheCountSoItIsLeftOut() {
        XCTAssertEqual(TapTally.summary(count: 4, names: [], perBeat: [4], countsChords: false), "4 notes.")
    }

    func testAnEmptyPassWritesNothing() {
        XCTAssertNil(TapTally.summary(count: 0, names: [], perBeat: nil, countsChords: false))
    }
}

/// The passes of one visit: numbering across stops and restarts, Clear and its Undo, and labels that
/// can't land on the wrong tap.
final class TapPassesTests: XCTestCase {

    private func tap(_ pass: Int, _ seconds: TimeInterval) -> TapTally.Instant {
        TapTally.Instant(pass: pass, seconds: seconds)
    }

    func testTapsGroupByPassAndSortWithinIt() {
        var passes = TapPasses()
        passes.beginRun()
        passes.record(tap(0, 31))
        passes.record(tap(0, 30.5))
        passes.record(tap(1, 30.2))
        XCTAssertEqual(passes.passes.map(\.id), [1, 2])
        XCTAssertEqual(passes.passes[0].taps.map(\.seconds), [30.5, 31])
    }

    func testARestartNumbersOnFromTheLastPass() {
        var passes = TapPasses()
        passes.beginRun()
        passes.record(tap(2, 30))                 // pass 3 of the first run
        passes.beginRun()                         // stopped, played again
        XCTAssertEqual(passes.record(tap(0, 30)), 4)
    }

    func testClearThenUndoPutsBackAlongsideNewTaps() {
        var passes = TapPasses()
        passes.beginRun()
        passes.record(tap(0, 30))
        passes.record(tap(1, 30))
        let cleared = passes.clear()
        XCTAssertTrue(passes.passes.isEmpty)
        XCTAssertEqual(passes.record(tap(2, 30)), 3, "numbers never go back down after a Clear")
        passes.restore(cleared)
        XCTAssertEqual(passes.passes.map(\.id), [1, 2, 3])
    }

    func testOnlyTheNewestPassesAreKept() {
        var passes = TapPasses()
        passes.beginRun()
        for pass in 0..<(TapPasses.kept + 3) { passes.record(tap(pass, 30)) }
        XCTAssertEqual(passes.passes.count, TapPasses.kept)
        XCTAssertEqual(passes.passes.first?.id, 4)
    }

    func testALongPassIsWellPastTheComfortableLength() {
        XCTAssertFalse(TapTally.isLongPass(TapTally.comfortableNotes))
        XCTAssertFalse(TapTally.isLongPass(24), "a few past comfortable isn't told anything")
        XCTAssertTrue(TapTally.isLongPass(25))
    }
}
