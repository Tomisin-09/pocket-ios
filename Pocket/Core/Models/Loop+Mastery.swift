import Foundation

/// `Loop`'s **mastery reading** (ADR 0169) — the self-rating plus the command speed it was given at.
/// The mirror of `Exercise+Mastery.swift`, differing only in unit: a loop works in `×` of original
/// where an exercise works in absolute BPM, and a loop states no rhythm of its own.
///
/// Mastery and command tempo remain two axes (ADR 0036/0039); nothing here derives one from the
/// other. See `MasteryReading` for the shared rule.
extension Loop {

    /// Set the self-rating **and stamp the command speed it was given at** (ADR 0169). The single
    /// write path, on the model for the same reason `promoteCommand` is — the routine Done screen
    /// commits a rating and an accepted promote together, and stamping at the write is what makes
    /// that ordering truthful. Clearing the rating clears the stamp.
    func rateMastery(_ value: Int?) {
        mastery = value
        masteryAtSpeed = value == nil ? nil : command
    }

    /// Whether the rating's conditions have since moved — the command speed has left where the
    /// rating was taken. An unstamped rating (pre-0169) is **not** stale.
    var masteryIsStale: Bool {
        MasteryReading.isStale(ratedAt: masteryAtSpeed, command: command)
    }

    /// What a read-back surface captions the mastery row with — "Rated at 85%", or `nil` when there
    /// is no rating or no stamp to report. Whole percent, the unit every loop surface renders a
    /// command in, so the caption and the command badge cannot disagree.
    var masteryReading: MasteryReading.Display? {
        guard let mastery, let masteryAtSpeed else { return nil }
        return MasteryReading.Display(rating: mastery,
                                      conditions: "\(Int((masteryAtSpeed * 100).rounded()))%",
                                      isStale: masteryIsStale)
    }
}
