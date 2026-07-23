import Foundation

/// The **front-half** of the V2 planner (ADR 0015): turns active goals into a ranked list of
/// `PlannerCandidate`s that the back-half (`SessionBuilder`) lays out into a session. Pure /
/// Foundation-only, so the selection rules are unit-tested and reusable by a future AI producer
/// (ADR 0002 — deferred), exactly like `SessionBuilder`.
///
/// Per active goal → each of its skills, routed by the taxonomy `default mode` (Decision 5):
///  - **Path A** (the four technique modes): resolve to library **exercises** via the coarse
///    `SkillFamilyMap` (Decision 4), plus any **loops** the user tagged with a matching skill bucket
///    (Slice 4, Decision 8), weighted by the goal (S5) and **soft-down-weighted** when the skill's
///    direct prerequisites are unrated / low-mastery (Decision 6 — a soft stage, never a hard gate:
///    the advanced thing still appears, just later in the U-shape).
///  - **Path B** (`repertoire` mode): resolve to the goal's **target song** — its loops plus the
///    song run itself (Decision 5). Song-routed, not skill-matched.
///
/// A skill with no goal never produces a candidate (S4); an exercise that no goal skill covers is
/// excluded. A unit surfaced by several goals keeps its **strongest** claim (max priority). The
/// dueScore multiply (recency × need) is *not* applied here — that stays in `SessionBuilder.select`
/// so need and recency compose once; the deriver only sets `priority` and passes mastery/recency
/// through. Composed, higher mastery therefore ranks a unit lower (via dueScore), per the ADR 0015
/// property list.
enum CandidateDeriver {

    /// Multiplier applied to a skill's goal weight for each **unmet** direct prerequisite
    /// (Decision 6). Compounds across several unmet prereqs but never drops below `prereqFloor`, so
    /// a hard-weighted advanced goal still schedules — the ADR 0016 ↔ 0071 reconciliation at the
    /// selection level (clean-before-fast, but never refuse what the player asked for).
    static let prereqPenalty = 0.6
    /// The floor the compounded prerequisite down-weight is clamped to — keeps the candidate
    /// present (never excluded), just later.
    static let prereqFloor = 0.3
    /// A prerequisite counts as **met** once the player's exercises for it average at least this
    /// mastery (0–5). Unrated (no rated exercise for the prereq) ⇒ unmet ⇒ down-weight — which, at
    /// cold-start where everything is unrated, simply ranks no-prereq beginner skills first.
    static let prereqReadyMastery = 2.0

    /// Derive the ranked candidate pool from the active goals over the projected library, tilted by
    /// the profile's `emphasis` (ADR 0113 S3 — a lift-only multiplier on `priority`, defaulting to
    /// `.neutral` so a profile-less call behaves exactly as before). Pure.
    static func deriveCandidates(goals: [PlannerGoal], library: PlannerLibrary,
                                 emphasis: PracticeEmphasis = .neutral) -> [PlannerCandidate] {
        var strongest: [PlannerUnitRef: PlannerCandidate] = [:]

        for goal in goals where !goal.isMet {
            for skillID in goal.skillIDs {
                guard let info = TechniqueTaxonomy.info(skillID) else { continue }  // unknown ⇒ skip
                let resolved = info.mode.isRepertoire
                    ? repertoireCandidates(goal: goal, skillID: skillID, library: library,
                                           emphasis: emphasis)
                    : techniqueCandidates(goal: goal, info: info, library: library,
                                          emphasis: emphasis)
                for candidate in resolved {
                    if let existing = strongest[candidate.unit], existing.priority >= candidate.priority {
                        continue  // keep the strongest claim on a unit surfaced by several goals
                    }
                    strongest[candidate.unit] = candidate
                }
            }
        }
        return Array(strongest.values)
    }

