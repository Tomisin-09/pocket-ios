import Foundation

/// The planner's **selection ranking** (V2 planner, ADR 0015 S5) — the single formula that
/// decides how much a candidate wants scheduling *right now*:
///
/// ```
/// dueScore = goalWeight × dueness(lastPracticed, now) × (1 − mastery/5)
/// ```
///
/// Pure and **SwiftData-/SwiftUI-free** (Foundation only), so it stays unit-tested per
/// AGENTS.md and reusable by a future AI producer (ADR 0002).
///
/// **Static rating, time-driven resurfacing (ADR 0070):** `mastery` is a stored
/// self-assessment the app NEVER auto-decays. The `dueness(lastPracticed)` term alone brings a
/// well-learned drill (mastery 1–4) back as time passes; a fully-owned drill (mastery 5) is
/// retired from rotation (its `1 − 5/5 = 0` term) until the player themself lowers the rating —
/// we never silently change a number the player set.
enum DueScore {

    /// The decay constant for `dueness`, in days: how quickly an unpractised item climbs back
    /// toward maximum due. At ~7 days a drill sits around 63% due; it keeps rising (never
    /// saturating) so ordering by recency is always strict.
    static let duenessTauDays = 7.0

    /// **Dueness** — rises monotonically with time since the item was last practised (ADR 0015
    /// S5). Never-practised (`lastPracticed == nil`) is treated as **max-due** (`1.0`), which is
    /// exactly right for cold-start: things you've never touched surface first. A smooth
    /// `1 − e^(−elapsed/τ)` curve: strictly increasing for all finite elapsed times (so equal
    /// budgets rank by recency), asymptoting toward — but never reaching — `1.0`, so a
    /// never-practised item always outranks any practised one.
    static func dueness(lastPracticed: Date?, now: Date) -> Double {
        guard let last = lastPracticed else { return 1.0 }
        let elapsedDays = max(0, now.timeIntervalSince(last)) / 86_400
        return 1.0 - exp(-elapsedDays / duenessTauDays)
    }

    /// The **mastery term** — falls as the player rates the item more settled (ADR 0015 S5).
    /// Unrated (`nil`) is treated as max-due (`1.0`, as if mastery 0): a drill you've never
    /// judged is assumed to still need work. `mastery 5` yields `0` — fully owned, retired from
    /// rotation until re-rated. Clamped to `0…5` defensively.
    static func masteryTerm(_ mastery: Int?) -> Double {
        guard let mastery else { return 1.0 }
        let clamped = min(5, max(0, mastery))
        return 1.0 - Double(clamped) / 5.0
    }

    /// The full dueScore for a candidate at `now` (ADR 0015 S5). Higher ⇒ wants scheduling more.
    /// A non-positive `priority` (no active goal — ADR 0015 S4) yields `0`; the caller excludes
    /// those before selection.
    static func score(_ candidate: PlannerCandidate, now: Date) -> Double {
        candidate.priority
            * dueness(lastPracticed: candidate.lastPracticed, now: now)
            * masteryTerm(candidate.mastery)
    }
}
