import XCTest
@testable import Pocket

/// Pure A/B span cycle (ADR 0041) — the play-along tap state machine and span
/// ordering. The geometry it leans on (`loopBounds`) is covered in
/// `WaveformGestureTests`; here we pin the cycle transitions and accessors.
final class ABSpanTests: XCTestCase {

    // MARK: tappingPlayhead — the three-state cycle

    func testIdleTapArmsAtPlayhead() {
        XCTAssertEqual(ABSpan.idle.tappingPlayhead(0.3, duration: 0), .armed(0.3))
    }

    func testArmedTapClosesToOrderedSpan() {
        let span = ABSpan.armed(0.3).tappingPlayhead(0.7, duration: 0)
        XCTAssertEqual(span, .set(start: 0.3, end: 0.7))
    }

    func testArmedTapOrdersBackwardSecondTap() {
        // B landed left of A — the span must still come out start < end.
        let span = ABSpan.armed(0.7).tappingPlayhead(0.3, duration: 0)
        XCTAssertEqual(span, .set(start: 0.3, end: 0.7))
    }

    func testArmedTapWidensWhenTooClose() {
        // A and B almost coincident — widened to the minimum loop width.
        guard case .set(let start, let end) = ABSpan.armed(0.5).tappingPlayhead(0.505, duration: 0) else {
            return XCTFail("Expected a closed span")
        }
        XCTAssertEqual(end - start, WaveformGesture.minLoopWidthFallback, accuracy: 0.0001)
        XCTAssertEqual((start + end) / 2, 0.5025, accuracy: 0.0001)
    }

    func testSetTapClears() {
        XCTAssertEqual(ABSpan.set(start: 0.2, end: 0.6).tappingPlayhead(0.9, duration: 0), .idle)
    }

    func testFullCycleReturnsToIdle() {
        let span = ABSpan.idle
            .tappingPlayhead(0.2, duration: 0)   // → armed(0.2)
            .tappingPlayhead(0.6, duration: 0)   // → set(0.2, 0.6)
            .tappingPlayhead(0.4, duration: 0)   // → idle
        XCTAssertEqual(span, .idle)
    }

    func testArmedTapUsesTheHalfSecondFloorWhenDurationIsKnown() {
        // The floor is half a second of *audio*, not a slice of the song (ADR 0199). On a
        // four-minute track that is 0.00208 of the song — a quarter of the old 2% constant,
        // which is the whole point: a bar of 4/4 at 90bpm is 2.7s and used to be unreachable.
        let fourMinutes: TimeInterval = 240
        guard case .set(let start, let end) = ABSpan.armed(0.5).tappingPlayhead(0.5001, duration: fourMinutes) else {
            return XCTFail("Expected a closed span")
        }
        XCTAssertEqual((end - start) * fourMinutes, WaveformGesture.minLoopSeconds, accuracy: 0.001)
    }

    func testTheFloorDoesNotGrowWithSongLength() {
        // The bug this replaces: the floor used to scale with the song, so the longer the
        // piece the coarser the practice. Two songs, one twice the length — same seconds.
        func widthSeconds(duration: TimeInterval) -> TimeInterval {
            guard case .set(let start, let end) = ABSpan.armed(0.5).tappingPlayhead(0.5001, duration: duration) else {
                XCTFail("Expected a closed span"); return 0
            }
            return (end - start) * duration
        }
        XCTAssertEqual(widthSeconds(duration: 240), widthSeconds(duration: 480), accuracy: 0.001)
    }

    // MARK: closed(from:to:) — the shared set exit (spatial hold-drag release)

    func testClosedOrdersAndWidens() {
        // A pinned at the playhead (anchor), B at the finger (current), reversed.
        guard case .set(let start, let end) = ABSpan.closed(from: 0.8, to: 0.1, duration: 0) else {
            return XCTFail("Expected a closed span")
        }
        XCTAssertEqual(start, 0.1, accuracy: 0.0001)
        XCTAssertEqual(end, 0.8, accuracy: 0.0001)
    }

    // MARK: accessors

    func testArmedPointOnlyWhenForming() {
        XCTAssertEqual(ABSpan.armed(0.42).armedPoint, 0.42)
        XCTAssertNil(ABSpan.idle.armedPoint)
        XCTAssertNil(ABSpan.set(start: 0.1, end: 0.2).armedPoint)
    }

    func testBoundsOnlyWhenSet() {
        let bounds = ABSpan.set(start: 0.15, end: 0.55).bounds
        XCTAssertEqual(bounds?.start, 0.15)
        XCTAssertEqual(bounds?.end, 0.55)
        XCTAssertNil(ABSpan.idle.bounds)
        XCTAssertNil(ABSpan.armed(0.3).bounds)
    }

    func testIsSetTracksClosedSpan() {
        XCTAssertFalse(ABSpan.idle.isSet)
        XCTAssertFalse(ABSpan.armed(0.3).isSet)
        XCTAssertTrue(ABSpan.set(start: 0.1, end: 0.2).isSet)
    }
}
