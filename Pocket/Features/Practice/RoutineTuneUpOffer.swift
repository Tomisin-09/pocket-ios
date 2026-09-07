import Foundation

/// When a routine **asks** whether to tune up before block 1 (ADR 0195) — the whole rule, pure, so
/// the "never repeated within a session" half is a tested fact rather than a claim about a `@State`
/// flag's history.
///
/// Three conditions, and the interesting one is the first. `RoutinePlayerView.onAppear` re-fires
/// every time the player comes back to the front, so a rule that only read the preference would put
/// the offer up again between blocks four and five — the same failure ADR 0120's analytics latch and
/// ADR 0113's one-time profile moments each had to solve on their own. `alreadyDecided` is that
/// latch, and it is set whether or not an offer is actually made: *deciding not to offer* is a
/// decision, and re-deciding it on the next appear would reopen the same hole.
enum RoutineTuneUpOffer {

    /// Whether to put the offer up now.
    ///
    /// - Parameters:
    ///   - alreadyDecided: whether this presentation of the player has already been through here.
    ///   - isEnabled: `Settings ▸ Routines ▸ Ask to tune up`, which the prompt's own
    ///     `Don't ask again` also writes.
    ///   - hasStages: whether the routine has anything to play. An all-orphaned routine lands
    ///     straight on the summary screen, and offering to tune up for it would be the app asking
    ///     you to prepare for nothing.
    static func shouldOffer(alreadyDecided: Bool, isEnabled: Bool, hasStages: Bool) -> Bool {
        guard !alreadyDecided else { return false }
        return isEnabled && hasStages
    }
}
