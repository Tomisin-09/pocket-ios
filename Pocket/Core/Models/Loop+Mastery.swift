import Foundation

/// `Loop`'s **mastery reading** (ADR 0169) — the self-rating plus the command speed it was given at.
/// The mirror of `Exercise+Mastery.swift`, differing only in unit: a loop works in `×` of original
/// where an exercise works in absolute BPM, and a loop states no rhythm of its own.
///
/// Mastery and command tempo remain two axes (ADR 0036/0039); nothing here derives one from the
/// other. See `MasteryReading` for the shared rule, including why a command move sets the rating
/// aside (ADR 0250).
extension Loop {

    /// Set the self-rating **and stamp the command speed it was given at** (ADR 0169). The single
    /// write path, on the model for the same reason `promoteCommand` is — the routine Done screen
    /// commits a rating and an accepted promote together, and stamping at the write is what makes
    /// that ordering truthful. Clearing the rating clears the stamp.
    ///
    /// An unchanged value writes nothing, and a new one supersedes the set-aside rating — see
    /// `Exercise.rateMastery` for why both matter (ADR 0250).
    func rateMastery(_ value: Int?) {
        guard value != mastery else { return }
        mastery = value
        previousMastery = nil
        masteryAtSpeed = value == nil ? nil : command
    }

    /// Write the command and **set aside a rating the move leaves behind** (ADR 0250) — the path
    /// `promoteCommand`, `settleCommand` and the loop editor all write `commandTempo` through. The
    /// rule is `Exercise.moveCommand`'s: a stamped rating goes when its stamp no longer matches, an
    /// unstamped one when the effective speed actually changed — compared within
    /// `MasteryReading.speedTolerance`, because the run screen writes `percent / 100`. Never on a
    /// write that lands where it already was: `LoopRunView.persist` promotes on every Save and Start.
    func moveCommand(to speed: Double?) {
        let setsAside = ratingWouldBeSetAside(movingTo: speed)
        commandTempo = speed
        if setsAside { setRatingAside() }
    }

    /// Whether writing `speed` as the command would set the current rating aside — the rule
    /// `moveCommand` applies, asked ahead of time so the loop editor can show the dots it will save
    /// (blank, captioned "Last rated…") while the move is still only on screen.
    func ratingWouldBeSetAside(movingTo speed: Double?) -> Bool {
        guard mastery != nil else { return false }
        let after = speed ?? self.speed
        if let masteryAtSpeed { return MasteryReading.isStale(ratedAt: masteryAtSpeed, command: after) }
        return abs(after - command) > MasteryReading.speedTolerance
    }

    /// Move the current rating to `previousMastery`, keeping its stamp, so the loop reads unrated at
    /// its new speed and "Last rated…" can still be said (ADR 0250). Idempotent.
    func setRatingAside() {
        guard let mastery else { return }
        previousMastery = mastery
        self.mastery = nil
    }

    /// Whether the **current** rating's conditions have since moved — the command speed has left
    /// where it was taken. An unstamped rating (pre-0169) is **not** stale, and with no current
    /// rating there is nothing to be stale.
    var masteryIsStale: Bool {
        guard mastery != nil else { return false }
        return MasteryReading.isStale(ratedAt: masteryAtSpeed, command: command)
    }

    /// What a read-back surface captions the mastery row with — "Rated at 85%", "Last rated 5 at
    /// 85%" for a set-aside rating, or `nil` when there is nothing to report. Whole percent, the unit
    /// every loop surface renders a command in, so the caption and the command badge cannot disagree.
    var masteryReading: MasteryReading.Display? {
        let conditions = masteryAtSpeed.map { "\(Int(($0 * 100).rounded()))%" }
        if let mastery {
            guard let conditions else { return nil }
            return MasteryReading.Display(rating: mastery, conditions: conditions,
                                          isStale: masteryIsStale)
        }
        guard let previousMastery else { return nil }
        return MasteryReading.Display(rating: previousMastery, conditions: conditions,
                                      isStale: false, isPrevious: true)
    }
}
