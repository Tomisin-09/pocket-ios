import Foundation
import SwiftData

/// One playable block resolved for the player (ADR 0066, slice 3) — its display title plus the live
/// unit to run. The associated-value payload keeps the "exactly one unit" invariant honest without
/// optionals the player would have to force-unwrap.
struct RoutineStage: Identifiable {
    let id: UUID
    let title: String
    /// How many times this block runs back-to-back before the session advances (ADR 0076) — the
    /// block's `RoutineItem.effectiveReps`. `1` for a single run and always for a rest.
    let reps: Int
    /// Minutes a generated session allotted this block (ADR 0129), or `nil` when it was hand-authored.
    /// Handed to the run screen so it can fit its ramp to the slot.
    let plannedMinutes: Int?
    let payload: Payload

    enum Payload { case exercise(Exercise), loop(Loop), earLoop(Loop), song(Song), rest }

    var kind: RoutineStageKind {
        switch payload {
        case .exercise: return .exercise
        case .loop: return .loop
        case .earLoop: return .earLoop
        case .song: return .song
        case .rest: return .rest
        }
    }
    var exercise: Exercise? { if case .exercise(let value) = payload { return value }; return nil }
    /// The loop unit for **either** loop mode — standard trainer (`.loop`) or ear (`.earLoop`).
    var loop: Loop? {
        switch payload {
        case .loop(let value), .earLoop(let value): return value
        default: return nil
        }
    }
    var song: Song? { if case .song(let value) = payload { return value }; return nil }
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
/// Song blocks run the audio-only `SongPlayAlongView` (ADR 0071). Only orphaned blocks (ADR 0066 R5)
/// and Apple-Music-backed songs (browse/metadata only, not playable — ADR 0001) are filtered out.
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

    /// The between-blocks breather, seconds — user-set (`AppSettings.routineRestSeconds`), a short
    /// runtime pause deliberately *not* the ADR 0014 planning-time rest minutes (a planner concern;
    /// at runtime each block runs its natural length, so the routine needs no per-block clock).
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

    /// 1-based run within the current block, and whether another rep remains (ADR 0076). The player
    /// view keys each run screen on `currentRep` so a fresh rep restarts the drill, and shows
    /// `repLabel` while a multi-rep block is in play.
    var currentRep: Int { cursor.rep }
    var hasMoreReps: Bool { cursor.hasMoreReps }
    var repLabel: String { cursor.repLabel }

    /// The block after the current one — drives the rest screen's "up next" preview; `nil` if the
    /// current block is the last.
    var upNext: RoutineStage? {
        let next = cursor.index + 1
        return next < stages.count ? stages[next] : nil
    }

    /// Whether there's a previous block to step back to.
    var canGoBack: Bool { cursor.index > 0 && !isFinished }

    /// Whether the block at `index` should begin on its own when it appears — purely the auto-start
    /// setting (ADR 0071 R4b). The first block used to always wait for a deliberate Start; that gate
    /// is dropped now that every block is previewable up front from the routine detail, so tapping
    /// **Start** runs straight into block one (with auto-start off, every block still waits).
    func shouldAutoStart(at index: Int) -> Bool {
        AppSettings.routineAutoStart
    }

    /// The next **unit** block (exercise/loop/song) after `index`, skipping rests — drives the Done
    /// screen's "Up next" (ADR 0071 R4b). `nil` when only rests (or nothing) remain. Pure, so the
    /// skip-rest selection is unit-testable.
    func nextUnitStage(after index: Int) -> RoutineStage? {
        guard index + 1 < stages.count else { return nil }
        return stages[(index + 1)...].first { $0.kind != .rest }
    }

    init(routine: Routine) {
        routineName = routine.name.isEmpty ? "Routine" : routine.name
        // Play order, minus blocks the player can't run: orphaned units (deleted → nullified, R5)
        // and Apple-Music songs (not a playable audio source, ADR 0001).
        let playable = routine.orderedItems.filter { !$0.isOrphaned && Self.isPlayable($0) }
        let mapped = playable.map(Self.stage(for:))
        stages = mapped
        cursor = RoutineSessionCursor(reps: mapped.map(\.reps))
    }

    /// Whether the player can actually run this block's unit. Exercises and loops always can; a song
    /// block is playable only when its audio is a local/iCloud file (Apple Music is browse-only, so
    /// its blocks are dropped rather than shown as silent dead ends).
    private static func isPlayable(_ item: RoutineItem) -> Bool {
        guard let song = item.song else { return true }
        return song.ref.source != .appleMusic
    }

    private static func stage(for item: RoutineItem) -> RoutineStage {
        let reps = item.effectiveReps
        // The allotment, unless this block declined the fit (ADR 0130) — then the run plays the
        // exercise's or loop's own recipe, exactly as a hand-authored block does.
        let planned = item.effectivePlannedMinutes
        if let exercise = item.exercise {
            let title = exercise.name.isEmpty ? "Exercise" : exercise.name
            return RoutineStage(id: item.uid, title: title, reps: reps,
                                plannedMinutes: planned, payload: .exercise(exercise))
        }
        if let loop = item.loop {
            let title = loop.name.isEmpty ? "Loop" : loop.name
            // A loop block carries a mode (ADR 0104 Slice 2): ear training embeds the ears-only
            // surface, everything else the standard command-anchored trainer.
            let payload: RoutineStage.Payload =
                item.loopRunMode == .ear ? .earLoop(loop) : .loop(loop)
            return RoutineStage(id: item.uid, title: title, reps: reps,
                                plannedMinutes: planned, payload: payload)
        }
        if let song = item.song {
            return RoutineStage(id: item.uid, title: song.title.isEmpty ? "Song" : song.title,
                                reps: reps, plannedMinutes: planned, payload: .song(song))
        }
        return RoutineStage(id: item.uid, title: "Rest", reps: 1, plannedMinutes: nil, payload: .rest)
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

    /// Advance on a **natural completion** (ADR 0076): step to the next rep of a multi-rep block, or —
    /// on its last rep — roll to the next block. Also the path a rest countdown and a Done-screen
    /// Continue take (both land on the last rep). The player view keys the run screen on `currentRep`,
    /// so a next-rep advance restarts the same drill fresh.
    func advance() {
        stopRestTimer()
        cursor.advance()
        beginCurrentStage()
    }

    /// **Skip** to the next block (user-initiated), abandoning any remaining reps of the current one —
    /// distinct from `advance()`, which would only step to the next rep of a multi-rep block.
    func skip() {
        stopRestTimer()
        cursor.skip()
        beginCurrentStage()
    }

    /// Step back to the previous block (user-initiated). No-op at the first block; it re-lands on a
    /// fresh, stopped run screen, so nothing auto-restarts under you.
    func back() {
        guard cursor.index > 0 else { return }
        stopRestTimer()
        cursor.retreat()
        beginCurrentStage()
    }

    private func beginCurrentStage() {
        guard let stage = current else { state = .finished; return }
        if stage.kind == .rest { beginRest() } else { state = .running }
    }

    // MARK: - Rest (the only phase the conductor plays itself)

    private func beginRest() {
        state = .resting
        restRemaining = AppSettings.routineRestSeconds
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
