import XCTest
@testable import Pocket

/// The rhythm-change binding (ADR 0121): the pure rescale, the "does this revalue a measured
/// achievement?" test, and the two answers. This is tempo arithmetic that silently corrupts a whole
/// ramp when it's wrong — a rescaled command that lands under its working floor, or a pinned reach
/// left below command — so the invariants are asserted, not just the happy numbers.
final class RhythmChangeTests: XCTestCase {

    /// The engine's real range, so a clamp in a test means the same thing it means on screen.
    private let range = StandaloneMetronomeEngine.bpmRange

    private func tempos(working: Int = 60, command: Int = 80,
                        reach: Int? = nil, backoff: Int? = nil) -> RhythmChange.Tempos {
        RhythmChange.Tempos(working: working, command: command,
                            reachOverride: reach, backoffOverride: backoff)
    }

    // MARK: - The rescale

    func testDoublingTheRateHalvesEveryTempo() {
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 60, command: 80),
                                                   from: 2, to: 4, clampedTo: range)
        XCTAssertEqual(result.command, 40)
        XCTAssertEqual(result.working, 30)
    }

    func testHalvingTheRateDoublesEveryTempo() {
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 60, command: 80),
                                                   from: 4, to: 2, clampedTo: range)
        XCTAssertEqual(result.command, 160)
        XCTAssertEqual(result.working, 120)
    }

    /// The property that gives the option its name: notes per minute is unchanged.
    func testNoteSpeedIsPreservedAcrossTheChange() {
        // Each case picks a command whose rescaled result stays inside the engine's 30…300 range —
        // no single tempo survives both 1→4 and 4→1, and a clamped result cannot hold the note speed
        // by definition (clamping is its own test below).
        for (old, new, command) in [(1, 4, 120), (4, 1, 60), (2, 3, 120), (3, 2, 80), (2, 4, 120)] {
            let result = RhythmChange.keepingNoteSpeed(tempos(working: 30, command: command),
                                                       from: old, to: new, clampedTo: range)
            XCTAssertEqual(RhythmChange.notesPerMinute(bpm: result.command, perBeat: new),
                           RhythmChange.notesPerMinute(bpm: command, perBeat: old),
                           "\(old) → \(new) should hold the note speed")
        }
    }

    func testAnUnchangedRateIsANoOp() {
        let start = tempos(working: 60, command: 80, reach: 96, backoff: 70)
        XCTAssertEqual(RhythmChange.keepingNoteSpeed(start, from: 2, to: 2, clampedTo: range), start)
    }

    func testResultsAreClampedIntoTheEngineRange() {
        let fast = RhythmChange.keepingNoteSpeed(tempos(command: 200), from: 4, to: 1,
                                                 clampedTo: range)
        XCTAssertEqual(fast.command, range.upperBound)
        let slow = RhythmChange.keepingNoteSpeed(tempos(working: 30, command: 40), from: 1, to: 4,
                                                 clampedTo: range)
        XCTAssertEqual(slow.command, range.lowerBound, "clamped to the floor, not below it")
    }

    /// Clamping can squash two tempos onto the same value; the ramp invariants must survive it.
    func testWorkingNeverEndsUpAboveCommand() {
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 280, command: 300),
                                                   from: 4, to: 1, clampedTo: range)
        XCTAssertLessThanOrEqual(result.working, result.command)
    }

    func testAPinnedReachThatCollidesWithCommandDropsToAuto() {
        // Both squash onto the range floor under the clamp, so the pin no longer clears command.
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 30, command: 30, reach: 32),
                                                   from: 1, to: 4, clampedTo: range)
        XCTAssertNil(result.reachOverride, "a reach must stay strictly above command")
    }

    func testAPinnedReachThatStillClearsCommandIsKept() {
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 60, command: 80, reach: 100),
                                                   from: 2, to: 4, clampedTo: range)
        XCTAssertEqual(result.reachOverride, 50)
        XCTAssertGreaterThan(result.reachOverride ?? 0, result.command)
    }

    func testAPinnedBackoffStaysAtOrBelowCommand() {
        let result = RhythmChange.keepingNoteSpeed(tempos(working: 60, command: 80, backoff: 70),
                                                   from: 2, to: 4, clampedTo: range)
        XCTAssertEqual(result.backoffOverride, 35)
        XCTAssertLessThanOrEqual(result.backoffOverride ?? 0, result.command)
    }

    // MARK: - When the player has to be asked

    func testAChangeRevaluesOnlyAMeasuredBoundCommand() {
        let measured = Exercise(commandTempo: 80, notesPerBeat: 2, commandNotesPerBeat: 2)
        XCTAssertTrue(measured.rhythmChangeRevaluesCommand(to: 4))
        XCTAssertFalse(measured.rhythmChangeRevaluesCommand(to: 2), "same rhythm changes nothing")
    }

    func testAnUnmeasuredCommandIsNeverRevalued() {
        let fresh = Exercise(commandTempo: nil, notesPerBeat: 2)
        XCTAssertFalse(fresh.rhythmChangeRevaluesCommand(to: 4))
    }

    /// A command measured on a drill that stated no rhythm has nothing to rescale *from*, so there is
    /// no question to ask — the new rhythm is simply stamped.
    func testAnUnboundCommandIsNeverRevalued() {
        let unbound = Exercise(commandTempo: 80)
        XCTAssertFalse(unbound.rhythmChangeRevaluesCommand(to: 4))
    }

    // MARK: - The two answers

    func testKeepNoteSpeedRescalesAndRebinds() {
        let exercise = Exercise(currentTempo: 60, commandTempo: 80,
                                notesPerBeat: 2, commandNotesPerBeat: 2)
        exercise.keepNoteSpeed(movingTo: 4, range: range)
        XCTAssertEqual(exercise.commandTempo, 40)
        XCTAssertEqual(exercise.workingTempo, 30)
        XCTAssertEqual(exercise.commandNotesPerBeat, 4, "the achievement is re-bound, not left stale")
        XCTAssertEqual(exercise.commandNotesPerMinute, 160, "same note speed as 80 @ eighths")
    }

    func testReMeasureClearsTheCommandAndItsBinding() {
        let exercise = Exercise(currentTempo: 60, commandTempo: 80,
                                notesPerBeat: 2, commandNotesPerBeat: 2)
        exercise.reMeasureCommand(movingTo: 4, range: range)
        XCTAssertNil(exercise.commandTempo)
        XCTAssertNil(exercise.commandNotesPerBeat)
        XCTAssertFalse(exercise.hasMeasuredCommand)
    }

    /// Re-measuring still rescales the warm-up floor: a floor left at the old rhythm is the wrong
    /// speed to warm up at, whichever answer was given.
    func testReMeasureStillRescalesTheWorkingFloor() {
        let exercise = Exercise(currentTempo: 60, commandTempo: 80,
                                notesPerBeat: 2, commandNotesPerBeat: 2)
        exercise.reMeasureCommand(movingTo: 4, range: range)
        XCTAssertEqual(exercise.workingTempo, 30)
    }

    func testPromoteBindsTheCommandToTheCurrentRhythm() {
        let exercise = Exercise(notesPerBeat: 3)
        exercise.promoteCommand(to: 100)
        XCTAssertEqual(exercise.commandNotesPerBeat, 3)
    }

    func testPromoteOnARhythmlessDrillBindsNothing() {
        let exercise = Exercise()
        exercise.promoteCommand(to: 100)
        XCTAssertNil(exercise.commandNotesPerBeat)
    }

    // MARK: - The prompt

    func testThePromptQuotesTheRescaledCommand() {
        let exercise = Exercise(currentTempo: 60, commandTempo: 80,
                                notesPerBeat: 2, commandNotesPerBeat: 2)
        let prompt = RhythmChangePrompt(exercise: exercise, movingTo: 4, range: range)
        XCTAssertEqual(prompt?.rescaledCommand, 40)
        XCTAssertEqual(prompt?.title, "Eighths → Sixteenths")
        XCTAssertEqual(prompt?.keepLabel, "Keep note speed · 40 BPM")
    }

    func testThereIsNoPromptWhenNothingIsRevalued() {
        XCTAssertNil(RhythmChangePrompt(exercise: Exercise(commandTempo: 80), movingTo: 4,
                                        range: range))
    }

    // MARK: - Backfill (ADR 0121)

    func testBackfillMovesTheRetiredSubdivisionIntoNotesPerBeat() {
        let exercise = Exercise(commandTempo: 80, subdivision: .sixteenths, template: .warmup)
        ExerciseNoteRateBackfill.apply(to: exercise)
        XCTAssertEqual(exercise.notesPerBeat, 4)
        XCTAssertEqual(exercise.commandNotesPerBeat, 4)
    }

    /// `.none` stated nothing, so it stays nothing — the backfill must not mint a defaulted
    /// "quarters" that every surface would then start labelling.
    func testBackfillLeavesAStatedNothingUnstated() {
        let exercise = Exercise(commandTempo: 70, subdivision: .none, template: .chords)
        ExerciseNoteRateBackfill.apply(to: exercise)
        XCTAssertNil(exercise.notesPerBeat)
        XCTAssertNil(exercise.commandNotesPerBeat)
    }

    /// Content wins over the retired field, so a drill whose payload states 16ths binds to 16ths even
    /// though its old click said eighths.
    func testBackfillBindsToTheContentRhythmNotTheRetiredField() {
        let exercise = Exercise(commandTempo: 80, subdivision: .eighths, template: .scales)
        exercise.setFretboardContent(.custom(FretboardDrill(notesPerBeat: 4, notes: [nil, nil])))
        ExerciseNoteRateBackfill.apply(to: exercise)
        XCTAssertEqual(exercise.commandNotesPerBeat, 4)
    }

    func testBackfillIsIdempotent() {
        let exercise = Exercise(commandTempo: 80, subdivision: .sixteenths, template: .warmup)
        ExerciseNoteRateBackfill.apply(to: exercise)
        exercise.keepNoteSpeed(movingTo: 2, range: range)
        ExerciseNoteRateBackfill.apply(to: exercise)
        XCTAssertEqual(exercise.commandNotesPerBeat, 2, "a re-run must not undo an answered change")
    }

    func testBackfillLeavesAnUnmeasuredCommandUnbound() {
        let exercise = Exercise(commandTempo: nil, subdivision: .sixteenths, template: .warmup)
        ExerciseNoteRateBackfill.apply(to: exercise)
        XCTAssertEqual(exercise.notesPerBeat, 4)
        XCTAssertNil(exercise.commandNotesPerBeat, "nothing measured, so nothing to bind")
    }
}
