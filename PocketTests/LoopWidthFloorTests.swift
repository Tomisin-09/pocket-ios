import XCTest
@testable import Pocket

/// The minimum loop width (ADR 0199). Split out of `WaveformGestureTests` because it is its own
/// subject: the floor moved from a fraction of the song to half a second of audio, and the tests
/// that matter are about that unit change rather than about gesture geometry.
final class LoopWidthFloorTests: XCTestCase {

    // MARK: minWidth(forDuration:) — the floor in seconds (ADR 0199)

    func testFloorIsHalfASecondOfAudio() {
        // 240s song: 0.5s is 1/480th of it.
        XCTAssertEqual(WaveformGesture.minWidth(forDuration: 240), 0.5 / 240, accuracy: 1e-9)
    }

    func testFloorIsConstantInSecondsAcrossSongLengths() {
        // The defect being fixed: the old constant was a fraction, so the floor grew with the
        // song — 4.8s on a four-minute track, 9.6s on an eight-minute one. In seconds it is flat.
        for duration in [60.0, 240.0, 480.0, 3600.0] {
            let seconds = WaveformGesture.minWidth(forDuration: duration) * duration
            XCTAssertEqual(seconds, WaveformGesture.minLoopSeconds, accuracy: 1e-6,
                           "floor drifted at \(duration)s")
        }
    }

    func testFloorLetsASingleBarBeIsolatedOnALongSong() {
        // A bar of 4/4 at 90bpm is 2.67s. On a six-minute song the old 2% floor was 7.2s — nearly
        // three bars — so this is the case that could not be expressed at all before.
        let sixMinutes: TimeInterval = 360
        let barSeconds = 4 * 60.0 / 90.0
        let floorSeconds = WaveformGesture.minWidth(forDuration: sixMinutes) * sixMinutes
        XCTAssertLessThan(floorSeconds, barSeconds)
    }

    func testFloorClampsToHalfOfAVeryShortSong() {
        // A 0.4s file can't give half a second, and must stay loopable rather than trapping.
        XCTAssertEqual(WaveformGesture.minWidth(forDuration: 0.4), 0.5, accuracy: 1e-9)
    }

    func testFloorFallsBackWhenDurationIsUnknown() {
        // Duration 0 is a real transient state (audio not resolved yet), not an error.
        XCTAssertEqual(WaveformGesture.minWidth(forDuration: 0), WaveformGesture.minLoopWidthFallback)
        XCTAssertEqual(WaveformGesture.minWidth(forDuration: -5), WaveformGesture.minLoopWidthFallback)
    }

    func testMovingHandleHonoursASuppliedFloor() {
        // The pathway the app actually uses: an explicit minWidth, not the fallback default.
        let floor = WaveformGesture.minWidth(forDuration: 240)
        let bounds = WaveformGesture.movingHandle(.start, toFraction: 0.95,
                                                  start: 0.30, end: 0.70, minWidth: floor)
        XCTAssertEqual(bounds.start, 0.70 - floor, accuracy: 1e-9)
    }
}
