import XCTest
@testable import Pocket

/// The derived **warm-up floor** on an un-promoted exercise (ADR 0129 sub-decision 1).
///
/// `workingTempo` is a straight alias over `currentTempo`, so before a command is promoted the two are
/// the same number — and `CommandRamp` then emits neither a warm-up (`command > working` is false) nor a
/// backoff (the derived backoff lands *on* command, not below it). Three of the four documented phases
/// were missing from every exercise a player had not yet promoted. Exercised as plain uninserted
/// `@Model` objects, like `TargetOverrideTests` — pure accessors, no context, no container.
final class RampFloorTests: XCTestCase {

    // MARK: - The floor itself

    func testUnmeasuredExerciseDerivesAFloorBelowCommand() {
        let exercise = Exercise(currentTempo: 80)
        XCTAssertFalse(exercise.hasMeasuredCommand)
        // 15% of 80 = 12, inside the 5…20 clamp ⇒ 80 − 12 = 68.
        XCTAssertEqual(exercise.rampFloor, 68)
        XCTAssertLessThan(exercise.rampFloor, exercise.command)
    }

    func testMeasuredExerciseUsesItsStoredWorkingFloor() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        XCTAssertTrue(exercise.hasMeasuredCommand)
        XCTAssertEqual(exercise.rampFloor, 70)
        XCTAssertEqual(exercise.rampFloor, exercise.workingTempo)
    }

    func testTheFloorIsDerivedNeverStored() {
        let exercise = Exercise(currentTempo: 80)
        _ = exercise.rampFloor
        // Reading it must not write anything — there are no users, but a stored floor would be a
        // migration we don't owe and a silent rewrite of an authored recipe.
        XCTAssertEqual(exercise.currentTempo, 80)
        XCTAssertEqual(exercise.workingTempo, 80)
        // And it disappears the moment a real command exists.
        exercise.promoteCommand(to: 96)
        XCTAssertEqual(exercise.rampFloor, exercise.workingTempo)
    }

    // MARK: - What the ramp now plays (the regression this fixes)

    func testUnmeasuredExerciseNowClimbsAndBacksOff() {
        let exercise = Exercise(currentTempo: 80)
        // Floor 68, default step 5 ⇒ warm-up 68 · 73 · 78; dwell at 80; reach = 80 + clamp(4.8, 3…15)
        // ⇒ 85; backoff = max(68, 80 − 5) = 75, which now sits below command so the tail survives.
        XCTAssertEqual(exercise.ramp.plateaus.map(\.bpm), [68, 73, 78, 80, 85, 75])
        XCTAssertEqual(exercise.ramp.plateaus.map(\.intervals), [1, 1, 1, 4, 1, 1])
    }

    func testUnmeasuredExerciseUsedToHaveNeitherWarmUpNorBackoff() {
        // Pin the old behaviour to the cause, so a future change that re-aliases the floor is caught:
        // with working == command the staircase collapses to dwell + summit.
        let collapsed = CommandRamp(working: 80, command: 80, target: 85, stepBPM: 5,
                                    intervalCount: 4, unit: .bars, dwellIntervals: 4,
                                    includeBackoff: true)
        XCTAssertEqual(collapsed.plateaus.map(\.bpm), [80, 85])
    }

    func testDerivedBackoffAgreesWithTheRampItPlays() {
        let exercise = Exercise(currentTempo: 80)
        // The displayed backoff and the played one must not disagree — both take `rampFloor`.
        XCTAssertEqual(exercise.derivedBackoff, 75)
        XCTAssertEqual(exercise.ramp.plateaus.last?.bpm, exercise.derivedBackoff)
    }

    // MARK: - What it does to the planner's estimate

    func testTheFloorLiftsTheEstimateOffItsOneMinuteFloor() {
        let exercise = Exercise(currentTempo: 80)
        // Was 20 bars ≈ 59s, which `SessionEstimate` floors to 1 minute — the input that let
        // `SessionBuilder` pack 15 items into a "Quick 15". Now 36 bars ≈ 112s ⇒ 2.
        // Called on the pure estimator rather than `PracticePlanner.estimatedMinutes(for:)`, which is
        // `@MainActor`; this test has no reason to hop actors for arithmetic it can do directly.
        XCTAssertEqual(SessionEstimate.minutes(forRamp: exercise.ramp,
                                               beatsPerBar: exercise.beatsPerBar), 2)
    }
}