    /// **Path A** — a technique skill resolves to every library **exercise** whose template can serve
    /// it (`SkillFamilyMap`), plus any **loop** the user has tagged with a skill bucket that serves it
    /// (Slice 4, Decision 8 — untagged loops carry no template and stay Path-B only). Each candidate
    /// carries the goal weight softened by prerequisite readiness.
    private static func techniqueCandidates(goal: PlannerGoal,
                                            info: SkillInfo,
                                            library: PlannerLibrary,
                                            emphasis: PracticeEmphasis) -> [PlannerCandidate] {
        let priority = goal.weight * prereqReadiness(for: info, library: library)
            * emphasis.multiplier(forSkillID: info.id, mode: info.mode)
        let exercises = library.exercises
            .filter { SkillFamilyMap.template($0.template, serves: info.id) }
            .map { exercise in
                PlannerCandidate(unit: PlannerUnitRef(exercise.uid, .exercise),
                                 priority: priority,
                                 mastery: exercise.mastery,
                                 lastPracticed: exercise.lastPracticed,
                                 estimatedMinutes: exercise.estimatedMinutes,
                                 skillID: info.id)
            }
        let loops = library.loops
            .filter { loop in loop.templates.contains { SkillFamilyMap.template($0, serves: info.id) } }
            .map { loop in
                PlannerCandidate(unit: PlannerUnitRef(loop.uid, .loop),
                                 priority: priority,
                                 mastery: loop.mastery,
                                 lastPracticed: loop.lastPracticed,
                                 estimatedMinutes: loop.estimatedMinutes,
                                 skillID: info.id)
            }
        return exercises + loops
    }

    /// **Path B** — a repertoire skill resolves to the goal's target song: its loops, then the song
    /// run itself. No prerequisite down-weight (repertoire prereqs are themselves song-routed).
    private static func repertoireCandidates(goal: PlannerGoal,
                                             skillID: String,
                                             library: PlannerLibrary,
                                             emphasis: PracticeEmphasis) -> [PlannerCandidate] {
        guard let songUID = goal.targetSongUID else { return [] }
        // Repertoire is always the `.repertoire` mode; the emphasis lift applies to the whole path.
        let priority = goal.weight * emphasis.multiplier(forSkillID: skillID, mode: .repertoire)
        var result: [PlannerCandidate] = library.loops
            .filter { $0.songUID == songUID }
            .map { loop in
                PlannerCandidate(unit: PlannerUnitRef(loop.uid, .loop),
                                 priority: priority,
                                 mastery: loop.mastery,
                                 lastPracticed: loop.lastPracticed,
                                 estimatedMinutes: loop.estimatedMinutes,
                                 skillID: skillID)
            }
        if let song = library.songs.first(where: { $0.uid == songUID }) {
            result.append(PlannerCandidate(unit: PlannerUnitRef(song.uid, .song),
                                           priority: priority,
                                           mastery: nil,  // song mastery is derived; treat run as max-due
                                           lastPracticed: song.lastPracticed,
                                           estimatedMinutes: song.estimatedMinutes,
                                           skillID: skillID))
        }
        return result
    }

    /// The soft prerequisite down-weight for a skill (Decision 6): `prereqPenalty` per unmet direct
    /// prereq, compounded, clamped to `prereqFloor`. `1.0` when every prereq is met (or there are
    /// none). Pure; exposed for unit testing.
    static func prereqReadiness(for info: SkillInfo, library: PlannerLibrary) -> Double {
        var factor = 1.0
        for prereq in info.prereqs where !prereqMet(prereq, library: library) {
            factor *= prereqPenalty
        }
        return max(prereqFloor, factor)
    }

    /// Whether a prerequisite skill is "met": the player's exercises for it (via the family map)
    /// average at least `prereqReadyMastery`. No rated exercise ⇒ unmet (unrated = not demonstrated).
    private static func prereqMet(_ skillID: String, library: PlannerLibrary) -> Bool {
        let rated = library.exercises
            .filter { SkillFamilyMap.template($0.template, serves: skillID) }
            .compactMap(\.mastery)
        guard !rated.isEmpty else { return false }
        let average = Double(rated.reduce(0, +)) / Double(rated.count)
        return average >= prereqReadyMastery
    }
}
