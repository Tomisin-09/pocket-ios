import Foundation
import SwiftData

/// A **practice goal** (V2 planner Slice 2, ADR 0015): "Build speed", "Learn *Wish You Were Here*"
/// — what the player wants to get better at, which the planner's front-half (`CandidateDeriver`)
/// expands into a ranked pool of things to practise. A goal is authored from an in-house
/// `GoalTemplate` (Decision 7) that pre-seeds a sensible `skillIDs` set the user trims; there is no
/// free-text / AI decomposition in V2.
///
/// Follows the model discipline (ADR 0011/0012/0036): a `uid: UUID` business id; **declaration
/// defaults** on every non-optional attribute so SwiftData lightweight migration stays additive
/// (the CoreData 134110 mandatory-attribute rule); skills stored as a scalar `[String]` of
/// `SkillID`s that *index* the taxonomy — **never a stored enum** (the enum-attribute migration
/// rule). `targetSong` is a typed optional relationship (ADR 0058/0066 R4), not a generic owner id.
@Model
final class Goal {
    /// Stable business id — list diffing / selection, like `Exercise`/`Loop`.
    var uid: UUID

    /// The goal's title (from its template, editable). Empty until named.
    var title: String = ""

    /// The goal-selection **weight** (ADR 0015 S5) — how hard this goal pulls its skills' candidates
    /// up the ranking. `1.0` is neutral; a higher weight yields higher-priority candidates.
    var weight: Double = 1.0

    /// The `SkillID`s this goal targets — a scalar `[String]` indexing `TechniqueTaxonomy` (never a
    /// stored enum). Declaration default keeps migration additive. Path A resolves technique skills
    /// to exercises; a repertoire skill routes to `targetSong` (Path B).
    var skillIDs: [String] = []

    /// The optional repertoire target (Path B): the song a "learn / master a song" goal points at.
    /// Typed optional relationship with a **nullify** delete rule — deleting the song clears the
    /// link (the goal survives, its Path-B candidates simply stop resolving), it does not delete the
    /// goal. `nil` for pure technique goals.
    @Relationship(deleteRule: .nullify) var targetSong: Song?

    /// Whether the player has marked this goal **met** (ADR 0015 S6) — a met goal contributes no
    /// candidates on the next derivation, without being deleted (the history is kept).
    var isMet: Bool = false

    /// When the goal was created — the default sort key.
    var dateAdded: Date = Date.now

    init(title: String = "",
         weight: Double = 1.0,
         skillIDs: [String] = [],
         targetSong: Song? = nil,
         isMet: Bool = false,
         dateAdded: Date = .now) {
        self.uid = UUID()
        self.title = title
        self.weight = weight
        self.skillIDs = skillIDs
        self.targetSong = targetSong
        self.isMet = isMet
        self.dateAdded = dateAdded
    }

    /// The pure projection the deriver reads (`PlannerGoal`) — resolves the target song to its
    /// deterministic planner id so the pure layer never holds the `@Model`.
    var plannerProjection: PlannerGoal {
        PlannerGoal(uid: uid,
                    weight: weight,
                    skillIDs: skillIDs,
                    targetSongUID: targetSong.map { PlannerID.uid(from: $0.sourceID) },
                    isMet: isMet)
    }
}
