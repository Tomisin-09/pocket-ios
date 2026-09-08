import XCTest
@testable import Pocket

/// The pure rules behind loop span history (ADR 0199): whether an edit is worth recording, and
/// what kind of edit it was. Both sit on the write path in `saveABSpan`, where getting them wrong
/// is invisible — a missing row looks exactly like a loop nobody edited.
final class SpanHistoryTests: XCTestCase {

    // MARK: changed — the guard on the write

    func testAnUnmovedSaveRecordsNothing() {
        // Open the range editor, touch nothing, press Save. There is no edit to record, and a row
        // here would claim one.
        XCTAssertFalse(SpanHistory.changed(fromStart: 0.3, end: 0.5, toStart: 0.3, end: 0.5))
    }

    func testFloatNoiseIsNotAnEdit() {
        XCTAssertFalse(SpanHistory.changed(fromStart: 0.3, end: 0.5,
                                           toStart: 0.3 + 1e-15, end: 0.5 - 1e-15))
    }

    func testEitherEdgeMovingCounts() {
        XCTAssertTrue(SpanHistory.changed(fromStart: 0.3, end: 0.5, toStart: 0.32, end: 0.5))
        XCTAssertTrue(SpanHistory.changed(fromStart: 0.3, end: 0.5, toStart: 0.3, end: 0.48))
    }

    func testATinyDeliberateTrimIsAnEdit() {
        // Deliberately *not* filtered by a "meaningful change" threshold: trimming two frames off
        // the top of a phrase is a small number and a real act. The epsilon is float hygiene only.
        XCTAssertTrue(SpanHistory.changed(fromStart: 0.30000, end: 0.5,
                                          toStart: 0.30001, end: 0.5))
    }

    // MARK: kind — width is the axis

    func testNarrowing() {
        XCTAssertEqual(SpanHistory.kind(fromStart: 0.2, end: 0.8, toStart: 0.4, end: 0.6), .narrowed)
    }

    func testWidening() {
        XCTAssertEqual(SpanHistory.kind(fromStart: 0.4, end: 0.6, toStart: 0.2, end: 0.8), .widened)
    }

    func testASpanThatSlidesIsMovedNotNarrowed() {
        // Same width, different place. Calling this a narrowing would put a false claim into
        // everything downstream that reads the history back.
        XCTAssertEqual(SpanHistory.kind(fromStart: 0.2, end: 0.4, toStart: 0.5, end: 0.7), .moved)
    }

    func testTrimmingOneEdgeNarrows() {
        XCTAssertEqual(SpanHistory.kind(fromStart: 0.2, end: 0.8, toStart: 0.2, end: 0.6), .narrowed)
        XCTAssertEqual(SpanHistory.kind(fromStart: 0.2, end: 0.8, toStart: 0.5, end: 0.8), .narrowed)
    }

    // MARK: LoopSpanChange — the record itself

    func testARecordCarriesBothSpans() {
        // Self-contained by design: one row answers "widen back to where it was" without walking
        // the chain, and a loop that predates this ADR loses nothing — its first row carries the
        // bounds it was created with.
        let change = LoopSpanChange(start: 0.42, end: 0.52,
                                    previousStart: 0.24, previousEnd: 0.72,
                                    speed: 0.72, songDuration: 240)
        XCTAssertEqual(change.width, 0.10, accuracy: 1e-9)
        XCTAssertEqual(change.previousWidth, 0.48, accuracy: 1e-9)
        XCTAssertEqual(SpanHistory.kind(fromStart: change.previousStart, end: change.previousEnd,
                                        toStart: change.start, end: change.end), .narrowed)
    }

    func testSecondsAreDerivedFromTheRecordedDuration() {
        // Read back in seconds without the audio still being linked (ADR 0152 relinking) — the
        // duration at write time is stored on the row for exactly that reason.
        let change = LoopSpanChange(start: 0.42, end: 0.52,
                                    previousStart: 0.24, previousEnd: 0.72,
                                    speed: 0.72, songDuration: 240)
        XCTAssertEqual(try XCTUnwrap(change.widthSeconds), 24, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(change.previousWidthSeconds), 115.2, accuracy: 1e-6)
    }

    func testSecondsAreNilWithoutARecordedDuration() {
        let change = LoopSpanChange(start: 0.4, end: 0.5, previousStart: 0.2, previousEnd: 0.8)
        XCTAssertNil(change.widthSeconds)
        XCTAssertNil(change.previousWidthSeconds)
    }

    func testSpeedIsOptionalAndMeansUnrecorded() {
        // nil is "the speed wasn't readable", never "1.0×" — the same rule mastery and
        // commandTempo follow on Loop.
        let change = LoopSpanChange(start: 0.4, end: 0.5, previousStart: 0.2, previousEnd: 0.8)
        XCTAssertNil(change.speed)
    }
}
