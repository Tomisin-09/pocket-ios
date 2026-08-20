import Foundation

/// The **pure** half of pinning notes to points in a take (ADR 0175): what a trim does to the marks
/// that were placed against the old timeline.
///
/// Free of SwiftUI and SwiftData for the reason `TakeTrim` is — this is arithmetic that fails
/// silently. A moment that keeps its old seconds after a trim still renders perfectly: a plausible
/// timecode, a mark on the strip, and audio underneath it that is not what the note is about. There
/// is no crash and no empty state to notice, which is exactly why it is unit-tested rather than
/// eyeballed.
enum TakeMoments {

    /// What a trim does to one moment.
    enum Rebase: Equatable {
        /// The moment survives, at this position on the **new** timeline.
        case keep(TimeInterval)
        /// The moment pointed at audio the trim removes, and goes with it.
        case drop
    }

    /// Where a moment at `time` lands after a trim that keeps `keepStart…keepEnd`.
    ///
    /// Trimming moves the take's zero, so a surviving moment is rebased by `keepStart` — a note at
    /// 1:20 in a take trimmed to keep 0:40 onward is a note at 0:40, still over the same audio.
    ///
    /// **A moment outside the span is dropped, not clamped.** Clamping keeps a row that now points
    /// at audio it was never about, and stacks several of them on one instant; the note is a pointer
    /// into a passage, and when the passage goes there is nothing honest left for it to point at.
    /// The trim confirmation names how many will go, which is what makes the loss a choice.
    ///
    /// `TakeTrim.edgeTolerance` of grace at each end: handles are placed by eye, and a moment
    /// sitting a few hundredths outside one should not have its fate decided by that.
    static func rebase(time: TimeInterval, keepStart: TimeInterval,
                       keepEnd: TimeInterval) -> Rebase {
        let tolerance = TakeTrim.edgeTolerance
        guard time >= keepStart - tolerance, time <= keepEnd + tolerance else { return .drop }
        let kept = max(0, keepEnd - keepStart)
        return .keep(min(max(time - keepStart, 0), kept))
    }

    /// Apply `rebase` across a take's moments in one pass — the new positions in the order given,
    /// and how many were dropped.
    ///
    /// Returned together because the caller needs both at once and computing them separately is how
    /// the confirmation's count drifts from what the commit actually does.
    static func rebase(times: [TimeInterval], keepStart: TimeInterval,
                       keepEnd: TimeInterval) -> (kept: [TimeInterval?], dropped: Int) {
        var kept: [TimeInterval?] = []
        var dropped = 0
        for time in times {
            switch rebase(time: time, keepStart: keepStart, keepEnd: keepEnd) {
            case .keep(let rebased): kept.append(rebased)
            case .drop:
                kept.append(nil)
                dropped += 1
            }
        }
        return (kept, dropped)
    }

    /// How many of `times` a trim to `keepStart…keepEnd` would remove — the number the confirmation
    /// puts in front of the player, beside the seconds `TakeTrim.removed` gives it.
    static func droppedCount(times: [TimeInterval], keepStart: TimeInterval,
                             keepEnd: TimeInterval) -> Int {
        rebase(times: times, keepStart: keepStart, keepEnd: keepEnd).dropped
    }

    /// "2 notes" / "1 note" — the fragment the trim warning splices in. Here rather than in the view
    /// because it is the half of that sentence that can be got wrong, and the only half worth
    /// asserting.
    static func noteCountPhrase(_ count: Int) -> String {
        count == 1 ? "1 note" : "\(count) notes"
    }
}
