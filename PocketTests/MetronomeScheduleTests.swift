import XCTest
@testable import Pocket

/// Pure metronome scheduling (ADR 0026). The rate-relative delay is what keeps the
/// click locked to a time-stretched track, so it's pinned exhaustively here
/// (AGENTS.md).
final class MetronomeScheduleTests: XCTestCase {

    /// A simple 1-second-spaced grid, downbeat every 4th beat starting at t=0.
    private func grid(count: Int, spacing: TimeInterval = 1.0,
                      beatsPerBar: Int = 4) -> [(time: TimeInterval, isDownbeat: Bool)] {
        (0..<count).map { (time: Double($0) * spacing, isDownbeat: $0 % beatsPerBar == 0) }
    }

    // MARK: guards

    func testNoClicksForNonPositiveRate() {
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 8),
                                                currentSourceTime: 0, rate: 0, horizon: 4)
        XCTAssertTrue(clicks.isEmpty)
    }

    func testNoClicksForNonPositiveHorizon() {
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 8),
                                                currentSourceTime: 0, rate: 1, horizon: 0)
        XCTAssertTrue(clicks.isEmpty)
    }

    func testEmptyGridYieldsNoClicks() {
        let clicks = MetronomeSchedule.upcoming(beats: [],
                                                currentSourceTime: 0, rate: 1, horizon: 4)
        XCTAssertTrue(clicks.isEmpty)
    }

    // MARK: window

    func testOnlyBeatsAheadWithinHorizon() {
        // Playhead at 2.0s, horizon 2.0s at 1× ⇒ beats at 3.0 and 4.0 (not 2.0 itself,
        // not 5.0 which is past the horizon).
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 8),
                                                currentSourceTime: 2.0, rate: 1, horizon: 2.0)
        XCTAssertEqual(clicks.map(\.delay), [1.0, 2.0])
    }

    func testBeatLevelWithPlayheadIsNotRefired() {
        // A beat sitting exactly on the playhead must be excluded (it just fired).
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 8),
                                                currentSourceTime: 3.0, rate: 1, horizon: 1.5)
        XCTAssertEqual(clicks.map(\.delay), [1.0])   // 4.0s only; 3.0 dropped, 5.0 past horizon
    }

    // MARK: rate scaling — the crux

    func testHalfRateDoublesRealDelay() {
        // At 0.5× the track is slowed, so the next beat (1s away in source time) is
        // heard 2s from now — the click follows the slowed track.
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 4),
                                                currentSourceTime: 0, rate: 0.5, horizon: 3.0)
        XCTAssertEqual(clicks.map(\.delay), [2.0])   // beat at 1.0s ⇒ 2.0s real; 2.0s ⇒ 4.0 past horizon
    }

    func testDoubleRateHalvesRealDelay() {
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 6),
                                                currentSourceTime: 0, rate: 2.0, horizon: 1.5)
        // beats at 1,2,3s ⇒ 0.5,1.0,1.5s real (all within horizon).
        XCTAssertEqual(clicks.map(\.delay), [0.5, 1.0, 1.5])
    }

    // MARK: accents

    func testDownbeatFlagEveryBar() {
        let clicks = MetronomeSchedule.upcoming(beats: grid(count: 9, beatsPerBar: 4),
                                                currentSourceTime: -0.5, rate: 1, horizon: 8.0)
        // beats 0..7 within window (index 8 at delay 8.5 > horizon); downbeats at 0 and 4.
        XCTAssertEqual(clicks.map(\.isDownbeat),
                       [true, false, false, false, true, false, false, false])
    }
}
