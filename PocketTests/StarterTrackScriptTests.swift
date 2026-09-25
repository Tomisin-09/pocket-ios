import XCTest
@testable import Pocket

/// Beat 1, scripted (ADR 0220 D3): playback pauses on each of the starter track's markers so the
/// player's two Loop taps land on them. Driven here frame by frame, the way `PracticeAudioEngine`
/// drives it — and the stops are the song's **constants**, never its `Marker` records (D5).
final class StarterTrackScriptTests: XCTestCase {

    /// One 60 Hz frame of song time at full speed.
    private let frame: TimeInterval = 1.0 / 60

    /// Advance from `from` to `through` a frame at a time, returning the first stop the script asks
    /// for (and the time it asked), as the engine's ticker would.
    @discardableResult
    private func play(_ script: inout StarterTrackScript, from: TimeInterval, through: TimeInterval,
                      span: StarterTrackScript.Span = .idle) -> TimeInterval? {
        var previous = from
        var now = from
        while now < through {
            now = min(through, now + frame)
            if let stop = script.tick(from: previous, to: now, span: span) { return stop }
            previous = now
        }
        return nil
    }

    // MARK: - The constants it runs on

    /// The script's defaults are the song's own positions, so the markers, the grid and the pauses
    /// agree by construction.
    func testItStopsOnTheStarterTracksOwnBars() {
        let script = StarterTrackScript()
        XCTAssertEqual(script.start, StarterTrack.chordsStart.seconds)
        XCTAssertEqual(script.end, StarterTrack.soloStart.seconds)
        XCTAssertEqual(script.leadIn, StarterTrack.leadInSeconds)
        XCTAssertEqual(script.start, 23.160, accuracy: 0.001)
        XCTAssertEqual(script.end, 34.726, accuracy: 0.001)
        XCTAssertEqual(script.leadIn, 17.376, accuracy: 0.001)
    }

    // MARK: - The whole beat

    /// D3 steps 1–5: lead in, pause on Chords start, Loop (A), pause on Solo start, Loop (B).
    func testTheScriptedBeatPausesOnBothMarkersAndFinishesWhenTheSpanCloses() {
        var script = StarterTrackScript()
        XCTAssertEqual(script.stage, .leadIn)
        XCTAssertFalse(script.hintsLoop)

        let first = play(&script, from: script.leadIn, through: 30)
        XCTAssertEqual(first, script.start, "It pauses exactly on the marker, not where the frame landed")
        XCTAssertEqual(script.stage, .heldAtStart)
        XCTAssertTrue(script.hintsLoop)

        // The model seeks onto the marker; the player's tap drops A there.
        script.spanChanged(.armed(script.start))
        XCTAssertEqual(script.stage, .awaitingEnd)
        XCTAssertFalse(script.hintsLoop)

        let second = play(&script, from: script.start, through: 40, span: .armed(script.start))
        XCTAssertEqual(second, script.end)
        XCTAssertEqual(script.stage, .heldAtEnd)
        XCTAssertTrue(script.hintsLoop)

        script.spanChanged(.set)
        XCTAssertEqual(script.stage, .finished)
        XCTAssertNil(play(&script, from: 0, through: 81, span: .set), "Nothing pauses once it has finished")
    }

    /// The seek-back leaves the playhead **on** the marker. Resuming from there — the player pressed
    /// play instead of tapping Loop — must not trip the same stop again.
    func testResumingFromTheMarkerDoesNotStopThereAgain() {
        var script = StarterTrackScript()
        play(&script, from: script.leadIn, through: 30)
        // A frame-rounded seek can land a hair *before* the marker; that is not a rewind.
        XCTAssertNil(play(&script, from: script.start - 0.00002, through: 30))
        XCTAssertEqual(script.stage, .heldAtStart)
    }

    /// Without an A, there is no loop to close: the second stop only exists once Loop was tapped.
    func testTheSecondStopNeedsAnArmedSpan() {
        var script = StarterTrackScript()
        play(&script, from: script.leadIn, through: 30)
        XCTAssertNil(play(&script, from: script.start, through: 40))
    }

    /// Rewinding to before the first marker without tapping Loop lets it stop there again.
    func testRewindingPastTheFirstStopReArmsIt() {
        var script = StarterTrackScript()
        play(&script, from: script.leadIn, through: 30)
        XCTAssertNil(script.tick(from: 23.2, to: 10, span: .idle))
        XCTAssertEqual(script.stage, .leadIn)
        XCTAssertEqual(play(&script, from: 20, through: 30), script.start)
    }

    // MARK: - Off script

    /// A tap before the marker is still the player's A. The script moves on to helping close it.
    func testLoopTappedEarlySkipsToTheSecondStop() {
        var script = StarterTrackScript()
        script.spanChanged(.armed(20))
        XCTAssertEqual(script.stage, .awaitingEnd)
        XCTAssertEqual(play(&script, from: 20, through: 40, span: .armed(20)), script.end)
    }

    /// An A dropped past the second stop cannot be closed on it; the script stays out of the way.
    func testAnAPastTheSecondStopNeverPauses() {
        var script = StarterTrackScript()
        script.spanChanged(.armed(50))
        XCTAssertNil(play(&script, from: 50, through: 81, span: .armed(50)))
    }

    /// Clearing A before B starts over from the first stop.
    func testClearingTheSpanStartsOver() {
        var script = StarterTrackScript()
        script.spanChanged(.armed(script.start))
        script.spanChanged(.idle)
        XCTAssertEqual(script.stage, .leadIn)
    }

    /// A span closed any other way — a hold-drag, say — finishes it: beat 1 is done however it was done.
    func testASpanClosedAnyWayFinishesTheScript() {
        var script = StarterTrackScript()
        script.spanChanged(.set)
        XCTAssertEqual(script.stage, .finished)
        script.spanChanged(.idle)
        XCTAssertEqual(script.stage, .finished, "A finished script never restarts")
    }

    // MARK: - What counts as playing through

    /// A seek or a ten-second skip across a marker is not playback reaching it.
    func testAJumpAcrossAStopIsNotPlayingThroughIt() {
        XCTAssertFalse(StarterTrackScript.played(from: 20, to: 30, through: 23.16))
        XCTAssertTrue(StarterTrackScript.played(from: 23.15, to: 23.17, through: 23.16))
        // Two-times speed on a 60 Hz display, with a dropped frame: still a crossing.
        XCTAssertTrue(StarterTrackScript.played(from: 23.10, to: 23.17, through: 23.16))
    }

    /// Strict on the near side, inclusive on the far one — landing exactly on the stop counts, and
    /// starting exactly on it does not.
    func testTheCrossingIsHalfOpen() {
        XCTAssertTrue(StarterTrackScript.played(from: 23.0, to: 23.16, through: 23.16))
        XCTAssertFalse(StarterTrackScript.played(from: 23.16, to: 23.2, through: 23.16))
    }
}
