import Foundation

/// What the **read-only Progress echo** says about one long-term goal (ADR 0171 D7) — facts, in the
/// `PracticeProgress.hourMilestones` register: *"a wall you pass rather than a ladder you're being
/// timed on."*
///
/// **What is deliberately absent is the design.** There is no "3 of 5 skills covered", no
/// percentage, no bar, no ETA and no "behind" state, because `PracticeLog` is blunt about why —
/// *"a denominator states a target, and a target is habit-pressure under another name."* A skill
/// **count** is a fact about the goal; a skill count over a total would be a score.
struct LongTermGoalReading: Equatable {
    /// Which goal this describes.
    var goalUID: UUID
    /// How many skills the goal names. A count, never a numerator.
    var skillCount: Int
    /// When something that serves this goal was last practised — `nil` for "not yet".
    var lastServed: Date?
}

/// Builds the echo's readings. Pure and Foundation-only, per the "pure logic stays pure" rule.
///
/// **This re-uses `CandidateDeriver` rather than walking skill → unit itself, and that is the whole
/// point of the type** (ADR 0171 D7). `PracticeRun` records a `unitUID` and has **no goal
/// reference** — a run never records which goal it served, and candidates are derived at plan time
/// — so attributing practice to a goal after the fact is necessarily a re-derivation. Doing that
/// re-derivation with a second, hand-rolled skill→unit walk would create a lookalike that could
/// drift from the planner's answer. Asking the deriver means the screen attributes exactly what the
/// planner would schedule, by construction.
///
/// The attribution is therefore **approximate** in the same way the planner is (`SkillFamilyMap` is
/// coarse: a goal naming "sweep picking" is served by any Picking exercise). That is fine for a
/// reflection and would be unacceptable for a score — which is why this produces neither.
enum LongTermGoalEcho {

    /// A reading per goal, in the order given. A **met** goal derives no candidates (the deriver
    /// skips `isMet`), so it reads `lastServed == nil`; the caller presents met goals without facts
    /// rather than showing them as "not yet".
    ///
    /// Goals are derived **one at a time** on purpose. `deriveCandidates` keeps only the strongest
    /// claim on each unit, so deriving the whole list at once would let a higher-ranked goal take
    /// sole credit for a unit two goals share — and the echo would then say "not yet" about a goal
    /// whose material the player practised this morning.
    static func readings(for goals: [PlannerGoal], library: PlannerLibrary) -> [LongTermGoalReading] {
        goals.map { goal in
            let candidates = CandidateDeriver.deriveCandidates(goals: [goal], library: library)
            return LongTermGoalReading(goalUID: goal.uid,
                                       skillCount: goal.skillIDs.count,
                                       lastServed: candidates.compactMap(\.lastPracticed).max())
        }
    }
}
