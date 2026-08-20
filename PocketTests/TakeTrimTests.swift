import XCTest
@testable import Pocket

/// The **pure** trim arithmetic (ADR 0174) — position ↔ fraction on a take's timeline, and the rules
/// deciding whether a chosen span is worth committing.
///
/// This is the logic AGENTS.md says must be unit-tested: none of it is visible in a screenshot, and
/// every failure here is silent and destructive. A span that ordered itself backwards, a fraction
/// mapped against the wrong length, or a "trim" that the no-op guard failed to catch all end with a
/// take being re-encoded to something the player didn't ask for — and a take has no source to
/// regenerate from.
final class TakeTrimTests: XCTestCase {

    // MARK: - Position ↔ fraction

    func testFractionOfTimeIsProportionOfDuration() {
        XCTAssertEqual(TakeTrim.fraction(of: 30, duration: 120), 0.25, accuracy: 1e-9)
    }

    func testFractionClampsOutsideTheTake() {
        XCTAssertEqual(TakeTrim.fraction(of: -5, duration: 120), 0)
        XCTAssertEqual(TakeTrim.fraction(of: 500, duration: 120), 1)
    }

    /// A take still extracting has no length yet, and the scrubber asks for a fraction anyway. Zero,
    /// not a division by nothing.
    func testFractionOfAZeroLengthTakeIsZero() {
        XCTAssertEqual(TakeTrim.fraction(of: 10, duration: 0), 0)
    }

    func testTimeAtFractionIsTheInverse() {
        XCTAssertEqual(TakeTrim.time(at: 0.25, duration: 120), 30, accuracy: 1e-9)
        XCTAssertEqual(TakeTrim.time(at: 1.5, duration: 120), 120, accuracy: 1e-9,
                       "a fraction past the end lands at the end")
    }

    // MARK: - The keep-span

    func testSpanOrdersItsHandles() {
        // The handles are draggable past one another; the caller shouldn't have to care which is
        // which.
        let span = TakeTrim.span(from: 0.8, to: 0.2, duration: 100)
        XCTAssertEqual(span.start, 20, accuracy: 1e-9)
        XCTAssertEqual(span.end, 80, accuracy: 1e-9)
    }

    /// Two handles on top of each other describe a take with nothing in it. The span widens instead.
    func testSpanWidensToTheMinimumKeep() {
        let span = TakeTrim.span(from: 0.5, to: 0.5, duration: 100)
        XCTAssertEqual(span.end - span.start, TakeTrim.minimumKeep, accuracy: 1e-9)
    }

    /// The case a naive "grow forwards" gets wrong: a span pinned at the very end has no room ahead,
    /// so it must widen *backwards* rather than clamp to a zero-length keep.
    func testSpanPinnedAtTheEndWidensBackwards() {
        let duration = 100.0
        let span = TakeTrim.span(from: 1.0, to: 1.0, duration: duration)
        XCTAssertEqual(span.end, duration, accuracy: 1e-9)
        XCTAssertEqual(span.end - span.start, TakeTrim.minimumKeep, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(span.start, 0)
    }

    /// A take shorter than the minimum keep can't be widened to it — the span is the whole take.
    func testSpanOnATakeShorterThanTheMinimumKeepIsTheWholeTake() {
        let duration = 0.4
        let span = TakeTrim.span(from: 0.5, to: 0.5, duration: duration)
        XCTAssertEqual(span.start, 0, accuracy: 1e-9)
        XCTAssertEqual(span.end, duration, accuracy: 1e-9)
    }

    func testSpanOfAZeroLengthTakeIsEmpty() {
        let span = TakeTrim.span(from: 0.2, to: 0.8, duration: 0)
        XCTAssertEqual(span.start, 0)
        XCTAssertEqual(span.end, 0)
    }

    // MARK: - What a trim removes

    func testRemovedIsWhatFallsOutsideTheSpan() {
        XCTAssertEqual(TakeTrim.removed(start: 20, end: 80, duration: 100), 40, accuracy: 1e-9)
    }

    func testRemovedIsZeroForASpanCoveringTheWholeTake() {
        XCTAssertEqual(TakeTrim.removed(start: 0, end: 100, duration: 100), 0, accuracy: 1e-9)
    }

    // MARK: - The no-op guard

    /// The guard that stops a trim rewriting every byte of a file, irreversibly and through an
    /// encoder, to arrive back where it started.
    func testWholeTakeSpanIsANoOp() {
        XCTAssertTrue(TakeTrim.isNoOp(start: 0, end: 100, duration: 100))
    }

    /// Handles within the edge tolerance still count as *at* the edges — a slipped handle two
    /// hundredths of a second in is not a trim anyone asked for.
    func testSpanWithinTheEdgeToleranceIsStillANoOp() {
        XCTAssertTrue(TakeTrim.isNoOp(start: TakeTrim.edgeTolerance / 2,
                                      end: 100 - TakeTrim.edgeTolerance / 2, duration: 100))
    }

    func testTrimmingOneEndIsNotANoOp() {
        XCTAssertFalse(TakeTrim.isNoOp(start: 10, end: 100, duration: 100),
                       "a trim that removes the first ten seconds is real work")
        XCTAssertFalse(TakeTrim.isNoOp(start: 0, end: 90, duration: 100),
                       "and so is one that removes the last ten")
    }

    func testEverythingIsANoOpOnAZeroLengthTake() {
        XCTAssertTrue(TakeTrim.isNoOp(start: 0, end: 0, duration: 0))
    }
}
