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
/// we never silently change a number the player set. **Unless the reading is stale** (ADR 0169): a
/// rating given at a command tempo the drill has since left is floored at `staleMasteryFloor` rather
/// than zeroed, so promoting a drill leaves it competing for a slot rather than sunk. Still no auto-decay — the
/// rating is unchanged; what changed is that the conditions it describes no longer hold.
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

    /// The floor a **stale** reading's term cannot fall below (ADR 0169) — exactly `masteryTerm(4)`,
    /// so it is a value already in the formula rather than a new constant: *a rating whose conditions
    /// have moved is worth no more to the planner than a 4 is.* It bites only at `5`, the one rating
    /// whose term is `0` and which therefore zeroes the whole product.
    ///
    /// Written as the term's own expression rather than the arithmetically equal `1.0 / 5.0`, so it
    /// is **bit-identical** to `masteryTerm(4)`. The two forms differ in the last place of a `Double`,
    /// which is enough to make a stale 5 rank a hair *above* a fresh 4 — an inversion of the axis,
    /// found by the test that asserts it cannot happen.
    static let staleMasteryFloor = 1.0 - 4.0 / 5.0

    /// The **mastery term** — falls as the player rates the item more settled (ADR 0015 S5).
    /// Unrated (`nil`) is treated as max-due (`1.0`, as if mastery 0): a drill you've never
    /// judged is assumed to still need work. `mastery 5` yields `0` — fully owned, retired from
    /// rotation until re-rated. Clamped to `0…5` defensively.
    ///
    /// **A stale reading never retires a drill (ADR 0169).** `isStale` means the command tempo (or
    /// rhythm) has moved off the one the rating was given at, so the rating is a true statement about
    /// conditions that no longer hold. The bug it fixes is a sequence, not a state: rate 5 → the offer
    /// leans `.raise` → `commitDone` writes the 5 *and* promotes → the term is `0` and the drill is
    /// retired, at a tempo it has never been rated at and by definition has not yet been played
    /// cleanly. Flooring at `staleMasteryFloor` makes an accepted raise leave the drill **competing
    /// for a slot** instead. (Note "retired" is loose: `SessionBuilder.ranked` filters on `priority`,
    /// not score, so a 0 sorts *last* rather than being excluded — total in a well-stocked library,
    /// partial in a small one. What is exact is that the score is a **product**, so a 5 is immune to
    /// dueness however long it sits.) The rating itself is untouched — ADR 0070 stands: the app marks that conditions
    /// changed, it never rewrites a number the player set.
    static func masteryTerm(_ mastery: Int?, isStale: Bool = false) -> Double {
        guard let mastery else { return 1.0 }
        let clamped = min(5, max(0, mastery))
        let term = 1.0 - Double(clamped) / 5.0
        return isStale ? max(term, staleMasteryFloor) : term
    }

    /// The full dueScore for a candidate at `now` (ADR 0015 S5). Higher ⇒ wants scheduling more.
    /// A non-positive `priority` (no active goal — ADR 0015 S4) yields `0`; the caller excludes
    /// those before selection.
    static func score(_ candidate: PlannerCandidate, now: Date) -> Double {
        candidate.priority
            * dueness(lastPracticed: candidate.lastPracticed, now: now)
            * masteryTerm(candidate.mastery, isStale: candidate.masteryIsStale)
    }
}
