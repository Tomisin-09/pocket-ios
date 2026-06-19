import XCTest
@testable import Pocket

final class WaveformGestureTests: XCTestCase {

    // MARK: fraction(atX:width:)

    func testFractionMapsLinearly() {
        XCTAssertEqual(WaveformGesture.fraction(atX: 150, width: 300), 0.5, accuracy: 0.0001)
    }

    func testFractionClampsBelowZero() {
        XCTAssertEqual(WaveformGesture.fraction(atX: -40, width: 300), 0, accuracy: 0.0001)
    }

    func testFractionClampsAboveOne() {
        XCTAssertEqual(WaveformGesture.fraction(atX: 400, width: 300), 1, accuracy: 0.0001)
    }

    func testFractionZeroWidthIsSafe() {
        XCTAssertEqual(WaveformGesture.fraction(atX: 10, width: 0), 0, accuracy: 0.0001)
    }

    // MARK: loopBounds

    func testLoopBoundsOrdersReversedTaps() {
        // Second tap left of the first — must still produce start < end.
        let bounds = WaveformGesture.loopBounds(0.7, 0.3)
        XCTAssertEqual(bounds.start, 0.3, accuracy: 0.0001)
        XCTAssertEqual(bounds.end, 0.7, accuracy: 0.0001)
    }

    func testLoopBoundsWidensWhenTooNarrow() {
        // Two near-identical taps grow to the minimum width around the midpoint.
        let bounds = WaveformGesture.loopBounds(0.500, 0.505)
        XCTAssertEqual(bounds.end - bounds.start, WaveformGesture.minLoopWidth, accuracy: 0.0001)
        XCTAssertEqual((bounds.start + bounds.end) / 2, 0.5025, accuracy: 0.0001)
    }

    func testLoopBoundsWidenStaysInsideAtRightEdge() {
        // A too-narrow tap pair at the very end can't spill past 1.0.
        let bounds = WaveformGesture.loopBounds(1.0, 1.0)
        XCTAssertEqual(bounds.end, 1.0, accuracy: 0.0001)
        XCTAssertEqual(bounds.end - bounds.start, WaveformGesture.minLoopWidth, accuracy: 0.0001)
    }

    func testLoopBoundsClampsOutOfRangeInputs() {
        let bounds = WaveformGesture.loopBounds(-0.2, 1.4)
        XCTAssertEqual(bounds.start, 0, accuracy: 0.0001)
        XCTAssertEqual(bounds.end, 1, accuracy: 0.0001)
    }

    // MARK: nearestHandle

    func testNearestHandlePicksCloser() {
        let handle = WaveformGesture.nearestHandle(toFraction: 0.32, start: 0.30, end: 0.70,
                                                   tolerance: 0.05)
        XCTAssertEqual(handle, .start)
    }

    func testNearestHandlePicksEnd() {
        let handle = WaveformGesture.nearestHandle(toFraction: 0.68, start: 0.30, end: 0.70,
                                                   tolerance: 0.05)
        XCTAssertEqual(handle, .end)
    }

    func testNearestHandleNilOutsideTolerance() {
        let handle = WaveformGesture.nearestHandle(toFraction: 0.50, start: 0.30, end: 0.70,
                                                   tolerance: 0.05)
        XCTAssertNil(handle)
    }

    func testNearestHandleTieGoesToStart() {
        let handle = WaveformGesture.nearestHandle(toFraction: 0.50, start: 0.40, end: 0.60,
                                                   tolerance: 0.2)
        XCTAssertEqual(handle, .start)
    }

    // MARK: movingHandle

    func testMovingStartHandle() {
        let bounds = WaveformGesture.movingHandle(.start, toFraction: 0.45, start: 0.30, end: 0.70)
        XCTAssertEqual(bounds.start, 0.45, accuracy: 0.0001)
        XCTAssertEqual(bounds.end, 0.70, accuracy: 0.0001)
    }

    func testMovingStartHandleCannotCrossEnd() {
        // Dragging start past end is capped at end − minLoopWidth.
        let bounds = WaveformGesture.movingHandle(.start, toFraction: 0.95, start: 0.30, end: 0.70)
        XCTAssertEqual(bounds.start, 0.70 - WaveformGesture.minLoopWidth, accuracy: 0.0001)
        XCTAssertEqual(bounds.end, 0.70, accuracy: 0.0001)
    }

