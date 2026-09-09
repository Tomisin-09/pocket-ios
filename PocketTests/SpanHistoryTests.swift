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

    // MARK: widenTarget — coming back down the ladder a rung at a time

    func testWidensBackOneStepNotAllTheWay() {
        // Narrowed Mon → Wed → Thu. From Thursday's span the offer is *Wednesday's*, not the whole
        // lick it started as: isolating is a ladder, and you come back down it a rung at a time.
        let previous = [(start: 0.36, end: 0.58),      // Thu's row records Wed's span
                        (start: 0.24, end: 0.72)]      // Wed's row records Mon's span
        let target = SpanHistory.widenTarget(currentWidth: 0.10, previous: previous)
        XCTAssertEqual(target?.start ?? 0, 0.36, accuracy: 1e-9)
        XCTAssertEqual(target?.end ?? 0, 0.58, accuracy: 1e-9)
    }

    func testSkipsRecordedSpansThatAreNotWider() {
        // A slide (same width, different place) is in the history but is not somewhere to widen to.
        let previous = [(start: 0.50, end: 0.60),      // same width as now — skipped
                        (start: 0.24, end: 0.72)]
        let target = SpanHistory.widenTarget(currentWidth: 0.10, previous: previous)
        XCTAssertEqual(target?.start ?? 0, 0.24, accuracy: 1e-9)
    }

    func testNothingToWidenBackTo() {
        // A loop that has only ever been widened has nowhere to go, and offering its own bounds
        // would be an action that does nothing.
        XCTAssertNil(SpanHistory.widenTarget(currentWidth: 0.50,
                                             previous: [(start: 0.30, end: 0.60)]))
        XCTAssertNil(SpanHistory.widenTarget(currentWidth: 0.10, previous: []))
    }
}
