import Foundation
import SwiftData

/// One playable block resolved for the player (ADR 0066, slice 3) — its display title plus the live
/// unit to run. The associated-value payload keeps the "exactly one unit" invariant honest without
/// optionals the player would have to force-unwrap.
struct RoutineStage: Identifiable {
    let id: UUID
    let title: String
    let payload: Payload

    enum Payload { case exercise(Exercise), loop(Loop), rest }

    var kind: RoutineStageKind {
        switch payload {
        case .exercise: return .exercise
        case .loop: return .loop
        case .rest: return .rest
        }
    }
    var exercise: Exercise? { if case .exercise(let value) = payload { return value }; return nil }
    var loop: Loop? { if case .loop(let value) = payload { return value }; return nil }
}

/// The **session conductor** for a routine run (ADR 0066, slice 3 / ADR 0071): a thin transport that
/// walks the routine's playable blocks in order and **auto-advances** between them. Deliberately it
/// owns **no playback engine** — each exercise/loop block is run by the *real* `ExerciseRunView` /
/// `LoopRunView`, so the session keeps every training aid (previews, staircase, promote, journal)
/// rather than a stripped-down surface. A run screen signals its natural completion back through
/// `RoutineRunContext.onFinished`, which lands here as `advance()`. The conductor's only own playback
/// concern is the between-blocks **rest** countdown; a rest carries no unit, so there is no run
/// screen to delegate to.
///
/// **No evaluation surface (ADR 0070).** Completion is the material's own length (a full ramp pass,
/// or the rest countdown), never "play it right to advance."
///
/// Song blocks are reserved for the audio-only play-along (a following slice) and are filtered out
/// until then, alongside orphaned blocks (ADR 0066 R5).
@MainActor
@Observable
final class RoutineSessionPlayer {

    /// Where the session is. A unit block is `running` (a run screen is on-stage); a rest is its own
    /// `resting` countdown phase; `finished` shows the summary.
    enum State: Equatable { case running, resting, finished }

    let routineName: String
    private(set) var stages: [RoutineStage]
    private(set) var cursor: RoutineSessionCursor
    private(set) var state: State = .running

    /// The fixed session breather between blocks, seconds — a short runtime pause, deliberately
    /// *not* the ADR 0014 planning-time rest minutes (a planner concern; at runtime each block runs
    /// its natural length, so the routine needs no per-block clock).
    static let restSeconds = 20
    private(set) var restRemaining = 0
    private var restTimer: Timer?
    /// Guards `start()` against a re-fired `onAppear`, so a rest countdown is never double-started.
    private var started = false

    /// The block the player is on, or `nil` once the session is complete.
    var current: RoutineStage? { cursor.isComplete ? nil : stages[cursor.index] }
    var currentIndex: Int { cursor.index }
    var stageCount: Int { stages.count }
    var progressLabel: String { cursor.progressLabel }
    var isFinished: Bool { state == .finished }

    /// Index of the first *unit* block (exercise/loop) — the one that always waits for a deliberate
    /// Start; `nil` if the routine has no unit blocks. Rests never auto-run a unit, so they don't
    /// count as "the first block" for auto-start.
    private let firstUnitIndex: Int?

    /// Whether the block at `index` should begin on its own — the auto-start setting is on *and* it's
    /// not the first unit block. The player asks this when building each block's context.
    func shouldAutoStart(at index: Int) -> Bool {
        AppSettings.routineAutoStart && index != firstUnitIndex
    }

    init(routine: Routine) {
        routineName = routine.name.isEmpty ? "Routine" : routine.name
        // Play order, minus blocks the player can't run: orphaned units (deleted → nullified, R5)
        // and song blocks (their audio-only play-along is a following slice).
        let playable = routine.orderedItems.filter { !$0.isOrphaned && $0.song == nil }
        let mapped = playable.map(Self.stage(for:))
        stages = mapped
        cursor = RoutineSessionCursor(total: mapped.count)
        firstUnitIndex = mapped.firstIndex { $0.kind != .rest }
    }

    private static func stage(for item: RoutineItem) -> RoutineStage {
        if let exercise = item.exercise {
            let title = exercise.name.isEmpty ? "Exercise" : exercise.name
            return RoutineStage(id: item.uid, title: title, payload: .exercise(exercise))
        }
        if let loop = item.loop {
            return RoutineStage(id: item.uid, title: loop.name.isEmpty ? "Loop" : loop.name,
                                payload: .loop(loop))
        }
        return RoutineStage(id: item.uid, title: "Rest", payload: .rest)
    }

    // MARK: - Lifecycle

    /// Begin the session on the first block. Called from the player's `onAppear`; guarded so a
    /// re-fired appear can't restart it.
    func start() {
        guard !started else { return }
        started = true
        beginCurrentStage()
    }

    /// Tear down and end — the player's `onDisappear` and the exit control. Idempotent.
    func end() {
        stopRestTimer()
        state = .finished
    }

    /// Advance to the next block — the shared path for a natural completion *and* a user Skip.
    func advance() {
        stopRestTimer()
        cursor.advance()
        beginCurrentStage()
    }

    private func beginCurrentStage() {
        guard let stage = current else { state = .finished; return }
        if stage.kind == .rest { beginRest() } else { state = .running }
    }

    // MARK: - Rest (the only phase the conductor plays itself)

    private func beginRest() {
        state = .resting
        restRemaining = Self.restSeconds
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickRest() }
        }
    }

    private func tickRest() {
        restRemaining -= 1
        if restRemaining <= 0 { advance() }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
}
