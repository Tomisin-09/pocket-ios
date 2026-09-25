import XCTest
@testable import Pocket

/// A run shaped phase by phase (ADR 0221): the switches, the per-phase holds, the phase ranges the
/// staircase lights, and the model's warm-up seed. Plain values throughout — this is the plateau
/// arithmetic that breaks silently (AGENTS.md), and the rows on screen are only as right as it is.
final class PhaseShapedRunTests: XCTestCase {

    /// 80 → 100, reach 106, auto back off 94; one intermediate warm-up stop ⇒ warm-up 80, 90.
    private func ramp(_ shape: RunShape = RunShape(warmupSteps: 1)) -> CommandRamp {
        CommandRamp(tempos: RampTempos(working: 80, command: 100, reach: 106, backoff: 94),
                    shape: shape, backoffOverride: nil, intervalCount: 4, unit: .bars)
    }

    // MARK: - D2: only command is mandatory

    /// Every combination of the three switches, against the plateaus it should draw.
    func testEverySwitchCombinationDrawsExactlyItsPhases() {
        let warmup = [80, 90], command = [100], reach = [106], backoff = [94]
        for includeWarmup in [true, false] {
            for includeReach in [true, false] {
                for includeBackoff in [true, false] {
                    let shape = RunShape(includeWarmup: includeWarmup, includeReach: includeReach,
                                         includeBackoff: includeBackoff, warmupSteps: 1)
                    let expected = (includeWarmup ? warmup : []) + command
                        + (includeReach ? reach : []) + (includeBackoff ? backoff : [])
                    XCTAssertEqual(ramp(shape).plateaus.map(\.bpm), expected,
                                   "warm-up \(includeWarmup), reach \(includeReach), back off \(includeBackoff)")
                }
            }
        }
    }

    func testCommandOnlyIsOnePlateauHeldForTheDwell() {
        let shape = RunShape(includeWarmup: false, includeReach: false, includeBackoff: false, dwell: 4)
        XCTAssertEqual(ramp(shape).plateaus, [CommandRamp.Plateau(bpm: 100, intervals: 4)])
        XCTAssertEqual(ramp(shape).completionInterval, 16, "16 bars — four 4-bar intervals")
    }

    /// With Reach off the back off descends from command, and its steps span that gap.
    func testBackoffDescendsFromCommandWhenReachIsOff() {
        let shape = RunShape(includeWarmup: false, includeReach: false, backoffSteps: 1)
        XCTAssertEqual(ramp(shape).plateaus.map(\.bpm), [100, 97, 94])
    }

    /// A switch removes the phase and nothing else: the pinned back off is still the tail once the
    /// reach comes back, and an off reach doesn't move the auto back off (D2).
    func testASwitchDoesNotMoveAnotherPhasesTempo() {
        var withReach = ramp(RunShape(warmupSteps: 1))
        var withoutReach = ramp(RunShape(includeReach: false, warmupSteps: 1))
        XCTAssertEqual(withReach.plateaus.last?.bpm, withoutReach.plateaus.last?.bpm)
        withReach.backoffOverride = 88
        withoutReach.backoffOverride = 88
        XCTAssertEqual(withReach.plateaus.last?.bpm, 88)
        XCTAssertEqual(withoutReach.plateaus.last?.bpm, 88)
    }

    // MARK: - D3: a hold per phase

    func testEachPhaseHoldsForItsOwnHold() {
        let shape = RunShape(warmupSteps: 1, reachSteps: 1, backoffSteps: 1,
                             warmupHold: 2, dwell: 5, reachHold: 3, backoffHold: 4)
        let plateaus = ramp(shape).plateaus
        XCTAssertEqual(plateaus.map(\.bpm), [80, 90, 100, 103, 106, 100, 94])
        XCTAssertEqual(plateaus.map(\.intervals), [2, 2, 5, 3, 3, 4, 4])
    }

