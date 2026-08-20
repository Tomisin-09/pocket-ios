import Foundation

/// The **pure** half of trimming a practice take (ADR 0174): position ↔ fraction for a take's
/// timeline, and the rules that decide whether a chosen span is worth committing.
///
/// Free of SwiftUI and AVFoundation, because this is the arithmetic that breaks silently — a
/// fraction mapped against the wrong length, a span that ordered itself backwards, a "trim" that
/// removes nothing — and none of it is visible in a screenshot. The I/O half is `TakeTrimmer`,
/// which does the one thing this cannot: rewrite the file.
enum TakeTrim {

    /// The shortest take a trim may leave behind. A second is already generous against
    /// `RecordingController.minTakeDuration` (half a second, the accidental-run threshold) — the
    /// point is that a destructive trim should never be the way a take becomes unusable, and a span
    /// this narrow is far more likely to be a slipped handle than an intention.
    static let minimumKeep: TimeInterval = 1.0

    /// How close to an edge still counts as *at* the edge. A handle parked within this of the start
    /// or the end is treated as covering it, so a trim that would rewrite the whole file to shave
    /// two hundredths of a second is recognised as the no-op it is.
    static let edgeTolerance: TimeInterval = 0.05

    /// Where `time` sits in a take of `duration`, as `0…1`. Zero for a take with no length, so a
    /// scrubber over an empty or still-loading take renders at the start rather than dividing by
    /// nothing.
    static func fraction(of time: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1)
    }

    /// The time a `0…1` fraction points at in a take of `duration`.
    static func time(at fraction: Double, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return min(max(fraction, 0), 1) * duration
    }

    /// Turn two fractional handle positions into an ordered, clamped keep-span in seconds.
    ///
    /// Ordered because the handles are draggable past one another and the caller should not have to
    /// care which is which; widened to `minimumKeep` because two handles that land on top of each
    /// other describe a take with nothing in it. The widening grows the span **away from whichever
    /// edge it can reach**, so a span pinned at the end of a take still widens (backwards) instead
    /// of silently clamping to a zero-length keep.
    static func span(from first: Double, to second: Double,
                     duration: TimeInterval) -> (start: TimeInterval, end: TimeInterval) {
        guard duration > 0 else { return (0, 0) }
        let lower = time(at: min(first, second), duration: duration)
        let upper = time(at: max(first, second), duration: duration)
        let keep = min(minimumKeep, duration)
        guard upper - lower < keep else { return (lower, upper) }
        // Too narrow: grow forwards if there is room ahead, otherwise backwards from the end.
        if lower + keep <= duration { return (lower, lower + keep) }
        return (duration - keep, duration)
    }

    /// How much audio a trim to `start…end` would remove from a take of `duration` — the number the
    /// confirmation puts in front of the player, because "this can't be undone" means little without
    /// saying what goes.
    static func removed(start: TimeInterval, end: TimeInterval,
                        duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        let span = span(from: fraction(of: start, duration: duration),
                        to: fraction(of: end, duration: duration), duration: duration)
        return max(0, duration - (span.end - span.start))
    }

    /// Whether a trim to `start…end` would change anything. Both handles sitting at the edges (within
    /// `edgeTolerance`) means the span is the whole take, and committing it would rewrite every byte
    /// of the file — irreversibly, and through an encoder — to arrive back where it started. The
    /// commit control is disabled on this, rather than the trim being attempted and quietly wasted.
    static func isNoOp(start: TimeInterval, end: TimeInterval, duration: TimeInterval) -> Bool {
        guard duration > 0 else { return true }
        return start <= edgeTolerance && end >= duration - edgeTolerance
    }
}
