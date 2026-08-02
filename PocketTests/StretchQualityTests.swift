import XCTest
@testable import Pocket

/// The time-pitch smoothness curve (ADR 0140 §2). Pure math, no AVFoundation — the AU's *sound* is a
/// device-only listening claim, but the number handed to it must never leave the parameter's range or
/// invert (smoother when faster), and neither failure is visible without a test.
final class StretchQualityTests: XCTestCase {

    // MARK: - Range

    func testStaysInsideTheAUsParameterRangeAcrossEveryReachableRate() {
        for step in 0...175 {
            let rate = 0.25 + Double(step) * 0.01     // 0.25 … 2.0, the engine's own clamp
            let smoothness = StretchQuality.smoothness(forRate: rate)
            XCTAssertGreaterThanOrEqual(smoothness, StretchQuality.minimumSmoothness,
                                        "rate \(rate) produced \(smoothness), below the AU's floor")
            XCTAssertLessThanOrEqual(smoothness, StretchQuality.maximumSmoothness,
                                     "rate \(rate) produced \(smoothness), above the AU's ceiling")
        }
    }

    func testAnAbsurdlySlowRateClampsToTheCeilingRatherThanRunningAway() {
        // Unreachable through the engine, but the curve is linear in 1/rate and would otherwise
        // sail past 32 — the AU would reject it.
        XCTAssertEqual(StretchQuality.smoothness(forRate: 0.01), StretchQuality.maximumSmoothness)
    }

    // MARK: - Monotonicity

    func testSlowingDownNeverMakesTheOutputLessSmooth() {
        var previous = StretchQuality.smoothness(forRate: 0.25)
        for step in 1...175 {
            let rate = 0.25 + Double(step) * 0.01
            let smoothness = StretchQuality.smoothness(forRate: rate)
            XCTAssertLessThanOrEqual(smoothness, previous,
                                     "smoothness rose at rate \(rate) — faster must never be smoother")
            previous = smoothness
        }
    }

    // MARK: - Endpoints

    func testUnityAndAboveRestAtTheLowValue() {
        // Nothing is being stretched at or above 1×, so there are no artifacts to smooth away and
        // no reason to pay the CPU. Must not climb when speeding up.
        XCTAssertEqual(StretchQuality.smoothness(forRate: 1.0), StretchQuality.unitySmoothness)
        XCTAssertEqual(StretchQuality.smoothness(forRate: 1.5), StretchQuality.unitySmoothness)
        XCTAssertEqual(StretchQuality.smoothness(forRate: 2.0), StretchQuality.unitySmoothness)
    }

    func testHalfSpeedPassesTheAUsOwnDefault() {
        // A 2× stretch is where the old pinned 3.0 was audibly wrong; the curve should be past
        // Apple's 8.0 default by here.
        XCTAssertGreaterThan(StretchQuality.smoothness(forRate: 0.5), 8.0)
    }

    func testTheSlowestRateReachesTheHighTeens() {
        // 0.25× is a 4× stretch — the worst case the app allows, and the point of the whole curve.
        XCTAssertEqual(StretchQuality.smoothness(forRate: 0.25), 18.0, accuracy: 0.001)
    }

    func testTheOldPinnedFloorIsNeverChosenForARateThatStretches() {
        // Regression guard on the decision itself: 3.0 is *minimum* smoothness, i.e. maximum
        // artifacts, and the engine used to pin it at every rate.
        for rate in [0.25, 0.5, 0.75, 0.9] {
            XCTAssertGreaterThan(StretchQuality.smoothness(forRate: rate),
                                 StretchQuality.minimumSmoothness,
                                 "rate \(rate) fell back to the AU's artifact floor")
        }
    }

    // MARK: - Degenerate input

    func testANonPositiveRateFallsBackInsteadOfDividingByZero() {
        XCTAssertEqual(StretchQuality.smoothness(forRate: 0), StretchQuality.unitySmoothness)
        XCTAssertEqual(StretchQuality.smoothness(forRate: -1), StretchQuality.unitySmoothness)
    }
}
