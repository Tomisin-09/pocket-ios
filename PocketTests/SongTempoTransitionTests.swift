import XCTest
@testable import Pocket

/// The pure song-level resume-tempo invariant (ADR 0044): arming the first loop banks the
/// song's tempo, disarming the last loop restores it, and loop↔loop / full-song changes leave
/// it alone — so a loop's speed never leaks into `Song.lastPracticedSpeed`. Tested purely; the
/// model wiring around this is exercised on device (the audio engine can't build on CI).
final class SongTempoTransitionTests: XCTestCase {

    func testArmingFirstLoopBanksSongTempo() {
        XCTAssertEqual(SongTempoTransition.forActiveLoopChange(wasArmed: false, nowArmed: true),
                       .bankSongTempo)
    }

    func testDisarmingLastLoopRestoresSongTempo() {
        XCTAssertEqual(SongTempoTransition.forActiveLoopChange(wasArmed: true, nowArmed: false),
                       .restoreSongTempo)
    }

    func testLoopToLoopLeavesSongTempoAlone() {
        XCTAssertEqual(SongTempoTransition.forActiveLoopChange(wasArmed: true, nowArmed: true),
                       .none)
    }

    func testFullSongChangeLeavesSongTempoAlone() {
        XCTAssertEqual(SongTempoTransition.forActiveLoopChange(wasArmed: false, nowArmed: false),
                       .none)
    }
}
