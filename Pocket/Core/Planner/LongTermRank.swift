import Foundation

/// The **rank → pull** mapping for a `LongTermGoal` (ADR 0171 D3) — the long-term tier's answer to
/// `GoalPriority`, which is what the short-term tier uses. A today-goal is *weighted* (Low / Normal
/// / High); a long-term goal is *ranked*, and its position in the list is the only ordering it has.
/// This pure enum turns that position into the `weight` the deriver multiplies into candidate
/// priority, so rank is something the player can observe in a generated session rather than a label.
///
/// The scale is deliberately **commensurable with `GoalPriority`** (0.5 / 1.0 / 2.0), because both
/// tiers project into the same `[PlannerGoal]` pool and compete directly: the top-ranked long-term
/// goal outpulls a *Normal* today-goal but **never outpulls an explicit High one**. The player
/// opened "Today's session" and said what they want today; today wins when today is asked for.
///
/// Foundation-only, per the "pure logic stays pure" rule (AGENTS.md).
enum LongTermRank {

    /// The pull of the top-ranked goal (`order == 0`). Sits between `GoalPriority.normal` (1.0) and
    /// `.high` (2.0) — see the type doc for why it must not reach 2.0.
    static let topWeight = 1.5

    /// The floor the decay clamps to. Reached **exactly** at `order == 10`, which is the cap
    /// (ADR 0171 D4) — so within the list every rank is strictly above the floor and every rank
    /// therefore pulls differently. The floor only ever applies to data authored over the cap.
    static let floorWeight = 0.5

    /// How much pull one position costs.
    static let step = 0.1

    /// The stored `weight` a goal at zero-based list position `order` projects with. Monotonically
    /// decreasing, clamped to `floorWeight`; a negative order is treated as the top.
    static func weight(forOrder order: Int) -> Double {
        max(floorWeight, topWeight - Double(max(0, order)) * step)
    }

    /// The most long-term goals the list will author (ADR 0171 D4). Enforced at the add button, not
    /// by refusing a save — ADR 0015 S7's "one near-term goal" is about modesty, and ten is argued
    /// against it by **ranking**: an unranked list of ten is a pile, a ranked one is a priority
    /// order the planner obeys.
    static let maxGoals = 10
}
