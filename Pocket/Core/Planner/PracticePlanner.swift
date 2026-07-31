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
    static func planQuickSession(length: SessionLength,
                                 exercises: [Exercise],
                                 now: Date = .now) -> [SessionBlock] {
        let focused = exercises
            .filter { $0.template != .warmup }
            .map { candidate(for: $0) }
        let warmUps = exercises
            .filter { $0.template == .warmup }
            .map { candidate(for: $0) }
        let warmUp = SessionBuilder.warmUpPick(warmUps)
        return SessionBuilder.buildSession(length: length, candidates: focused,
                                           warmUp: warmUp, now: now)
    }

    /// Generate a **goal-driven session** (Slice 2 milestone): the front-half (`CandidateDeriver`)
    /// expands the active goals into a ranked candidate pool over the projected library, then the
    /// back-half (`SessionBuilder`) lays it out — warm-up still LRU-picked from `template == .warmup`
    /// exercises (structural, never due-scored). The optional `profile` supplies the ADR 0113 S3
    /// **emphasis mix** (declared genres + dream), a lift-only tilt on candidate priority; omit it (or
    /// pass a curation-free profile) for the pre-S3 due/goal-only ranking. Returns the pure block
    /// layout; pass it to `materialise` with the same model arrays to persist and run.
    static func planGoalSession(length: SessionLength,
                                goals: [Goal],
                                exercises: [Exercise],
                                loops: [Loop] = [],
                                songs: [Song] = [],
                                profile: Profile? = nil,
                                now: Date = .now) -> [SessionBlock] {
        let library = library(exercises: exercises, loops: loops, songs: songs)
        let emphasis = profile.map { PracticeEmphasis(genres: $0.genres, dream: $0.dream) } ?? .neutral
        let candidates = CandidateDeriver.deriveCandidates(goals: goals.map(\.plannerProjection),
                                                           library: library, emphasis: emphasis)
        let warmUps = exercises.filter { $0.template == .warmup }.map { candidate(for: $0) }
        let warmUp = SessionBuilder.warmUpPick(warmUps)
        return SessionBuilder.buildSession(length: length, candidates: candidates,
                                           warmUp: warmUp, now: now)
    }

    /// Project the live library into the pure value types the deriver reasons over — the impure
    /// seam that owns the time estimates (they need audio durations). Warm-up exercises are excluded
    /// from the focused-selection projection (they're placed structurally, not ranked).
    static func library(exercises: [Exercise], loops: [Loop] = [], songs: [Song] = []) -> PlannerLibrary {
        PlannerLibrary(
            exercises: exercises
                .filter { $0.template != .warmup }
                .map { PlannerExercise(uid: $0.uid, template: $0.template, mastery: $0.mastery,
                                       lastPracticed: $0.lastPracticed,
                                       estimatedMinutes: estimatedMinutes(for: $0)) },
            loops: loops.map { PlannerLoop(uid: $0.uid, songUID: $0.song.map { PlannerID.uid(from: $0.sourceID) },
                                           mastery: $0.mastery, lastPracticed: nil,
                                           estimatedMinutes: estimatedMinutes(for: $0),
                                           templates: recognizedTemplates(for: $0)) },
            songs: songs.map { PlannerSong(uid: PlannerID.uid(from: $0.sourceID),
                                           lastPracticed: $0.lastPracticed,
                                           estimatedMinutes: estimatedMinutes(for: $0)) })
    }

    /// Project one exercise into a pure candidate (used for warm-up picking and the goal-less Quick
    /// session — `priority = 1`, no `skillID`; goal sessions get their priority from the deriver).
    static func candidate(for exercise: Exercise) -> PlannerCandidate {
        PlannerCandidate(unit: PlannerUnitRef(exercise.uid, .exercise),
                         priority: 1.0,
                         mastery: exercise.mastery,
                         lastPracticed: exercise.lastPracticed,
                         estimatedMinutes: estimatedMinutes(for: exercise))
    }

    /// A per-exercise time estimate from its **ramp staircase** (R3): how long the warm-up→dwell→
    /// summit→backoff plateaus actually take at their own tempos and meter, not a flat default. The
    /// back-half still splits any over-long block against the focused cap (R2).
    static func estimatedMinutes(for exercise: Exercise) -> Int {
        SessionEstimate.minutes(forRamp: exercise.ramp, beatsPerBar: exercise.beatsPerBar)
    }

    /// The distinct skill buckets recognised from a loop's tags (Slice 4, Decision 8), order-stable —
    /// the Path-A match key. Empty for an untagged loop (Path-B only). Dedupes while preserving the
    /// tag order the recogniser first sees each bucket.
    static func recognizedTemplates(for loop: Loop) -> [ExerciseTemplate] {
        var seen: Set<ExerciseTemplate> = []
        var result: [ExerciseTemplate] = []
        for tag in loop.tags {
            guard let template = SkillFamilyMap.recognizedTemplate(for: tag), seen.insert(template).inserted
            else { continue }
            result.append(template)
        }
        return result
    }

    /// A loop's rough minutes — its region length × its repeat count (Path B), floored at 1.
    static func estimatedMinutes(for loop: Loop) -> Int {
        let seconds = max(0, loop.endSeconds - loop.startSeconds) * Double(max(1, loop.repeats))
        return max(1, Int((seconds / 60).rounded()))
    }

    /// A song run's rough minutes — its full duration (Path B), floored at 1.
    static func estimatedMinutes(for song: Song) -> Int {
        max(1, Int((song.duration / 60).rounded()))
    }

    /// Total estimated minutes for a whole **routine** (R3) — the sum over its runnable, unit-bearing
    /// blocks of the per-unit estimate × the block's `reps`. Orphaned blocks (deleted unit) and rests
    /// (breaks, not budgeted work — ADR 0014 R1) contribute nothing. Drives the planner review
    /// screen's soft length readout.
    static func estimatedMinutes(forRoutine routine: Routine) -> Int {
        routine.orderedItems.reduce(0) { total, item in
            guard !item.isOrphaned else { return total }
            let perRun: Int
            if let exercise = item.exercise {
                perRun = estimatedMinutes(for: exercise)
            } else if let loop = item.loop {
                perRun = estimatedMinutes(for: loop)
            } else if let song = item.song {
                perRun = estimatedMinutes(for: song)
            } else {
                return total // a rest carries no unit
            }
            return total + SessionEstimate.minutes(perRun: perRun, reps: item.effectiveReps)
        }
    }

    /// Materialise a planned `[SessionBlock]` into a persisted `Routine` of ordered `RoutineItem`s
    /// (ADR 0066): the pure blocks become real blocks with explicit `order` (R2 — relationship
    /// arrays aren't dependably ordered) and the matching `RoutineItemKind`. A unit ref that no
    /// longer resolves is **skipped**, not a crash (R5). Resolves exercises by `uid`, loops by
    /// `uid`, and songs by their deterministic `PlannerID.uid(from: sourceID)` (Song has no stored
    /// `uid`). Pass the same model arrays the blocks were planned from. Inserts into `context`; the
    /// caller saves.
    ///
    /// `nonisolated` — it only touches the passed `context` and the value `blocks`, so it can be
    /// called from a view initialiser (which builds the routine in a private sandbox context) as
    /// well as from the main actor.
    @discardableResult
    nonisolated static func materialise(_ blocks: [SessionBlock],
                                        name: String,
                                        exercises: [Exercise],
                                        loops: [Loop] = [],
                                        songs: [Song] = [],
                                        into context: ModelContext,
                                        now: Date = .now) -> Routine {
        let exercisesByUID = Dictionary(exercises.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let loopsByUID = Dictionary(loops.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let songsByUID = Dictionary(songs.map { (PlannerID.uid(from: $0.sourceID), $0) },
                                    uniquingKeysWith: { first, _ in first })
        let routine = Routine(name: name, dateAdded: now)
        context.insert(routine)

        var order = 0
        for block in blocks {
            guard let item = item(for: block, order: order,
                                  exercises: exercisesByUID, loops: loopsByUID, songs: songsByUID)
            else { continue }  // orphaned unit ref → skip (R5)
            item.routine = routine
            context.insert(item)
            order += 1
        }
        return routine
    }

    /// Build one `RoutineItem` from a block, resolving its unit ref by kind — or `nil` when the ref
    /// no longer resolves (skipped by the caller, R5). A rest carries no unit.
    nonisolated private static func item(for block: SessionBlock,
                                         order: Int,
                                         exercises: [UUID: Exercise],
                                         loops: [UUID: Loop],
                                         songs: [UUID: Song]) -> RoutineItem? {
        switch block.unit {
        case .none:
            return RoutineItem.rest(order: order)
        case let ref? where ref.kind == .exercise:
            return exercises[ref.uid].map { RoutineItem.item($0, kind: block.kind, order: order) }
        case let ref? where ref.kind == .loop:
            return loops[ref.uid].map { RoutineItem.item($0, kind: block.kind, order: order) }
        case let ref?:
            return songs[ref.uid].map { RoutineItem.item($0, kind: block.kind, order: order) }
        }
    }
}
