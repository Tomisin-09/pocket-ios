import XCTest
@testable import Pocket

/// The transport's timed skip (ADR 0124, ADR 0192). Pure maths, so the clamping and the increment
/// resolution are pinned here rather than discovered on device at the end of a song — or, since
/// 0192, at the end of a loop, where overrunning the bounds would mean an unasked-for disarm.
final class TransportSkipTests: XCTestCase {

    /// The bounds a song with no loop armed skips within — the shape `bounds` returns for `nil`.
    private func song(_ duration: TimeInterval) -> ClosedRange<TimeInterval> { 0...duration }

    // MARK: target

    func testSkipMovesByTheIncrement() {
        XCTAssertEqual(TransportSkip.target(from: 30, by: 10, within: song(180)), 40, accuracy: 1e-9)
        XCTAssertEqual(TransportSkip.target(from: 30, by: -10, within: song(180)), 20, accuracy: 1e-9)
    }

    func testSkipClampsToTheSongStart() {
        // Rewinding from 3 s by 10 s lands on the top, not at −7 s.
        XCTAssertEqual(TransportSkip.target(from: 3, by: -10, within: song(180)), 0, accuracy: 1e-9)
    }

    func testSkipClampsToTheSongEnd() {
        XCTAssertEqual(TransportSkip.target(from: 175, by: 10, within: song(180)), 180, accuracy: 1e-9)
    }

    func testSkipOnAnUnloadedSongGoesNowhere() {
        // Audio not open yet ⇒ no duration ⇒ nothing to seek within.
        XCTAssertEqual(TransportSkip.target(from: 0, by: 10, within: song(0)), 0, accuracy: 1e-9)
    }

    // MARK: target, inside an armed loop (ADR 0192)

    func testSkipInsideALoopClampsToTheLoopEnd() {
        // The load-bearing case: +10 from 58 s inside a 40–60 s loop must land on 60, not 68.
        // 68 is outside the pre-rendered loop buffer, so seeking there would be a disarm.
        XCTAssertEqual(TransportSkip.target(from: 58, by: 10, within: 40...60), 60, accuracy: 1e-9)
    }

    func testSkipInsideALoopClampsToTheLoopStart() {
        XCTAssertEqual(TransportSkip.target(from: 42, by: -10, within: 40...60), 40, accuracy: 1e-9)
    }

    func testSkipInsideALoopMovesFreelyWithinIt() {
        // The move the unification is *for*: nudge back four seconds and catch the entry again.
        XCTAssertEqual(TransportSkip.target(from: 52, by: -4, within: 40...60), 48, accuracy: 1e-9)
    }

    func testSkipFromOutsideTheLoopLandsOnTheNearEdge() {
        // A playhead that hasn't reached the region yet (armed while paused before it) is pulled
        // to the edge it is skipping toward, rather than left outside the bounds.
        XCTAssertEqual(TransportSkip.target(from: 10, by: 10, within: 40...60), 40, accuracy: 1e-9)
        XCTAssertEqual(TransportSkip.target(from: 120, by: -10, within: 40...60), 60, accuracy: 1e-9)
    }

    // MARK: bounds — what is playing (ADR 0192)

    func testBoundsWithNoLoopAreTheWholeSong() {
        XCTAssertEqual(TransportSkip.bounds(loopRegion: nil, duration: 180), 0...180)
    }

    func testBoundsWithALoopAreTheLoopRegion() {
        XCTAssertEqual(TransportSkip.bounds(loopRegion: (start: 40, end: 60), duration: 180), 40...60)
    }

    func testBoundsOnAnUnloadedSongAreEmpty() {
        // No duration ⇒ nowhere to go, loop or not. Notably this must not build an invalid range.
        XCTAssertEqual(TransportSkip.bounds(loopRegion: nil, duration: 0), 0...0)
        XCTAssertEqual(TransportSkip.bounds(loopRegion: (start: 40, end: 60), duration: 0), 0...0)
    }

    func testADegenerateLoopFallsBackToTheSong() {
        // An empty or inverted region is no place to confine the playhead — the alternative is a
        // transport whose buttons silently do nothing.
        XCTAssertEqual(TransportSkip.bounds(loopRegion: (start: 40, end: 40), duration: 180), 0...180)
        XCTAssertEqual(TransportSkip.bounds(loopRegion: (start: 60, end: 40), duration: 180), 0...180)
    }

    func testALoopReachingPastTheSongIsClampedToIt() {
        XCTAssertEqual(TransportSkip.bounds(loopRegion: (start: 170, end: 200), duration: 180), 170...180)
    }

    // MARK: increment resolution

    func testEveryOfferedIncrementResolvesToItself() {
        for increment in TransportSkip.increments {
            XCTAssertEqual(TransportSkip.resolved(seconds: Int(increment)), increment, accuracy: 1e-9)
        }
    }

    func testUnknownStoredIncrementFallsBack() {
        // A hand-edited default or a value from a build that offered another step.
        XCTAssertEqual(TransportSkip.resolved(seconds: 7), TransportSkip.defaultIncrement, accuracy: 1e-9)
        XCTAssertEqual(TransportSkip.resolved(seconds: 0), TransportSkip.defaultIncrement, accuracy: 1e-9)
        XCTAssertEqual(TransportSkip.resolved(seconds: -10), TransportSkip.defaultIncrement, accuracy: 1e-9)
    }

    func testDefaultIncrementIsOnTheMenu() {
        XCTAssertTrue(TransportSkip.increments.contains(TransportSkip.defaultIncrement))
    }

    // MARK: glyphs + wording

    func testEveryIncrementHasItsOwnNumberedGlyph() {
        // The button *shows* the amount, so a missing symbol variant would silently caption nothing.
        XCTAssertEqual(TransportSkip.symbol(increment: 10, forward: false), "gobackward.10")
        XCTAssertEqual(TransportSkip.symbol(increment: 10, forward: true), "goforward.10")
        for increment in TransportSkip.increments {
            XCTAssertEqual(TransportSkip.symbol(increment: increment, forward: true),
                           "goforward.\(Int(increment))")
        }
    }

    func testUnknownIncrementFallsBackToThePlainGlyph() {
        XCTAssertEqual(TransportSkip.symbol(increment: 7, forward: false), "gobackward")
    }

    func testAMinuteReadsAsAMinute() {
        XCTAssertEqual(TransportSkip.label(increment: 60), "1 minute")
        XCTAssertEqual(TransportSkip.label(increment: 5), "5 seconds")
    }
}
