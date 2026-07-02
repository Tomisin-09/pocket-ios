import XCTest
@testable import Pocket

/// Loop run-setup ramp-shape persistence (ADR 0057 follow-up). Two pure surfaces:
/// `LoopSetupState` equality drives the Save Changes button (`isDirty`), and the four dedicated
/// `Loop` fields round-trip the staircase shape. `Loop` is built **uninserted** (never
/// `context.insert` in the test host — that SIGTRAPs; stored-property logic reads fine off a bare
/// `@Model`), mirroring `LoopEditSnapshotTests`.
final class LoopRampSetupTests: XCTestCase {

    private func makeState() -> LoopSetupState {
        LoopSetupState(working: 70, command: 85, warmupSteps: 2,
                       reachSteps: 1, backoffSteps: 1, repsPerStep: 3)
    }

    // MARK: - isDirty driver (LoopSetupState equality, per field)

    func testUnchangedStatesAreEqual() {
        XCTAssertEqual(makeState(), makeState())
    }

    func testEachFieldChangeIsDetected() {
        let base = makeState()

        XCTAssertNotEqual(LoopSetupState(working: 71, command: 85, warmupSteps: 2,
                                         reachSteps: 1, backoffSteps: 1, repsPerStep: 3), base)
        XCTAssertNotEqual(LoopSetupState(working: 70, command: 86, warmupSteps: 2,
                                         reachSteps: 1, backoffSteps: 1, repsPerStep: 3), base)
        XCTAssertNotEqual(LoopSetupState(working: 70, command: 85, warmupSteps: 3,
                                         reachSteps: 1, backoffSteps: 1, repsPerStep: 3), base)
        XCTAssertNotEqual(LoopSetupState(working: 70, command: 85, warmupSteps: 2,
                                         reachSteps: 2, backoffSteps: 1, repsPerStep: 3), base)
        XCTAssertNotEqual(LoopSetupState(working: 70, command: 85, warmupSteps: 2,
                                         reachSteps: 1, backoffSteps: 2, repsPerStep: 3), base)
        XCTAssertNotEqual(LoopSetupState(working: 70, command: 85, warmupSteps: 2,
                                         reachSteps: 1, backoffSteps: 1, repsPerStep: 4), base)
    }

    // MARK: - Model round-trip (the four dedicated fields)

    func testFreshLoopReadsRampDefaults() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        XCTAssertEqual(loop.rampWarmupSteps, 0)
        XCTAssertEqual(loop.rampReachSteps, 0)
        XCTAssertEqual(loop.rampBackoffSteps, 0)
        XCTAssertEqual(loop.rampRepsPerStep, LoopCommandRamp.defaultRepsPerStep)
    }

    func testRampFieldsRoundTrip() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)

        loop.rampWarmupSteps = 3
        loop.rampReachSteps = 2
        loop.rampBackoffSteps = 1
        loop.rampRepsPerStep = 4

        XCTAssertEqual(loop.rampWarmupSteps, 3)
        XCTAssertEqual(loop.rampReachSteps, 2)
        XCTAssertEqual(loop.rampBackoffSteps, 1)
        XCTAssertEqual(loop.rampRepsPerStep, 4)
    }

    /// The four ramp fields are independent of the ADR-0013 automator fields — writing one family
    /// must not disturb the other (the whole point of keeping them decoupled).
    func testRampFieldsAreIndependentOfAutomator() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        loop.automatorStepCount = 6
        loop.automatorLoopsPerStep = 2

        loop.rampWarmupSteps = 3
        loop.rampReachSteps = 2
        loop.rampBackoffSteps = 1
        loop.rampRepsPerStep = 4

        XCTAssertEqual(loop.automatorStepCount, 6)
        XCTAssertEqual(loop.automatorLoopsPerStep, 2)
    }
}
