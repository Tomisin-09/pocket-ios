import XCTest
@testable import Pocket

/// The pure ramp-staircase duration estimator (V2 planner R3). Timing math that feeds the planner's
/// length readout + soft budget — it drifts silently, so it's unit-tested per AGENTS.md.
final class SessionEstimateTests: XCTestCase {

    // MARK: - Seconds-based ramp (already real time)

    func testSecondsRampIsIntervalsTimesCount() {
        // No warm-up climb (command == working), no summit/backoff → one dwell plateau of 5
        // intervals × 6 seconds each = 30s. Meter is irrelevant for a seconds ramp.
        let ramp = CommandRamp(working: 120, command: 120, target: 120, stepBPM: 0,
                               intervalCount: 6, unit: .seconds, dwellIntervals: 5,
                               includeBackoff: false)
        XCTAssertEqual(SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 4), 30, accuracy: 0.001)
        XCTAssertEqual(SessionEstimate.minutes(forRamp: ramp, beatsPerBar: 4), 1) // 30s rounds/floors to 1
    }

    // MARK: - Bars-based ramp (per-plateau tempo)

    func testBarsRampSinglePlateauConvertsAtItsTempo() {
        // One dwell plateau: 8 intervals × 2 bars = 16 bars at 120 BPM, 4/4.
        // secondsPerBar = 4 × 60 / 120 = 2s → 16 × 2 = 32s.
        let ramp = CommandRamp(working: 120, command: 120, target: 120, stepBPM: 0,
                               intervalCount: 2, unit: .bars, dwellIntervals: 8,
                               includeBackoff: false)
        XCTAssertEqual(SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 4), 32, accuracy: 0.001)
    }

    func testSlowerTempoTakesLongerThanFaster() {
        // Same shape, different tempo — the estimator must reflect that slow bars take longer.
        func ramp(bpm: Int) -> CommandRamp {
            CommandRamp(working: bpm, command: bpm, target: bpm, stepBPM: 0, intervalCount: 1,
                        unit: .bars, dwellIntervals: 4, includeBackoff: false)
        }
        let slow = SessionEstimate.seconds(forRamp: ramp(bpm: 60), beatsPerBar: 4)
        let fast = SessionEstimate.seconds(forRamp: ramp(bpm: 120), beatsPerBar: 4)
        XCTAssertGreaterThan(slow, fast)
        XCTAssertEqual(slow, fast * 2, accuracy: 0.001) // 60 BPM bars are exactly twice as long
    }

    func testWarmupPlateausUseTheirOwnSlowerTempo() {
        // Warm-up 60→120 in one 60-BPM step (working 60, command 120, stepBPM 60): plateaus are
        // [60 (1 interval), 120 (dwell 2 intervals)]. intervalCount 1 bar, 4/4.
        //   60-BPM bar = 4s (1 bar) ; 120-BPM bars = 2s each × 2 = 4s → total 8s.
        let ramp = CommandRamp(working: 60, command: 120, target: 120, stepBPM: 60,
                               intervalCount: 1, unit: .bars, dwellIntervals: 2,
                               includeBackoff: false)
        XCTAssertEqual(ramp.plateaus.map(\.bpm), [60, 120])
        XCTAssertEqual(SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 4), 8, accuracy: 0.001)
    }

    func testMeterScalesBarLength() {
        // A 6/8 bar has more beats than 4/4, so the same bar count takes longer.
        let ramp = CommandRamp(working: 120, command: 120, target: 120, stepBPM: 0, intervalCount: 1,
                               unit: .bars, dwellIntervals: 4, includeBackoff: false)
        let four = SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 4)
        let six = SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 6)
        XCTAssertEqual(six, four * 1.5, accuracy: 0.001)
    }

    // MARK: - Guards

    func testDegenerateInputsFloorSafely() {
        let ramp = CommandRamp(working: 120, command: 120, target: 120, stepBPM: 0, intervalCount: 0,
                               unit: .bars, dwellIntervals: 1, includeBackoff: false)
        // intervalCount 0 floors to 1; still yields a sane non-negative estimate and ≥1 minute.
        XCTAssertGreaterThanOrEqual(SessionEstimate.seconds(forRamp: ramp, beatsPerBar: 0), 0)
        XCTAssertGreaterThanOrEqual(SessionEstimate.minutes(forRamp: ramp, beatsPerBar: 0), 1)
    }

    func testMinutesFromSecondsFloorsAtOne() {
        XCTAssertEqual(SessionEstimate.minutes(fromSeconds: 0), 1)
        XCTAssertEqual(SessionEstimate.minutes(fromSeconds: 5), 1)
        XCTAssertEqual(SessionEstimate.minutes(fromSeconds: 90), 2) // 1.5 min rounds to 2
    }

    // MARK: - Reps multiplier

    func testRepsMultiplyPerRunEstimate() {
        XCTAssertEqual(SessionEstimate.minutes(perRun: 4, reps: 3), 12)
        XCTAssertEqual(SessionEstimate.minutes(perRun: 4, reps: 1), 4)
        XCTAssertEqual(SessionEstimate.minutes(perRun: 4, reps: 0), 4) // reps < 1 → single run
        XCTAssertEqual(SessionEstimate.minutes(perRun: 0, reps: 5), 1) // floored at 1
    }

    // MARK: - Soft budget fit

    func testFitOnTargetWithinTolerance() {
        // ±15% of 30 = 25.5…34.5 → 28 and 33 are on target, boundaries included.
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 30, targetMinutes: 30), .onTarget)
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 28, targetMinutes: 30), .onTarget)
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 34, targetMinutes: 30), .onTarget)
    }

    func testFitUnderAndOver() {
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 20, targetMinutes: 30), .under)
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 45, targetMinutes: 30), .over)
    }

    func testFitWithNoTargetReadsOnTarget() {
        XCTAssertEqual(SessionEstimate.fit(estimateMinutes: 99, targetMinutes: 0), .onTarget)
    }
}
