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
}
