import XCTest
@testable import Pocket

/// The transport's timed skip (ADR 0124). Pure maths, so the clamping and the increment
/// resolution are pinned here rather than discovered on device at the end of a song.
final class TransportSkipTests: XCTestCase {

    // MARK: target

    func testSkipMovesByTheIncrement() {
        XCTAssertEqual(TransportSkip.target(from: 30, by: 10, duration: 180), 40, accuracy: 1e-9)
        XCTAssertEqual(TransportSkip.target(from: 30, by: -10, duration: 180), 20, accuracy: 1e-9)
    }

    func testSkipClampsToTheSongStart() {
        // Rewinding from 3 s by 10 s lands on the top, not at −7 s.
        XCTAssertEqual(TransportSkip.target(from: 3, by: -10, duration: 180), 0, accuracy: 1e-9)
    }

    func testSkipClampsToTheSongEnd() {
        XCTAssertEqual(TransportSkip.target(from: 175, by: 10, duration: 180), 180, accuracy: 1e-9)
    }

    func testSkipOnAnUnloadedSongGoesNowhere() {
        // Audio not open yet ⇒ no duration ⇒ nothing to seek within.
        XCTAssertEqual(TransportSkip.target(from: 0, by: 10, duration: 0), 0, accuracy: 1e-9)
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