    /// The defaults reproduce the ramp as it was before 0221 — one interval per non-command rung.
    func testDefaultHoldsAreTheOldFixedInterval() {
        XCTAssertEqual(ramp().plateaus.map(\.intervals), [1, 1, 4, 1, 1])
    }

    /// Block fitting (ADR 0129) still moves only the command hold, and prices the new holds as they
    /// stand (D9).
    func testFittingMovesTheCommandHoldAndLeavesTheOthers() {
        let authored = ramp(RunShape(warmupSteps: 1, warmupHold: 3, reachHold: 2, backoffHold: 2))
        let fit = SessionEstimate.fitted(authored, toMinutes: 3, beatsPerBar: 4)
        XCTAssertNotEqual(fit.dwellIntervals, authored.dwellIntervals)
        XCTAssertEqual(fit.plateaus.map(\.bpm), authored.plateaus.map(\.bpm))
        let others = { (ramp: CommandRamp) in ramp.plateaus.filter { $0.bpm != 100 }.map(\.intervals) }
        XCTAssertEqual(others(fit), others(authored))
    }

    // MARK: - D1: which bars each phase drew

    func testPhaseRangesNameEveryPhaseThatDrewBars() {
        let plateaus = ramp(RunShape(warmupSteps: 1, reachSteps: 1)).plateaus   // 80 90 100 103 106 94
        let ranges = CommandRamp.phaseRanges(of: plateaus, command: 100)
        XCTAssertEqual(ranges[.warmup], 0..<2)
        XCTAssertEqual(ranges[.command], 2..<3)
        XCTAssertEqual(ranges[.reach], 3..<5)
        XCTAssertEqual(ranges[.backoff], 5..<6)
    }

    func testPhaseRangesOmitPhasesThatAreOff() {
        let commandOnly = ramp(RunShape(includeWarmup: false, includeReach: false, includeBackoff: false))
        XCTAssertEqual(CommandRamp.phaseRanges(of: commandOnly.plateaus, command: 100), [.command: 0..<1])

        let noReach = ramp(RunShape(includeReach: false, warmupSteps: 1)).plateaus   // 80 90 100 94
        let ranges = CommandRamp.phaseRanges(of: noReach, command: 100)
        XCTAssertNil(ranges[.reach])
        XCTAssertEqual(ranges[.backoff], 3..<4)
    }

    // MARK: - The shape value

    func testCommandCannotBeSwitchedOff() {
        var shape = RunShape()
        shape.setOn(.command, false)
        XCTAssertTrue(shape.isOn(.command))
        shape.setOn(.warmup, false); shape.setOn(.reach, false); shape.setOn(.backoff, false)
        XCTAssertTrue(shape.isCommandOnly)
    }

    func testHoldsClampToTheSharedRange() {
        var shape = RunShape()
        shape.setHold(.warmup, 0)
        shape.setHold(.command, 40)
        XCTAssertEqual(shape.warmupHold, 1)
        XCTAssertEqual(shape.dwell, 12)
    }

    /// The Steps control shows rungs drawn; storage keeps intermediate stops (D4).
    func testRungsAreStoredAsIntermediateStops() {
        var shape = RunShape()
        shape.setRungs(.warmup, 3)
        shape.setRungs(.reach, 1)
        XCTAssertEqual(shape.warmupSteps, 2)
        XCTAssertEqual(shape.reachSteps, 0)
        let tempos = RampTempos(working: 80, command: 100, reach: 106, backoff: 94)
        XCTAssertEqual(tempos.rungs(of: .warmup, in: shape), 3)
    }

    /// The number shown never exceeds the number that fits, whatever is stored.
    func testShownRungsAreClampedToTheGap() {
        let tempos = RampTempos(working: 58, command: 61, reach: 64, backoff: 59)
        let shape = RunShape(warmupSteps: 6, reachSteps: 6, backoffSteps: 6)
        XCTAssertEqual(tempos.rungs(of: .warmup, in: shape), 3)
        XCTAssertEqual(tempos.maxRungs(of: .warmup, in: shape), 3)
        XCTAssertEqual(tempos.rungs(of: .reach, in: shape), 3)
        XCTAssertEqual(tempos.rungs(of: .backoff, in: shape), 5, "descends from the summit, 64 → 59")
        var noReach = shape
        noReach.includeReach = false
        XCTAssertEqual(tempos.rungs(of: .backoff, in: noReach), 2, "from command, 61 → 59")
    }

