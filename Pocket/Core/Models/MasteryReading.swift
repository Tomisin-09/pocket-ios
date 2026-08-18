import Foundation

/// The **conditions a mastery rating was taken under** (ADR 0169) — the pure half of "a 5 is a 5 at
/// *some tempo*", shared by `Exercise` (absolute BPM + a rhythm) and `Loop` (a `×` fraction of
/// original).
///
/// Mastery and command tempo stay **two axes** — cleanliness and speed, never averaged (ADR 0036,
/// `PracticeFieldInfo.commandTempo`, `docs/manual/terms.md`). Nothing here derives one from the
/// other. What it adds is the missing *condition*: a rating records which command it describes, so
/// the app can tell a 5 earned at today's tempo from one earned two promotes ago. That is ADR 0121's
/// argument for `commandNotesPerBeat` ("a BPM without its note rate is only half a fact") applied to
/// the rating instead of the tempo, and `RhythmChange`'s doctrine for when measurement conditions
/// move: a reading whose conditions have changed is marked **stale**, never silently rewritten and
/// never wiped (ADR 0070 — the app does not change a number the player set).
///
/// Pure and **SwiftData-/SwiftUI-free** so the comparison rules stay unit-tested per AGENTS.md.
enum MasteryReading {

    /// How close two `×` speeds must be to count as the same reading. Loop commands are `Double`
    /// fractions written from whole-percent steppers (`percent / 100`), so an exact `!=` would call a
    /// reading stale on a representation artefact alone. Half a percent is well under the 1% the UI
    /// can express and well over the error `Double` introduces.
    static let speedTolerance = 0.005

    /// Whether an **exercise** rating's conditions have moved. Stale when the command has left the
    /// tempo the rating was given at, *or* when the rhythm has — 90 at eighths and 90 at sixteenths
    /// are not the same claim (ADR 0121).
    ///
    /// A rating with no stamp (`ratedAt == nil`) is **not** stale: pre-0169 ratings genuinely don't
    /// know their conditions, and calling them stale would demote every existing rating in the store
    /// on upgrade. Unknown is not the same as moved.
    static func isStale(ratedAt: Int?, ratedRhythm: Int?, command: Int, rhythm: Int?) -> Bool {
        guard let ratedAt else { return false }
        return ratedAt != command || ratedRhythm != rhythm
    }

    /// Whether a **loop** rating's conditions have moved, in `×` of original. No rhythm term — a
    /// loop's command is a fraction of the recording's own tempo, so the material carries its rhythm
    /// with it. Unstamped is not stale, for the same reason as above.
    static func isStale(ratedAt: Double?, command: Double) -> Bool {
        guard let ratedAt else { return false }
        return abs(ratedAt - command) > speedTolerance
    }

    /// What a read-back surface shows under a mastery row — the rating, the conditions it was given
    /// under, and whether those have since moved.
    ///
    /// Carries `rating` so a view holding an **edited** binding can tell that the caption still
    /// describes what it is showing. An editor that has walked the dots to 3 must not caption them
    /// with the conditions of the stored 5.
    struct Display: Equatable {
        /// The stored rating this describes, 0–5.
        var rating: Int
        /// The conditions, already formatted for the unit — "90 BPM · 8ths", "85%".
        var conditions: String
        /// Whether the command has since left those conditions.
        var isStale: Bool

        /// The caption itself. Stale reads as a fact about the *command*, not a verdict on the
        /// rating: the rating stands, the thing it was measured against has moved.
        var caption: String {
            isStale ? "Rated at \(conditions) — command has moved since" : "Rated at \(conditions)"
        }
    }
}
