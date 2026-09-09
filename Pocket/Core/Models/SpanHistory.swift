import Foundation

/// Pure decisions about a loop's span history (ADR 0199) — free of SwiftData and SwiftUI so the
/// rules that decide *whether* an edit is worth recording, and *what kind* of edit it was, are
/// unit-testable without a model container.
enum SpanHistory {

    /// How much either edge must move before an edit counts as an edit, as a fraction of the song.
    ///
    /// This is float hygiene, not a meaningful threshold. Every recorded change is an explicit
    /// **Save**, so intent is never in doubt — the only thing being filtered is a save where the
    /// player moved nothing and the two `Double`s differ in their last bits. A real threshold would
    /// be wrong here: a two-frame trim at the top of a phrase is a small number and a deliberate act.
    static let epsilon = 1e-9

    /// Did the span actually move? The guard on the write: opening a loop's range editor and saving
    /// without touching a handle must not manufacture a history row that says nothing happened.
    static func changed(fromStart previousStart: Double, end previousEnd: Double,
                        toStart start: Double, end: Double) -> Bool {
        abs(start - previousStart) > epsilon || abs(end - previousEnd) > epsilon
    }

    /// What an edit did to the span.
    ///
    /// Width is the axis that matters — narrowing is the research-relevant act (isolate the failing
    /// move, slow it, re-enter it), widening is its inverse and the test of whether it stuck. A span
    /// that keeps its width and slides along the song is neither, and calling it either would put a
    /// false claim into anything that reads this back.
    enum Kind: String, CaseIterable {
        case narrowed, widened, moved
    }

    /// The span to offer widening back to (ADR 0201), or `nil` when there is nothing to go back to.
    ///
    /// `previous` is the recorded history **newest first**; the answer is the first entry that was
    /// genuinely wider than where the loop sits now. Walking from the newest rather than reaching
    /// for the widest matters: a loop narrowed in three steps should widen back **one step**, to
    /// the size it was working at yesterday, not leap to the whole lick it started as. Isolating is
    /// a ladder, and coming back down it a rung at a time is the point.
    ///
    /// Returns `nil` when every recorded span is the same width or narrower — a loop that has only
    /// ever been widened has nowhere to go, and offering it its own bounds would be an action that
    /// does nothing.
    static func widenTarget(currentWidth: Double,
                            previous: [(start: Double, end: Double)]) -> (start: Double, end: Double)? {
        previous.first { $0.end - $0.start > currentWidth + epsilon }
    }

    /// Classify an edit by comparing widths. Equal widths (within `epsilon`) are `.moved` — including
    /// the degenerate case where nothing moved at all, which `changed(...)` should have caught first.
    static func kind(fromStart previousStart: Double, end previousEnd: Double,
                     toStart start: Double, end: Double) -> Kind {
        let before = previousEnd - previousStart
        let after = end - start
        if after < before - epsilon { return .narrowed }
        if after > before + epsilon { return .widened }
        return .moved
    }
}
