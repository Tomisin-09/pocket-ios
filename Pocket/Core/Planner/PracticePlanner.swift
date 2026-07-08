import Foundation
import SwiftData

/// The **impure seam** of the V2 planner (Slice 1): projects live `@Model`s into the pure
/// candidate value types, runs the pure back-half (`SessionBuilder`), and materialises the
/// resulting `[SessionBlock]` into a persisted `Routine` handed to the shipped player (ADR 0066).
/// All the *decisions* live in the pure layer (`DueScore` / `SessionBuilder`); this only shuttles
/// data across the SwiftData boundary, so it stays thin and needs no unit tests of its own.
///
/// `@MainActor` because it reads and writes `@Model` state through the main-actor `ModelContext`
/// (CI is Swift 6 / Xcode 16 — main-actor isolation is enforced; mark it up front, per the repo's
/// CI-strictness note).
@MainActor
enum PracticePlanner {

    /// Generate a **Quick session** from the user's exercise library (Slice 1 milestone): no goals
    /// yet, so every focused candidate carries `priority = 1` and ranks by dueness alone; warm-up is
    /// LRU-picked from `template == .warmup` exercises. Returns the pure block layout; pass it to
    /// `materialise` to persist and run.
    static func planQuickSession(minutes: Int,
                                 exercises: [Exercise],
                                 now: Date = .now) -> [SessionBlock] {
        let focused = exercises
            .filter { $0.template != .warmup }
            .map { candidate(for: $0) }
        let warmUps = exercises
            .filter { $0.template == .warmup }
            .map { candidate(for: $0) }
        let warmUp = SessionBuilder.warmUpPick(warmUps)
        return SessionBuilder.buildSession(minutes: minutes, candidates: focused,
                                           warmUp: warmUp, now: now)
    }

    /// Project one exercise into a pure candidate (Slice 1: `priority = 1`, no `skillID`). The
    /// estimated minutes are a simple per-exercise default here; Slice 2 derives them from the ramp
    /// staircase.
    static func candidate(for exercise: Exercise) -> PlannerCandidate {
        PlannerCandidate(unit: PlannerUnitRef(exercise.uid, .exercise),
                         priority: 1.0,
                         mastery: exercise.mastery,
                         lastPracticed: exercise.lastPracticed,
                         estimatedMinutes: estimatedMinutes(for: exercise))
    }

    /// A rough per-exercise time estimate (Slice 1) — one default focused block. Slice 2 replaces
    /// this with the ramp staircase / loop length×reps / song duration (plan §5.2 item 4).
    static func estimatedMinutes(for exercise: Exercise) -> Int {
        RoutineBudget.defaultFocusedMinutes
    }

    /// Materialise a planned `[SessionBlock]` into a persisted `Routine` of ordered `RoutineItem`s
    /// (ADR 0066): the pure blocks become real blocks with explicit `order` (R2 — relationship
    /// arrays aren't dependably ordered) and the matching `RoutineItemKind`. A unit ref that no
    /// longer resolves is **skipped**, not a crash (R5). Slice 1 resolves only exercises; loop/song
    /// refs (Slice 2, Path B) are skipped until then. Inserts into `context`; the caller saves.
    ///
    /// `nonisolated` — it only touches the passed `context` and the value `blocks`, so it can be
    /// called from a view initialiser (which builds the routine in a private sandbox context) as
    /// well as from the main actor.
    @discardableResult
    nonisolated static func materialise(_ blocks: [SessionBlock],
                                        name: String,
                                        exercises: [Exercise],
                                        into context: ModelContext,
                                        now: Date = .now) -> Routine {
        let exercisesByUID = Dictionary(exercises.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let routine = Routine(name: name, dateAdded: now)
        context.insert(routine)

        var order = 0
        for block in blocks {
            let item: RoutineItem
            switch block.unit {
            case let ref? where ref.kind == .exercise:
                guard let exercise = exercisesByUID[ref.uid] else { continue }  // orphan → skip (R5)
                item = RoutineItem.item(exercise, kind: block.kind, order: order)
            case .some:
                continue  // loop / song refs not resolvable in Slice 1
            case .none:
                item = RoutineItem.rest(order: order)
            }
            item.routine = routine
            context.insert(item)
            order += 1
        }
        return routine
    }
}
