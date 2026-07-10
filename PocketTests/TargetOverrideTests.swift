import XCTest
@testable import Pocket

/// Manual **reach override** (ADR 0075) — the pinned goal above `command`, unified across `Loop`
/// (× of original) and `Exercise` (absolute BPM). Exercised as plain in-memory `@Model` objects for
/// the pure accessors + the `promoteCommand` auto-clear (the tempo math that breaks silently, per
/// AGENTS.md). The editable-row clamp lives in the views; the model invariant tested here is that a
/// caught-up pin is dropped so a stored reach always sits above the owned command.
final class TargetOverrideTests: XCTestCase {

    // MARK: - Exercise: effective reach falls through / returns the pin

    func testExerciseReachFallsBackToDerivedWhenNoOverride() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        XCTAssertNil(exercise.targetTempoOverride)
        XCTAssertFalse(exercise.hasTargetOverride)
        XCTAssertEqual(exercise.reachTempo, exercise.derivedTarget)
    }

    func testExerciseReachReturnsOverrideVerbatimWhenSet() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempoOverride = 140
        XCTAssertTrue(exercise.hasTargetOverride)
        XCTAssertEqual(exercise.reachTempo, 140)
        // The pure auto value is untouched, so reset-to-auto can fall back to it.
        XCTAssertEqual(exercise.derivedTarget, TempoStretch.targetBPM(forCommand: 100))
    }

    // MARK: - Exercise: promoteCommand auto-clear

    func testExercisePromoteClearsOverrideWhenCommandCatchesUp() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempoOverride = 130
        exercise.promoteCommand(to: 130)          // command meets the pin
        XCTAssertEqual(exercise.command, 130)
        XCTAssertNil(exercise.targetTempoOverride) // dropped → reach reverts to auto above 130
        XCTAssertEqual(exercise.reachTempo, exercise.derivedTarget)
    }

    func testExercisePromotePastOverrideClearsIt() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempoOverride = 130
        exercise.promoteCommand(to: 140)          // command passes the pin
        XCTAssertNil(exercise.targetTempoOverride)
    }

    func testExercisePromoteBelowOverrideKeepsIt() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempoOverride = 150
        exercise.promoteCommand(to: 120)          // still below the pin
        XCTAssertEqual(exercise.command, 120)
        XCTAssertEqual(exercise.targetTempoOverride, 150)
        XCTAssertEqual(exercise.reachTempo, 150)
    }

    func testExercisePromoteNoLongerWritesVestigialTargetTempo() {
        // ADR 0075: promoteCommand stops touching the vestigial `targetTempo`.
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempo = 120                // its declaration default
        exercise.promoteCommand(to: 130)
        XCTAssertEqual(exercise.targetTempo, 120) // unchanged
    }

    // MARK: - Exercise: ramp summits at the effective reach

    func testExerciseRampSummitsAtOverrideWhenSet() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        exercise.targetTempoOverride = 145
        XCTAssertEqual(exercise.ramp.target, 145)
    }

    func testExerciseRampSummitsAtAutoWhenUnpinned() {
        let exercise = Exercise(currentTempo: 70, commandTempo: 100)
        XCTAssertEqual(exercise.ramp.target, TempoStretch.targetBPM(forCommand: 100))
    }

    // MARK: - Loop: effective reach falls through / returns the pin

    func testLoopTargetSpeedFallsBackToDerivedWhenNoOverride() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        XCTAssertNil(loop.targetSpeedOverride)
        XCTAssertFalse(loop.hasTargetOverride)
        XCTAssertEqual(loop.targetSpeed, loop.derivedTargetSpeed, accuracy: 1e-9)
    }

    func testLoopTargetSpeedReturnsOverrideVerbatimWhenSet() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.targetSpeedOverride = 0.95
        XCTAssertTrue(loop.hasTargetOverride)
        XCTAssertEqual(loop.targetSpeed, 0.95, accuracy: 1e-9)
        XCTAssertEqual(loop.derivedTargetSpeed, TempoStretch.targetSpeed(forCommand: 0.85),
                       accuracy: 1e-9)
    }

    // MARK: - Loop: promoteCommand auto-clear

    func testLoopPromoteClearsOverrideWhenCommandCatchesUp() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.targetSpeedOverride = 0.95
        loop.promoteCommand(to: 0.95)             // command meets the pin
        XCTAssertEqual(loop.command, 0.95, accuracy: 1e-9)
        XCTAssertNil(loop.targetSpeedOverride)
    }

    func testLoopPromoteBelowOverrideKeepsIt() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.targetSpeedOverride = 0.98
        loop.promoteCommand(to: 0.90)             // still below the pin
        XCTAssertEqual(loop.targetSpeedOverride, 0.98)
        XCTAssertEqual(loop.targetSpeed, 0.98, accuracy: 1e-9)
    }

    // MARK: - Loop: ramp summits at the effective reach

    func testLoopRampSummitsAtOverrideWhenSet() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        loop.targetSpeedOverride = 0.96
        // The percent staircase summit tracks the pinned reach (0.96× → 96%).
        XCTAssertEqual(loop.ramp.target, LoopCommandRamp.percent(0.96))
    }

    func testLoopRampSummitsAtAutoWhenUnpinned() {
        let loop = Loop(name: "Solo", start: 0.2, end: 0.4, speed: 0.7, repeats: 0)
        loop.commandTempo = 0.85
        XCTAssertEqual(loop.ramp.target, LoopCommandRamp.percent(loop.derivedTargetSpeed))
    }
}
