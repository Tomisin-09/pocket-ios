import Foundation

/// Which take a routine block's **Done screen** offers to play back (ADR 0179).
///
/// Pure and store-free, so the rule that decides "did *this* run record something?" is unit-testable
/// without a `ModelContainer` — the discipline AGENTS.md asks of every non-trivial UI-free decision.
///
/// The rule is a cutoff, not a "most recent": a unit practised before already holds takes, and
/// `recordingsByRecent.first` on such a unit is a recording from some earlier day. Offering it on a
/// completion beat would tell the player they had just captured something they captured last week —
/// which is worse than offering nothing, because they would believe it.
enum RoutineTakeLookup {

    /// The newest take in `takes` captured at or after `since`, or `nil` when this run recorded
    /// nothing.
    ///
    /// - Parameters:
    ///   - takes: the owner's takes, in any order — this sorts rather than trusting a caller's.
    ///   - since: when the block began. `nil` means the block's start was never stamped, which is not
    ///     a licence to fall back on the newest take: with no cutoff there is no way to tell this
    ///     run's recording from any other, so the honest answer is `nil`.
    static func take(from takes: [Recording], since: Date?) -> Recording? {
        guard let since else { return nil }
        return takes.filter { $0.createdAt >= since }.max { $0.createdAt < $1.createdAt }
    }
}
