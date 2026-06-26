import XCTest
@testable import Pocket

/// Pure standalone-metronome beat generation (ADR 0043, slice 1). The interval
/// stepping, downbeat grouping, and window edges are exactly the arithmetic that
/// breaks silently without coverage (AGENTS.md), so they're pinned here.
final class MetronomeBeatsTests: XCTestCase {

    private func assertTimes(_ beats: [MetronomeBeats.Beat], _ expected: [TimeInterval],
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(beats.count, expected.count, "beat count", file: file, line: line)
        for (beat, want) in zip(beats, expected) {
            XCTAssertEqual(beat.time, want, accuracy: 1e-9, file: file, line: line)
        }
    }

    // MARK: guards

    func testEmptyForNonPositiveBPM() {
        XCTAssertTrue(MetronomeBeats.beats(bpm: 0, through: 10).isEmpty)
        XCTAssertTrue(MetronomeBeats.beats(bpm: -120, through: 10).isEmpty)
    }

    func testEmptyForInvertedWindow() {
        // through < from ⇒ no window ⇒ no beats.
        XCTAssertTrue(MetronomeBeats.beats(bpm: 120, from: 5, through: 4).isEmpty)
    }

    func testEmptyWhenWindowExceedsMaxBeats() {
        // 6000 BPM over 2000 s ⇒ 200k beats, past the runaway guard ⇒ no beats.
        XCTAssertTrue(MetronomeBeats.beats(bpm: 6000, through: 2000).isEmpty)
    }

    // MARK: positions

    func testBeatsStartAtZero() {
        // 60 BPM ⇒ a beat every second; a 4 s horizon ⇒ beats at 0…4 s.
        let beats = MetronomeBeats.beats(bpm: 60, through: 4)
        assertTimes(beats, [0, 1, 2, 3, 4])
    }

    func test120BPMHalfSecondSpacing() {
        let beats = MetronomeBeats.beats(bpm: 120, through: 2)
        assertTimes(beats, [0, 0.5, 1.0, 1.5, 2.0])
    }

    func testDownbeatEveryFourthBeat() {
        let beats = MetronomeBeats.beats(bpm: 60, through: 8)   // 9 beats, k = 0…8
        XCTAssertEqual(beats.map(\.isDownbeat),
                       [true, false, false, false, true, false, false, false, true])
    }

    func testThreeFourGrouping() {
        // 3/4: downbeats every 3rd beat from beat 0.
        let beats = MetronomeBeats.beats(bpm: 60, beatsPerBar: 3, through: 6)
        XCTAssertEqual(beats.filter(\.isDownbeat).map(\.time), [0, 3, 6])
    }

    func testBeatsPerBarBelowOneIsTreatedAsOne() {
        // Degenerate beatsPerBar ⇒ every beat is its own bar (all downbeats).
        let beats = MetronomeBeats.beats(bpm: 60, beatsPerBar: 0, through: 3)
        XCTAssertEqual(beats.count, 4)
        XCTAssertTrue(beats.allSatisfy(\.isDownbeat))
    }

    // MARK: window

    func testWindowExcludesBeatsBeforeStart() {
        // from 2.0 s ⇒ first beat returned is the one at 2.0, not earlier ones.
        let beats = MetronomeBeats.beats(bpm: 60, from: 2.0, through: 5.0)
        assertTimes(beats, [2, 3, 4, 5])
    }

    func testWindowKeepsAbsoluteDownbeatPhase() {
        // A window starting mid-sequence must still flag downbeats by absolute index,
        // not by position within the window: beat 4 (at 4 s) is a downbeat, 5/6/7 not.
        let beats = MetronomeBeats.beats(bpm: 60, from: 4.0, through: 7.0)
        XCTAssertEqual(beats.map(\.time), [4, 5, 6, 7])
        XCTAssertEqual(beats.map(\.isDownbeat), [true, false, false, false])
    }

    func testWindowStartFallsBetweenBeats() {
        // from 2.5 s at 60 BPM ⇒ first qualifying beat is at 3.0 s.
        let beats = MetronomeBeats.beats(bpm: 60, from: 2.5, through: 4.5)
        assertTimes(beats, [3, 4])
    }

    func testBeatExactlyOnStartEdgeIsIncluded() {
        let beats = MetronomeBeats.beats(bpm: 120, from: 1.0, through: 1.0)
        assertTimes(beats, [1.0])
    }

    // MARK: precision

    func testFractionalBPMKeepsPrecision() {
        // 90.06 BPM places beats fractionally tighter than 90.0 would; an Int-rounded
        // tempo would collapse the difference and drift the grid over a long sitting.
        let interval = 60.0 / 90.06
        let beats = MetronomeBeats.beats(bpm: 90.06, through: 4)
        XCTAssertEqual(beats[1].time, interval, accuracy: 1e-12)
        XCTAssertNotEqual(beats[1].time, 60.0 / 90.0, accuracy: 1e-6)
    }

    // MARK: scheduler hand-off

    func testSequenceMatchesBeatsAndDropsIntoScheduler() {
        let beats = MetronomeBeats.beats(bpm: 120, through: 3)
        let sequence = MetronomeBeats.sequence(bpm: 120, through: 3)
        XCTAssertEqual(sequence.map(\.time), beats.map(\.time))
        XCTAssertEqual(sequence.map(\.isDownbeat), beats.map(\.isDownbeat))

        // The generated sequence feeds the shared scheduler unchanged (rate 1.0).
        let clicks = MetronomeSchedule.upcoming(beats: sequence,
                                                currentSourceTime: 0, rate: 1, horizon: 1.0)
        XCTAssertEqual(clicks.map(\.delay), [0.5, 1.0])   // 0.0 dropped (level with now)
    }
}