    // MARK: - The model (D4, D6)

    /// An exercise saved before 0221 derives its count from its stride; once a count is stored the
    /// stride is never read again.
    func testTheWarmupCountIsSeededFromTheStrideUntilSaved() {
        let exercise = Exercise(currentTempo: 51, commandTempo: 61, rampStepBPM: 2)
        XCTAssertNil(exercise.rampWarmupSteps)
        XCTAssertEqual(exercise.warmupSteps, 4, "10-BPM span at a 2-BPM stride ⇒ 5 − 1")
        XCTAssertEqual(exercise.ramp.plateaus.prefix { $0.bpm < 61 }.count, 5, "and plays five rungs")

        exercise.applyRunShape(exercise.runShape)
        XCTAssertEqual(exercise.rampWarmupSteps, 4)
        exercise.rampStepBPM = 1
        XCTAssertEqual(exercise.warmupSteps, 4, "the stride is no longer read")
    }

    func testTheShapeRoundTripsThroughTheModel() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        let shape = RunShape(includeWarmup: false, includeReach: false, includeBackoff: true,
                             warmupSteps: 2, reachSteps: 3, backoffSteps: 1,
                             warmupHold: 2, dwell: 6, reachHold: 3, backoffHold: 4)
        exercise.applyRunShape(shape)
        XCTAssertEqual(exercise.runShape, shape)
        XCTAssertEqual(exercise.ramp.plateaus.first?.bpm, 100, "warm-up off: the run opens at command")
    }

    func testANewExerciseHasEveryPhaseOnAndTheOldHolds() {
        let shape = Exercise(currentTempo: 70, commandTempo: 100).runShape
        XCTAssertTrue(shape.includeWarmup && shape.includeReach && shape.includeBackoff)
        XCTAssertEqual([shape.warmupHold, shape.reachHold, shape.backoffHold], [1, 1, 1])
    }

    /// D6 — with Reach off the run summits at command, so no raise is offered.
    func testNoReachNoRaise() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        XCTAssertGreaterThan(exercise.summitTempo, 100)
        exercise.includeReach = false
        XCTAssertEqual(exercise.summitTempo, 100)
        let anchors = CommandOffer.Anchors(command: 100, floor: 20, ceiling: 300,
                                           raiseTarget: CommandOffer.raisedCommand(
                                               reach: exercise.summitTempo, ceiling: 300),
                                           settleTarget: exercise.derivedBackoff)
        XCTAssertFalse(CommandOffer.canRaise(anchors))
        XCTAssertNil(CommandOffer.bounds(for: .raise, anchors: anchors))
        XCTAssertNotNil(CommandOffer.bounds(for: .settle, anchors: anchors), "the settle half stands")
    }

    func testTheLibraryLinePrintsCommandAloneWithReachOff() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        XCTAssertTrue(exercise.commandProgressLabel.hasPrefix("Command 100 → "))
        exercise.includeReach = false
        XCTAssertTrue(exercise.commandProgressLabel.hasPrefix("Command 100 BPM"))
    }

    // MARK: - D7: the pencil shows only where the review bar doesn't

    func testThePencilAndTheReviewBarNeverShareAScreen() {
        XCTAssertTrue(PracticeReviewBar.isShown(isRunning: false, inRoutine: false))
        XCTAssertFalse(PracticeReviewBar.isShown(isRunning: true, inRoutine: false))
        XCTAssertFalse(PracticeReviewBar.isShown(isRunning: false, inRoutine: true))
        XCTAssertFalse(PracticeReviewBar.isShown(isRunning: true, inRoutine: true))
    }
}
