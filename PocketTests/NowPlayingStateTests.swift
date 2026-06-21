import XCTest
@testable import Pocket

/// `NowPlayingState` is the pure value that drives the lock-screen / Control
/// Center display (ADR 0025). The rate-reporting logic is the part that breaks
/// silently — the rest is field passthrough — so it's the focus here.
final class NowPlayingStateTests: XCTestCase {

    private func state(isPlaying: Bool, speed: Double) -> NowPlayingState {
        NowPlayingState(title: "Song", artist: "Artist", duration: 120,
                        elapsedTime: 30, isPlaying: isPlaying, speed: speed)
    }

    func testReportedRateIsZeroWhenPaused() {
        // Paused must report 0 so the lock-screen clock freezes and the control
        // shows the play glyph — even though the speed multiplier is non-zero.
        XCTAssertEqual(state(isPlaying: false, speed: 1.0).reportedRate, 0)
        XCTAssertEqual(state(isPlaying: false, speed: 0.5).reportedRate, 0)
    }

    func testReportedRateTracksSpeedWhenPlaying() {
        // Playing reports the actual practice speed (not a hard 1×) so the system's
        // extrapolated clock advances in step with reduced/raised playback.
        XCTAssertEqual(state(isPlaying: true, speed: 1.0).reportedRate, 1.0, accuracy: 1e-9)
        XCTAssertEqual(state(isPlaying: true, speed: 0.5).reportedRate, 0.5, accuracy: 1e-9)
        XCTAssertEqual(state(isPlaying: true, speed: 1.5).reportedRate, 1.5, accuracy: 1e-9)
    }
}
