import Foundation
import SwiftData

/// A **long-term goal** (ADR 0171): a standing outcome the player is working toward — "play *Wish
/// You Were Here* end to end", "build speed" — as opposed to a `Goal`, which is what they want out
/// of *this* session. The two tiers split by **scope of intent, not duration**, and they differ in
/// how they order: a `Goal` is **weighted** (`GoalPriority`), a `LongTermGoal` is **ranked**
/// (`order`, projected through `LongTermRank`).
///
/// **There is no date field of any kind, and that is the decision** (ADR 0171 D1). Not "no deadline
/// by default" — no column. With nothing stored there is nothing for the app to be late against, so
/// the no-verdict property of ADR 0070 is *structural* rather than a promise kept by copy. Nothing
/// in the deriver ever wanted a date either, so open-ended costs the planner exactly nothing.
///
/// **A separate `@Model` rather than a tier flag on `Goal`** (ADR 0171 D2): a discriminator would
/// make every existing read site responsible for filtering, and one that forgot would leak a
/// long-term goal into the Today's-session list — the "second read path" failure this repo has
/// already been bitten by twice (ADR 0120, ADR 0111). A separate entity makes that leak impossible
/// to write, and is additive, which the schema freeze permits.
///
/// Follows the model discipline (ADR 0011/0012/0036): a `uid: UUID` business id; **declaration
/// defaults** on every non-optional attribute so SwiftData lightweight migration stays additive;
/// skills as a scalar `[String]` indexing `TechniqueTaxonomy` — **never a stored enum**.
@Model
final class LongTermGoal {
    /// Stable business id — list diffing, and the key `SessionBuilder.roundRobin` deals on.
    var uid: UUID

    /// The goal's title (seeded from a shared `GoalTemplate`, then editable).
    var title: String = ""

    /// The `SkillID`s this goal targets — a scalar `[String]` indexing `TechniqueTaxonomy` (never a
    /// stored enum). At least one is what makes the goal derivable at all.
    var skillIDs: [String] = []

    /// Zero-based rank. **The only ordering this tier has**, and it is load-bearing twice over
    /// (ADR 0171 D3): it sets the projected `weight`, and it sets `roundRobin`'s visit order, so
    /// ranks past the session's item count still change what gets dealt. Contiguous by construction
    /// — `LongTermGoalStore.move` renumbers, the way `ReferenceLink` does.
    var order: Int = 0

    /// The optional repertoire target (Path B): the song a "learn / master a song" goal points at.
    /// Typed optional relationship with a **nullify** delete rule — deleting the song clears the
    /// link and the goal survives, its Path-B candidates simply stop resolving.
    @Relationship(deleteRule: .nullify) var targetSong: Song?

    /// Whether the player has marked this goal **met** (ADR 0015 S6, same semantics as `Goal`) — a
    /// met goal contributes no candidates without being deleted, and still shows in the list and
    /// the Progress echo.
    var isMet: Bool = false

    /// When the goal was created. A record, **not a horizon** — nothing reads it to compute
    /// lateness, elapsed time, or a "since" figure, and nothing may start.
    var dateAdded: Date = Date.now

    init(title: String = "",
         skillIDs: [String] = [],
         order: Int = 0,
         targetSong: Song? = nil,
         isMet: Bool = false,
         dateAdded: Date = .now) {
        self.uid = UUID()
        self.title = title
        self.skillIDs = skillIDs
        self.order = order
        self.targetSong = targetSong
        self.isMet = isMet
        self.dateAdded = dateAdded
    }

    /// The pure projection the deriver reads. Identical in shape to `Goal.plannerProjection` — which
    /// is the point: both tiers land in one `[PlannerGoal]` pool and compete on the same terms. The
    /// weight comes from `order` rather than being stored, so reordering the list is the *only* way
    /// to change how hard a long-term goal pulls.
    var plannerProjection: PlannerGoal {
        PlannerGoal(uid: uid,
                    weight: LongTermRank.weight(forOrder: order),
                    skillIDs: skillIDs,
                    targetSongUID: targetSong.map { PlannerID.uid(from: $0.sourceID) },
                    isMet: isMet)
    }
}

/// Ordering + reorder mechanics for the ranked list. Mirrors `ReferenceLinkStore.move` (ADR 0167)
/// with a contiguous renumber, for the same reason: `order` must stay gap-free or the rank → weight
/// mapping starts skipping steps.
enum LongTermGoalStore {

    /// Every goal in rank order — ties (only reachable from hand-authored data) break by `dateAdded`
    /// then `uid`, so the list is a total order and `.onMove` can't flicker.
    static func inRankOrder(_ goals: [LongTermGoal]) -> [LongTermGoal] {
        goals.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            if lhs.dateAdded != rhs.dateAdded { return lhs.dateAdded < rhs.dateAdded }
            return lhs.uid.uuidString < rhs.uid.uuidString
        }
    }

    /// Apply a list-edit move and renumber contiguously.
    static func move(from offsets: IndexSet, to destination: Int, in goals: [LongTermGoal]) {
        var ordered = inRankOrder(goals)
        ordered.move(fromOffsets: offsets, toOffset: destination)
        renumber(ordered)
    }

    /// Close the gaps after a delete (or any other mutation) so `order` stays contiguous from zero.
    static func renumber(_ ordered: [LongTermGoal]) {
        for (index, goal) in ordered.enumerated() where goal.order != index { goal.order = index }
    }

    /// The rank order the planner deals in — `roundRobin`'s `ranking` argument (ADR 0171 D3).
    /// **Met goals are omitted**: they derive nothing, so naming them would only pad the visit list.
    static func ranking(_ goals: [LongTermGoal]) -> [UUID] {
        inRankOrder(goals).filter { !$0.isMet }.map(\.uid)
    }
}
