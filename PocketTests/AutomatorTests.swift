import XCTest
@testable import Pocket

/// Pure automator stepping math (ADR 0013) — the per-loop speed ramp the practice model
/// applies as a loop wraps. Start → target over N steps (up or down), held at the target.
/// Exercised as a plain value type, no engine/UI.
final class AutomatorTests: XCTestCase {

    private func config(start: Double = 0.70, target: Double = 1.0, steps: Int = 6,
                        loops: Int = 2, enabled: Bool = true) -> AutomatorConfig {
        AutomatorConfig(startSpeed: start, targetSpeed: target, stepCount: steps,
                        loopsPerStep: loops, enabled: enabled)
    }

    func testStartsAtStartSpeed() {
        XCTAssertEqual(config().speed(atLoopIteration: 0), 0.70, accuracy: 1e-9)
    }

    func testAscendingStepsEveryLoopsPerStep() {
        let cfg = config(loops: 2)   // 0.70→1.00 in 6 steps; +0.05 each, every 2 passes
        XCTAssertEqual(cfg.speed(atLoopIteration: 1), 0.70, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 2), 0.75, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 3), 0.75, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 4), 0.80, accuracy: 1e-9)
    }

    func testHoldsAtTarget() {
        let cfg = config()
        XCTAssertEqual(cfg.speed(atLoopIteration: 12), 1.0, accuracy: 1e-9)   // step 6 == stepCount
        XCTAssertEqual(cfg.speed(atLoopIteration: 100), 1.0, accuracy: 1e-9)
    }

    func testDescendingRamp() {
        let cfg = config(start: 1.0, target: 0.70, steps: 6, loops: 2)
        XCTAssertEqual(cfg.speed(atLoopIteration: 0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 2), 0.95, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 12), 0.70, accuracy: 1e-9)
        XCTAssertLessThan(cfg.speed(atLoopIteration: 6), cfg.speed(atLoopIteration: 2))
    }

    func testRoundsToTenthPercent() {
        // 0.70 → 1.00 in 7 steps: step 1 = 0.70 + 0.30/7 = 0.742857… → 0.743 (74.3%)
        let cfg = config(steps: 7)
        XCTAssertEqual(cfg.speed(atLoopIteration: 2), 0.743, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 14), 1.0, accuracy: 1e-9, "final step lands exactly on target")
    }

    func testFlatWhenStartEqualsTarget() {
        XCTAssertEqual(config(start: 0.9, target: 0.9).speed(atLoopIteration: 10), 0.9, accuracy: 1e-9)
    }

    func testZeroStepsIsFlat() {
        XCTAssertEqual(config(steps: 0).speed(atLoopIteration: 10), 0.70, accuracy: 1e-9)
    }

    func testLoopsPerStepZeroTreatedAsOne() {
        XCTAssertEqual(config(loops: 0).speed(atLoopIteration: 1), 0.75, accuracy: 1e-9)
    }

    func testClampsToEngineSpeedBounds() {
        let high = config(start: 1.9, target: 3.0, steps: 4)
        XCTAssertLessThanOrEqual(high.speed(atLoopIteration: 100), TempoMath.maxSpeed)
        let low = config(start: 0.5, target: 0.1, steps: 4)
        XCTAssertGreaterThanOrEqual(low.speed(atLoopIteration: 100), TempoMath.minSpeed)
    }

    func testStepSizeIsSigned() {
        XCTAssertEqual(config().stepSize, 0.05, accuracy: 1e-9)                       // ascending
        XCTAssertEqual(config(start: 1.0, target: 0.70).stepSize, -0.05, accuracy: 1e-9)   // descending
        XCTAssertEqual(config(start: 0.8, target: 0.8).stepSize, 0, accuracy: 1e-9)        // flat
    }

    func testTotalLoops() {
        // (stepCount + 1) plateaus — start, 5 intermediate, held target — × loopsPerStep.
        XCTAssertEqual(config(steps: 6, loops: 2).totalLoops, 14)
        XCTAssertEqual(config(steps: 4, loops: 3).totalLoops, 15)
    }

    func testTargetPlateauGetsItsLoopsThenTotalLoopsIsTheStop() {
        let cfg = config(steps: 6, loops: 2)   // target first reached at iter 12, held for 2 passes
        XCTAssertEqual(cfg.speed(atLoopIteration: 12), 1.0, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 13), 1.0, accuracy: 1e-9)
        XCTAssertEqual(cfg.totalLoops, 14, "stop once iteration reaches this — after the target's last pass")
    }

    func testTotalLoopsTreatsComponentsAsAtLeastOne() {
        XCTAssertEqual(config(steps: 0, loops: 0).totalLoops, 1)   // 1 plateau × 1 pass
    }

    // MARK: - Progress (ADR 0260 D3) — what the sheet lights while the ramp plays

    func testPlateauCountIsOnePerHeldTempo() {
        XCTAssertEqual(config(steps: 6).plateauCount, 7, "start, five intermediate, the target")
        XCTAssertEqual(config(steps: 0).plateauCount, 1)
    }

    func testProgressStartsOnTheFirstPassOfTheFirstPlateau() {
        XCTAssertEqual(config().progress(atLoopIteration: 0),
                       AutomatorProgress(plateau: 0, pass: 1, isFinished: false))
    }

    func testProgressCountsPassesWithinAPlateau() {
        let cfg = config(steps: 6, loops: 2)
        XCTAssertEqual(cfg.progress(atLoopIteration: 1), AutomatorProgress(plateau: 0, pass: 2, isFinished: false))
        XCTAssertEqual(cfg.progress(atLoopIteration: 2), AutomatorProgress(plateau: 1, pass: 1, isFinished: false))
        XCTAssertEqual(cfg.progress(atLoopIteration: 5), AutomatorProgress(plateau: 2, pass: 2, isFinished: false))
    }

    /// The target is a plateau of its own and plays all its passes before the ramp is done — the stop
    /// `testTargetPlateauGetsItsLoopsThenTotalLoopsIsTheStop` pins, read from the other side.
    func testTheTargetPlaysEveryPassBeforeTheRampFinishes() {
        let cfg = config(steps: 6, loops: 2)
        XCTAssertEqual(cfg.progress(atLoopIteration: 12), AutomatorProgress(plateau: 6, pass: 1, isFinished: false))
        XCTAssertEqual(cfg.progress(atLoopIteration: 13), AutomatorProgress(plateau: 6, pass: 2, isFinished: false))
        XCTAssertTrue(cfg.progress(atLoopIteration: 14).isFinished, "totalLoops is the stop")
    }

    /// Finished holds on the target's last pass rather than counting on past the end, so the sheet
    /// never reads "Step 8/7".
    func testAFinishedRampHoldsOnTheTargetsLastPass() {
        let cfg = config(steps: 6, loops: 2)
        for iteration in [14, 15, 100] {
            XCTAssertEqual(cfg.progress(atLoopIteration: iteration),
                           AutomatorProgress(plateau: 6, pass: 2, isFinished: true), "iteration \(iteration)")
        }
    }

    /// The lit plateau and the speed shown are read off one iteration, and must name the same tempo:
    /// every pass plays its plateau's speed.
    func testTheLitPlateauPlaysTheSpeedShown() {
        let cfg = config(start: 1.0, target: 0.62, steps: 7, loops: 3)
        for iteration in 0..<cfg.totalLoops {
            let plateau = cfg.progress(atLoopIteration: iteration).plateau
            XCTAssertEqual(cfg.speed(atLoopIteration: iteration),
                           cfg.speed(atLoopIteration: plateau * 3), accuracy: 1e-9, "iteration \(iteration)")
        }
    }

    func testProgressTreatsANegativeIterationAsTheStart() {
        XCTAssertEqual(config().progress(atLoopIteration: -3),
                       AutomatorProgress(plateau: 0, pass: 1, isFinished: false))
    }

    func testProgressTreatsLoopsPerStepZeroAsOne() {
        let cfg = config(steps: 2, loops: 0)
        XCTAssertEqual(cfg.progress(atLoopIteration: 1), AutomatorProgress(plateau: 1, pass: 1, isFinished: false))
        XCTAssertTrue(cfg.progress(atLoopIteration: 3).isFinished)
    }

    // MARK: - The staircase's lit bar

    func testOneBarPerPlateauLightsThePlateauItself() {
        for plateau in 0..<7 {
            XCTAssertEqual(RampStairs.litBar(plateau: plateau, of: 7, across: 7), plateau)
        }
    }

    /// A ramp with more plateaus than the 12 bars drawn still lights the first bar at the start and the
    /// **last** bar at the target. It used to divide by the plateau count, so 13 plateaus lit bar 11 of
    /// 12 on *Done*.
    func testALongRampLightsTheEndBarsAtItsEnds() {
        for plateaus in [13, 17, 21] {
            XCTAssertEqual(RampStairs.litBar(plateau: 0, of: plateaus, across: 12), 0, "\(plateaus) plateaus")
            XCTAssertEqual(RampStairs.litBar(plateau: plateaus - 1, of: plateaus, across: 12), 11,
                           "\(plateaus) plateaus")
        }
    }

    func testTheLitBarIsClampedToTheStaircase() {
        XCTAssertEqual(RampStairs.litBar(plateau: -1, of: 7, across: 7), 0)
        XCTAssertEqual(RampStairs.litBar(plateau: 9, of: 7, across: 7), 6)
        XCTAssertEqual(RampStairs.litBar(plateau: 30, of: 21, across: 12), 11)
    }
}
