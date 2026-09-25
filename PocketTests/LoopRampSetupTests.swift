import XCTest
@testable import Pocket

/// Loop run-setup persistence (ADR 0057 follow-up, reshaped by ADR 0221 D8). Two pure surfaces:
/// `LoopSetupState` equality drives the Save Changes button (`isDirty`), and the `Loop` fields
/// round-trip the staircase shape. `Loop` is built **uninserted** (never `context.insert` in the test
/// host — that SIGTRAPs; stored-property logic reads fine off a bare `@Model`), mirroring
/// `LoopEditSnapshotTests`.
final class LoopRampSetupTests: XCTestCase {

    private func makeState(_ shape: RunShape = RunShape(warmupSteps: 2, reachSteps: 1,
                                                        backoffSteps: 1)) -> LoopSetupState {
        LoopSetupState(working: 70, command: 85, shape: shape)
    }

    // MARK: - isDirty driver (LoopSetupState equality, per field)

    func testUnchangedStatesAreEqual() {
        XCTAssertEqual(makeState(), makeState())
    }

    func testEachFieldChangeIsDetected() {
        let base = makeState()
        var moved = base
        moved.working = 71
        XCTAssertNotEqual(moved, base)
        moved = base
        moved.command = 86
        XCTAssertNotEqual(moved, base)
        moved = base
        moved.targetOverride = 95
        XCTAssertNotEqual(moved, base)
        // Back-off pinned floor (user-testing note 6) arms Save.
        moved = base
        moved.backoffOverride = 72
        XCTAssertNotEqual(moved, base)
    }

    /// Every part of the shape arms Save — a switch, a rung count, a hold (ADR 0221).
    func testEachShapeChangeIsDetected() {
        let base = makeState()
        let edits: [(inout RunShape) -> Void] = [
            { $0.includeWarmup = false }, { $0.includeReach = false }, { $0.includeBackoff = false },
            { $0.warmupSteps = 3 }, { $0.reachSteps = 2 }, { $0.backoffSteps = 2 },
            { $0.warmupHold = 2 }, { $0.dwell = 6 }, { $0.reachHold = 2 }, { $0.backoffHold = 2 }
        ]
        for (index, edit) in edits.enumerated() {
            var shape = base.shape
            edit(&shape)
            XCTAssertNotEqual(makeState(shape), base, "shape edit \(index) must arm Save")
        }
    }

    // MARK: - Model round-trip

    func testFreshLoopReadsRampDefaults() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        XCTAssertEqual(loop.rampWarmupSteps, 0)
        XCTAssertEqual(loop.rampReachSteps, 0)
        XCTAssertEqual(loop.rampBackoffSteps, 0)
        XCTAssertEqual(loop.rampRepsPerStep, 1)
        XCTAssertEqual(loop.rampDwellIntervals, 4)
        // A fresh loop's shape is the default one: every phase on, one pass a rung, four at command.
        XCTAssertEqual(loop.runShape, RunShape())
    }

    func testTheShapeRoundTrips() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        let shape = RunShape(includeWarmup: false, includeReach: false, includeBackoff: true,
                             warmupSteps: 3, reachSteps: 2, backoffSteps: 1,
                             warmupHold: 2, dwell: 6, reachHold: 3, backoffHold: 5)
        loop.applyRunShape(shape)
        XCTAssertEqual(loop.runShape, shape)
    }

    /// The stored dwell flows into the loop's `ramp` — the command plateau holds that many passes
    /// (ADR 0078). Verifies the model → `CommandRamp` seam a routine block runs from.
    func testDwellFlowsIntoLoopRamp() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        loop.promoteCommand(to: 0.95)
        loop.rampDwellIntervals = 7

        let commandPct = LoopCommandRamp.percent(loop.command)
        let dwellPlateau = loop.ramp.plateaus.first { $0.bpm == commandPct }
        XCTAssertEqual(dwellPlateau?.intervals, 7)
    }

    /// The ramp fields are independent of the ADR-0013 automator fields — writing one family must not
    /// disturb the other (the whole point of keeping them decoupled).
    func testRampFieldsAreIndependentOfAutomator() {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        loop.automatorStepCount = 6
        loop.automatorLoopsPerStep = 2

        loop.applyRunShape(RunShape(warmupSteps: 3, reachSteps: 2, backoffSteps: 1, dwell: 8))

        XCTAssertEqual(loop.automatorStepCount, 6)
        XCTAssertEqual(loop.automatorLoopsPerStep, 2)
    }
}
