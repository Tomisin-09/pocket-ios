import Foundation

/// The profile-driven **emphasis mix** (ADR 0113 Slice 3): a pure multiplier the planner folds into
/// each candidate's goal `priority` so "Today's session" tilts toward the player's declared taste —
/// the **genres** they picked and the **dream** they named — without ever *excluding* what a goal put
/// on the table.
///
/// **Lift-only, capped.** Emphasis multiplies priority by a factor that is always `≥ 1.0`: it can
/// move a taste-matching candidate *up* the ranking, never punish or drop one (the same soft,
/// never-a-gate philosophy as the prereq down-weight, `CandidateDeriver`). The product is clamped to
/// `cap`, chosen so a fully-emphasised **Normal**-priority candidate (`1.0 × cap`) still ranks below
/// an explicit **High** goal (`GoalPriority.high.weight == 2.0`): your *stated* goal always outranks
/// your *taste* tilt.
///
/// `.neutral` (no genres, no dream — a skipped or absent profile) multiplies by `1.0` everywhere, so
/// the planner behaves exactly as it did before S3 when there's nothing to emphasise.
///
/// Foundation-only and unit-tested (AGENTS.md pure-logic rule); the impure `PracticePlanner` builds
/// one from the local `Profile` and hands it to `CandidateDeriver`.
struct PracticeEmphasis: Equatable {

    /// Per-lift factors and the ceiling on their product. Kept modest so emphasis nudges rather than
    /// dominates: one genre-matched skill *and* a dream-matched mode together reach `cap`, which is
    /// below `GoalPriority.high.weight` (2.0) — a High goal still wins.
    static let genreLift = 1.35
    static let dreamLift = 1.30
    static let cap = 1.6

    /// The union of skill ids the declared genres emphasise (via `GenreSkillMap`), de-duplicated.
    let genreSkillIDs: Set<String>
    /// The declared dream, if any — tilts toward its `emphasisedMode`.
    let dream: MusicalDream?

    /// The no-op emphasis: multiplies by `1.0` for every candidate. The planner's fallback for an
    /// untouched or fully-skipped profile.
    static let neutral = PracticeEmphasis(genreSkillIDs: [], dream: nil)

    /// Direct init (also backs `.neutral`); prefer `init(genres:dream:)` at call sites.
    private init(genreSkillIDs: Set<String>, dream: MusicalDream?) {
        self.genreSkillIDs = genreSkillIDs
        self.dream = dream
    }

    /// Build the emphasis from the raw profile fields (values, not a `Profile`, so this stays
    /// SwiftData-free). Empty genres + `nil` dream yields the neutral behaviour.
    init(genres: [MusicGenre], dream: MusicalDream?) {
        self.genreSkillIDs = Set(genres.flatMap(GenreSkillMap.skillIDs(for:)))
        self.dream = dream
    }

    /// The priority multiplier for a candidate that satisfies `skillID` and is practised in `mode`
    /// (both known to the deriver). Applies the genre lift when the skill is one the declared genres
    /// lean on, the dream lift when the candidate's mode matches the dream's tilt, then clamps the
    /// product to `cap`. Always `≥ 1.0`.
    func multiplier(forSkillID skillID: String, mode: SkillMode) -> Double {
        var factor = 1.0
        if genreSkillIDs.contains(skillID) { factor *= Self.genreLift }
        if let dream, dream.emphasisedMode == mode { factor *= Self.dreamLift }
        return min(factor, Self.cap)
    }
}
