import XCTest
@testable import Pocket

final class TempoMathTests: XCTestCase {

    // MARK: effectiveBPM

    func testEffectiveBPMFromBrief() {
        // Brief: 85 BPM at 0.50× shows 43.
        XCTAssertEqual(TempoMath.effectiveBPM(songBPM: 85, speed: 0.50), 43)
    }

    func testEffectiveBPMAtFullSpeed() {
        XCTAssertEqual(TempoMath.effectiveBPM(songBPM: 120, speed: 1.0), 120)
    }

    func testEffectiveBPMRoundsHalfAwayFromZero() {
        XCTAssertEqual(TempoMath.effectiveBPM(songBPM: 90, speed: 0.90), 81)
    }

    // MARK: slider mapping

    func testPositionZeroIsMinSpeed() {
        XCTAssertEqual(TempoMath.speed(forPosition: 0), 0.25, accuracy: 0.0001)
    }

    func testPositionOneIsMaxSpeed() {
        XCTAssertEqual(TempoMath.speed(forPosition: 1), 2.0, accuracy: 0.0001)
    }

    func testSplitPositionIsFullSpeed() {
        // 1.0× sits at the asymmetric split, left of centre.
        XCTAssertEqual(TempoMath.speed(forPosition: TempoMath.splitPosition), 1.0, accuracy: 0.0001)
        XCTAssertLessThan(TempoMath.splitPosition, 0.5 + 0.05)
        XCTAssertGreaterThan(TempoMath.splitPosition, 0.5)
    }

    func testSpeedAndPositionAreInverse() {
        for speed in stride(from: 0.25, through: 2.0, by: 0.05) {
            let roundTrip = TempoMath.speed(forPosition: TempoMath.position(forSpeed: speed))
            XCTAssertEqual(roundTrip, speed, accuracy: 0.0001)
        }
    }

    func testSpeedClampsOutOfRangePosition() {
        XCTAssertEqual(TempoMath.speed(forPosition: -1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(TempoMath.speed(forPosition: 2), 2.0, accuracy: 0.0001)
    }

    // MARK: automator step count

    func testAutomatorStepCountExact() {
        // 65 → 85 by 5 = 65,70,75,80,85 = 5 steps.
        XCTAssertEqual(TempoMath.automatorStepCount(startBPM: 65, stepBPM: 5, ceilingBPM: 85), 5)
    }

    func testAutomatorStepCountWithRemainder() {
        // 60 → 100 by 15 = 60,75,90,(105→capped) = 4 steps.
        XCTAssertEqual(TempoMath.automatorStepCount(startBPM: 60, stepBPM: 15, ceilingBPM: 100), 4)
    }

    func testAutomatorStepCountDegenerateInputs() {
        XCTAssertEqual(TempoMath.automatorStepCount(startBPM: 80, stepBPM: 0, ceilingBPM: 120), 1)
        XCTAssertEqual(TempoMath.automatorStepCount(startBPM: 120, stepBPM: 5, ceilingBPM: 100), 1)
    }
}