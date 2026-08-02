import Foundation

/// Which kind of practice **unit** a planner candidate points at (V2 planner, ADR 0015).
/// A pure, SwiftData-free tag so the planner's value projections can name a unit without
/// holding the `@Model` — the materialiser resolves it back to the live object by `uid`.
enum PlannerUnitKind: String, Equatable, Hashable, Codable {
    case exercise
    case loop
    case song
}

/// A stable reference to one practice unit — its business `uid` plus which kind it is
/// (`Exercise` / `Loop` / `Song`). The pure planner reasons over these; the impure
/// materialiser maps `uid → @Model` to rebuild `RoutineItem`s. Mirrors the "typed unit,
/// resolved by id" shape the routine model already uses (ADR 0066 R4).
struct PlannerUnitRef: Equatable, Hashable, Codable {
    var uid: UUID
    var kind: PlannerUnitKind

    init(_ uid: UUID, _ kind: PlannerUnitKind) {
        self.uid = uid
        self.kind = kind
    }
}

/// A single thing the planner *could* schedule — a **value projection** of an `Exercise`,
/// `Loop`, or `Song` (V2 planner, ADR 0015 S3). Deliberately **SwiftData-/SwiftUI-free**
/// (Foundation only) so the selection math (`DueScore`, `SessionBuilder`) stays unit-testable
/// and reusable by a future AI producer (ADR 0002) — the "pure logic stays pure" rule
/// (AGENTS.md). Never the `@Model` itself: the impure projection step builds these, and the
/// materialiser resolves `unit.uid` back to the live object.
struct PlannerCandidate: Equatable {
    /// Which unit this candidate schedules — resolved back to a model by the materialiser.
    var unit: PlannerUnitRef

    /// The goal-derived weight (ADR 0015 S5 `goalWeight`). Slice 1 has no goals, so every
    /// candidate carries `1.0`; Slice 2's `deriveCandidates` sets it from the active goals.
    var priority: Double

    /// The unit's self-rated mastery (0–5, `nil` = unrated) — the dueScore *need* term
    /// (ADR 0070: self-set, never measured). `nil` ⇒ treated as max-due (cold-start friendly).
    var mastery: Int?

    /// When the unit was last practised (`nil` = never) — drives dueness (rises with time) on
    /// the focused axis and LRU rotation on the warm-up axis. Same field, two rules.
    var lastPracticed: Date?

    /// Rough minutes this unit wants — from the exercise ramp staircase / loop length×reps /
    /// song duration (Slice 2). Used by `buildSession` to time-box against the budget.
    var estimatedMinutes: Int

    /// The skill this candidate satisfies, for display only (`nil` in Slice 1 before goals).
    var skillID: String?

    /// **How this unit should be run**, when the unit is a loop (ADR 0135 B6a / 0139 O2a). A loop can
    /// serve a skill as the trainer's staircase, as ear work, or as a bed to solo over, and *which*
    /// is decided here — at resolution, by the skill that claimed it — because that is the only place
    /// the reason is still known. It then rides the block down to `RoutineItem.loopRunMode`.
    ///
    /// `.trainer` on every non-loop candidate and on loops surfaced the ordinary way, so nothing that
    /// predates this changes. Deliberately **not** part of `PlannerUnitRef`: the ref is the
    /// deduplication key, and a mode-bearing key would let one loop appear twice in a session — once
    /// to train, once to sing back (ADR 0139 O2b).
    var runMode: LoopRunMode

    /// Which **goal** surfaced this candidate — the strongest claim's goal, where several compete
    /// (`CandidateDeriver`). `nil` on the goal-less Quick path, where every candidate is equal.
    ///
    /// `SessionBuilder.select` deals across goals rather than taking the top-ranked N, so this is
    /// what keeps a session from being drawn entirely from one goal. It was invisible before ADR 0129:
    /// at ~15 items both goals were represented by brute force; at **three** the top goal took every
    /// slot.
    var goalUID: UUID?

    init(unit: PlannerUnitRef,
         priority: Double = 1.0,
         mastery: Int? = nil,
         lastPracticed: Date? = nil,
         estimatedMinutes: Int,
         skillID: String? = nil,
         runMode: LoopRunMode = .trainer,
         goalUID: UUID? = nil) {
        self.unit = unit
        self.priority = priority
        self.mastery = mastery
        self.lastPracticed = lastPracticed
        self.estimatedMinutes = estimatedMinutes
        self.skillID = skillID
        self.runMode = runMode
        self.goalUID = goalUID
    }
}
