import XCTest
@testable import Pocket

/// Pure automator stepping math (ADR 0013) — the per-loop speed ramp the practice model
/// applies as a loop wraps. Exercised as a plain value type, no engine/UI.
final class AutomatorTests: XCTestCase {

    private func config(start: Double = 0.70, step: Double = 0.05, ceiling: Double = 1.0,
                        repeatsPerStep: Int = 2, enabled: Bool = true) -> AutomatorConfig {
        AutomatorConfig(startSpeed: start, stepSpeed: step, ceilingSpeed: ceiling,
                        repeatsPerStep: repeatsPerStep, enabled: enabled)
    }

    func testStartsAtStartSpeed() {
        XCTAssertEqual(config().speed(atLoopIteration: 0), 0.70, accuracy: 1e-9)
    }

    func testStepsEveryRepeatsPerStep() {
        let cfg = config(repeatsPerStep: 2)   // passes 0–1 → 0.70, 2–3 → 0.75, 4–5 → 0.80
        XCTAssertEqual(cfg.speed(atLoopIteration: 1), 0.70, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 2), 0.75, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 3), 0.75, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 4), 0.80, accuracy: 1e-9)
    }

    func testHoldsAtCeiling() {
        let cfg = config()   // 0.70 → 1.00 by 0.05: reaches the ceiling at step 6 (iteration 12)
        XCTAssertEqual(cfg.speed(atLoopIteration: 12), 1.0, accuracy: 1e-9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 100), 1.0, accuracy: 1e-9)
    }

    func testNonPositiveStepIsFlat() {
        XCTAssertEqual(config(step: 0).speed(atLoopIteration: 10), 0.70, accuracy: 1e-9)
    }

    func testCeilingAtOrBelowStartIsFlat() {
        let cfg = config(start: 0.9, ceiling: 0.9)
        XCTAssertEqual(cfg.speed(atLoopIteration: 10), 0.9, accuracy: 1e-9)
    }

    func testClampsToEngineSpeedBounds() {
        let high = config(start: 1.9, step: 0.2, ceiling: 3.0)
        XCTAssertLessThanOrEqual(high.speed(atLoopIteration: 100), TempoMath.maxSpeed)
        let low = config(start: 0.1, step: 0.05, ceiling: 0.5)
        XCTAssertGreaterThanOrEqual(low.speed(atLoopIteration: 0), TempoMath.minSpeed)
    }

    func testRepeatsPerStepZeroTreatedAsOne() {
        XCTAssertEqual(config(repeatsPerStep: 0).speed(atLoopIteration: 1), 0.75, accuracy: 1e-9)
    }

    func testStepCount() {
        XCTAssertEqual(config().stepCount, 7)                       // 0.70→1.00 by 0.05 = 6 + start
        XCTAssertEqual(config(step: 0).stepCount, 1)                // flat
        XCTAssertEqual(config(start: 1.0, ceiling: 1.0).stepCount, 1)
    }
}
