import Foundation
import SwiftData
import SwiftUI

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

/// The **session conductor** for a routine run (ADR 0066, slice 3): a transport *over* the existing
/// per-unit engines, not a new one. It walks the routine's playable blocks in order and — the one
/// genuinely new thing — **auto-advances** between them on each block's *own natural completion*,
/// never a wall clock. An exercise/loop block ends when its saved `CommandRamp` finishes its last
/// plateau (the engines fire `onRampFinished` / `onFinished`); a rest ends when a short fixed
/// countdown elapses. This is deliberate: the aim is **controlled discomfort, not clean reps** — the
/// ramp already encodes the climb to and past the command tempo, so one pass *is* the block.
///
/// **No evaluation surface (ADR 0070).** The conductor never grades a take: completion is the
/// material's length, never "play it right to advance." It only reflects the session back.
///
/// One drill runs at a time, so it reuses a single `StandaloneMetronomeEngine` across exercise
/// blocks and rebuilds a `LoopRunModel` per loop block (each is bound to one loop at init). Song
/// blocks are reserved for the audio-only play-along (a following slice) and are filtered out until
/// then, alongside orphaned blocks (ADR 0066 R5).
@MainActor
@Observable
final class RoutineSessionPlayer {

    /// Where the transport is. `resting` is its own phase (a countdown, no engine); `finished` shows
    /// the session summary. A rest is short enough that it offers no pause — only Skip.
    enum State: Equatable { case playing, paused, resting, finished }

    let routineName: String
    private(set) var stages: [RoutineStage]
    private(set) var cursor: RoutineSessionCursor
    private(set) var state: State = .playing

    /// Reused across exercise blocks — one drill sounds at a time.
    let metronome = StandaloneMetronomeEngine()
    /// The audio model for the *current* loop block, rebuilt per loop (bound to one loop at init).
    private(set) var loopModel: LoopRunModel?

    /// The fixed session breather between blocks, seconds — a short runtime pause, deliberately
    /// *not* the ADR 0014 planning-time rest minutes (those are a planner concern; at runtime each
    /// block already runs its natural length, so the routine needs no per-block clock).
    static let restSeconds = 20
    private(set) var restRemaining = 0
    private var restTimer: Timer?

    /// The block the player is on, or `nil` once the session is complete.
    var current: RoutineStage? { cursor.isComplete ? nil : stages[cursor.index] }
    var progressLabel: String { cursor.progressLabel }
    var isFinished: Bool { state == .finished }
    /// Pause is offered only during an exercise/loop block, not a rest (too short to bother).
    var canPause: Bool { state == .playing || state == .paused }

    init(routine: Routine) {
        routineName = routine.name.isEmpty ? "Routine" : routine.name
        // Play order, minus blocks the player can't run: orphaned units (deleted → nullified, R5)
        // and song blocks (their audio-only play-along is a following slice).
        let playable = routine.orderedItems.filter { !$0.isOrphaned && $0.song == nil }
        let mapped = playable.map(Self.stage(for:))
        stages = mapped
        cursor = RoutineSessionCursor(total: mapped.count)
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

    /// Begin the session on the first block. Call once, from the player's `onAppear`.
    func start() { beginCurrentStage() }

    /// Tear everything down — the player's `onDisappear` and the End button. Idempotent.
    func end() {
        tearDownCurrent()
        state = .finished
    }

    private func beginCurrentStage() {
        guard let stage = current else { finish(); return }
        switch stage.payload {
        case .exercise(let exercise): beginExercise(exercise)
        case .loop(let loop): beginLoop(loop)
        case .rest: beginRest()
        }
    }

    /// Advance to the next block — the shared path for a natural completion *and* a user Skip. Tears
    /// the current block down first (which detaches its completion callback, so this never re-enters).
    func advance() {
        tearDownCurrent()
        cursor.advance()
        beginCurrentStage()
    }

    private func finish() {
        tearDownCurrent()
        state = .finished
    }

    // MARK: - Per-block start

    private func beginExercise(_ exercise: Exercise) {
        tearDownLoop()
        state = .playing
        metronome.onRampFinished = { [weak self] in self?.advance() }
        metronome.setTimeSignature(TimeSignature.forStored(beats: exercise.beatsPerBar,
                                                           noteValue: exercise.noteValue,
                                                           accentBeats: exercise.accentBeats))
        metronome.run(ramp: exercise.ramp)
    }

    private func beginLoop(_ loop: Loop) {
        metronome.stop()
        let model = LoopRunModel(loop: loop)
        model.onFinished = { [weak self] in self?.advance() }
        loopModel = model
        state = .playing
        Task { [weak self] in
            await model.loadIfNeeded()
            // Guard against a Skip/End during the async load: only start if this is still the live
            // model and the player is still meant to be playing it.
            guard let self, self.loopModel === model, self.state == .playing else { return }
            model.start(ramp: loop.ramp)
        }
    }

    private func beginRest() {
        metronome.stop()
        tearDownLoop()
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

    // MARK: - Pause / resume

    /// Pause or resume the current exercise/loop block. No-op during a rest (there's no pause there)
    /// or once finished.
    func togglePause() {
        switch state {
        case .playing:
            if let loopModel { loopModel.toggle() } else { metronome.toggle() }
            state = .paused
        case .paused:
            if let loopModel { loopModel.toggle() } else { metronome.toggle() }
            state = .playing
        case .resting, .finished:
            break
        }
    }

    // MARK: - Teardown

    /// Stop whatever is running and detach its completion callback, so a teardown from Skip/End/
    /// advance never fires an auto-advance (only a *natural* finish inside the engine does).
    private func tearDownCurrent() {
        stopRestTimer()
        metronome.onRampFinished = nil
        metronome.stop()
        tearDownLoop()
    }

    private func tearDownLoop() {
        loopModel?.onFinished = nil
        loopModel?.stop()
        loopModel = nil
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
}
