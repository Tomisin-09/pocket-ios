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

    // MARK: tap tempo (ADR 0024)

    func testTapTempoFromEvenTaps() {
        // Taps 0.5 s apart ⇒ 120 BPM.
        let times: [TimeInterval] = [0, 0.5, 1.0, 1.5, 2.0]
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoAveragesJitter() {
        // Slightly uneven taps average toward the true tempo (~100 BPM).
        let times: [TimeInterval] = [0, 0.58, 1.22, 1.80]   // gaps 0.58, 0.64, 0.58 → mean 0.6
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0, 100, accuracy: 1e-6)
    }

    func testTapTempoKeepsSubIntegerPrecision() {
        // Mean gap 0.4012 s ⇒ 149.55 BPM, which an Int would drift; Double keeps it.
        let times: [TimeInterval] = [0, 0.4012, 0.8024]
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0, 60.0 / 0.4012, accuracy: 1e-6)
    }

    func testTapTempoNeedsTwoTaps() {
        XCTAssertNil(TempoMath.bpm(fromTapTimes: []))
        XCTAssertNil(TempoMath.bpm(fromTapTimes: [1.0]))
    }

    func testTapTempoDiscardsLoopWrapStraddle() {
        // A tap that wraps the loop back to an earlier song position gives a
        // non-positive gap (1.5 → 0.2); that interval is dropped, leaving the two
        // clean 0.5 s gaps ⇒ 120 BPM.
        let times: [TimeInterval] = [0.5, 1.0, 1.5, 0.2, 0.7]   // gaps .5, .5, -1.3, .5
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoReturnsNilWhenNoUsableGap() {
        // Every gap non-positive (equal or descending timestamps) ⇒ unmeasurable.
        XCTAssertNil(TempoMath.bpm(fromTapTimes: [1.0, 1.0, 1.0]))
        XCTAssertNil(TempoMath.bpm(fromTapTimes: [2.0, 1.0]))
    }

    func testTapTempoClampsToMusicalRange() {
        // Very fast double-tap clamps to the ceiling; a very slow pair to the floor.
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: [0, 0.01]) ?? 0, TempoMath.maxTapBPM, accuracy: 1e-6)
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: [0, 10]) ?? 0, TempoMath.minTapBPM, accuracy: 1e-6)
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