    func testMovingEndHandleCannotCrossStart() {
        let bounds = WaveformGesture.movingHandle(.end, toFraction: 0.10, start: 0.30, end: 0.70)
        XCTAssertEqual(bounds.start, 0.30, accuracy: 0.0001)
        XCTAssertEqual(bounds.end, 0.30 + WaveformGesture.minLoopWidth, accuracy: 0.0001)
    }

    func testMovingHandleClampsToTrack() {
        let bounds = WaveformGesture.movingHandle(.end, toFraction: 1.5, start: 0.30, end: 0.70)
        XCTAssertEqual(bounds.end, 1.0, accuracy: 0.0001)
    }

    // MARK: Zoom — span / viewport / mapping

    func testClampSpanBounds() {
        XCTAssertEqual(WaveformGesture.clampSpan(2.0), 1.0, accuracy: 1e-9)        // no more than whole song
        XCTAssertEqual(WaveformGesture.clampSpan(0.001), WaveformGesture.minZoomSpan, accuracy: 1e-9)
        XCTAssertEqual(WaveformGesture.clampSpan(0.4), 0.4, accuracy: 1e-9)
    }

    func testSongFractionMapsThroughViewport() {
        let viewport = (start: 0.4, end: 0.6)
        XCTAssertEqual(WaveformGesture.songFraction(screenFraction: 0, viewport: viewport), 0.4, accuracy: 1e-9)
        XCTAssertEqual(WaveformGesture.songFraction(screenFraction: 0.5, viewport: viewport), 0.5, accuracy: 1e-9)
        XCTAssertEqual(WaveformGesture.songFraction(screenFraction: 1, viewport: viewport), 0.6, accuracy: 1e-9)
    }

    func testScreenFractionIsInverse() {
        let viewport = (start: 0.4, end: 0.6)
        XCTAssertEqual(WaveformGesture.screenFraction(songFraction: 0.4, viewport: viewport), 0, accuracy: 1e-9)
        XCTAssertEqual(WaveformGesture.screenFraction(songFraction: 0.5, viewport: viewport), 0.5, accuracy: 1e-9)
        XCTAssertEqual(WaveformGesture.screenFraction(songFraction: 0.6, viewport: viewport), 1, accuracy: 1e-9)
    }

    // MARK: Page-mode — pagedStart

    func testPagedStartHoldsStillWithinComfortZone() {
        // Playhead inside [start, start + 0.9·span] → window does not move.
        let start = WaveformGesture.pagedStart(currentStart: 0.20, span: 0.20, playhead: 0.30)
        XCTAssertEqual(start, 0.20, accuracy: 1e-9)
    }

    func testPagedStartPagesForwardAtThreshold() {
        // Crossing ~90% across re-anchors so the playhead lands leadIn·span (0.02) in.
        // start 0.20, span 0.20 → trigger at 0.20 + 0.18 = 0.38; playhead just past it.
        let start = WaveformGesture.pagedStart(currentStart: 0.20, span: 0.20, playhead: 0.39)
        XCTAssertEqual(start, 0.39 - 0.1 * 0.20, accuracy: 1e-9)   // 0.37
    }

    func testPagedStartPagesBackWhenPlayheadSeekedBeforeWindow() {
        // Seek to before the window → it pages back so the playhead is visible again.
        let start = WaveformGesture.pagedStart(currentStart: 0.50, span: 0.20, playhead: 0.10)
        XCTAssertEqual(start, 0.10 - 0.1 * 0.20, accuracy: 1e-9)   // 0.08
    }

    func testPagedStartClampsAtSongEnd() {
        // Near the end, the re-anchored window can't run past 1 − span.
        let start = WaveformGesture.pagedStart(currentStart: 0.70, span: 0.20, playhead: 0.99)
        XCTAssertEqual(start, 0.80, accuracy: 1e-9)               // 1 − span
    }

    func testPagedStartFullSongNeverMoves() {
        // span == 1 → maxStart 0; the window is the whole song wherever the playhead is.
        XCTAssertEqual(WaveformGesture.pagedStart(currentStart: 0, span: 1, playhead: 0.95), 0, accuracy: 1e-9)
    }

    func testPagedStartClampsNegativeAnchorAtHead() {
        // Re-anchoring near the head can't produce a negative start.
        let start = WaveformGesture.pagedStart(currentStart: 0.50, span: 0.20, playhead: 0.01)
        XCTAssertEqual(start, 0, accuracy: 1e-9)
    }
}
