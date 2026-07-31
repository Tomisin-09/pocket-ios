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

    // MARK: - Fitting a ramp to a block (ADR 0129)

    /// The staircase a default, never-promoted exercise now runs: floor 68 → command 80, reach 85,
    /// backoff 75, stepping every 4 bars in 4/4. Priced per plateau at 240/bpm seconds a bar:
    /// 14.118 + 13.151 + 12.308 + [12.0 per dwell interval] + 11.294 + 12.8 — so everything that
    /// isn't dwell costs **63.670s**, and one dwell interval costs **12.0s**.
    private func freshRamp() -> CommandRamp {
        CommandRamp(working: 68, command: 80, target: 85, stepBPM: 5, intervalCount: 4,
                    unit: .bars, dwellIntervals: 4, includeBackoff: true)
    }

    func testDwellIntervalIsPricedAtTheCommandTempo() {
        // 4 bars × 4 beats × 60 / 80 BPM = 12s.
        XCTAssertEqual(SessionEstimate.dwellIntervalSeconds(freshRamp(), beatsPerBar: 4),
                       12.0, accuracy: 0.001)
    }

    func testFittedRampHitsItsTargetLength() {
        // (240s − 63.670s fixed) / 12s = 14.694 → 15 dwell intervals.
        let fit = SessionEstimate.fitted(freshRamp(), toMinutes: 4, beatsPerBar: 4)
        XCTAssertEqual(fit.dwellIntervals, 15)
        // 63.670 + 15 × 12 = 243.670s = 4.06 min.
        XCTAssertEqual(SessionEstimate.seconds(forRamp: fit, beatsPerBar: 4), 243.670, accuracy: 0.01)
        XCTAssertEqual(SessionEstimate.minutes(forRamp: fit, beatsPerBar: 4), 4)
    }

    func testFittedRampMovesTheDwellAndNothingElse() {
        let ramp = freshRamp()
        let fit = SessionEstimate.fitted(ramp, toMinutes: 4, beatsPerBar: 4)
        // Same staircase shape — only the command plateau's hold changes.
        XCTAssertEqual(fit.plateaus.map(\.bpm), ramp.plateaus.map(\.bpm))
        XCTAssertEqual(fit.plateaus.map(\.intervals), [1, 1, 1, 15, 1, 1])
        XCTAssertEqual(fit.working, ramp.working)
        XCTAssertEqual(fit.command, ramp.command)
        XCTAssertEqual(fit.target, ramp.target)
        XCTAssertEqual(fit.stepBPM, ramp.stepBPM)
        XCTAssertEqual(fit.intervalCount, ramp.intervalCount)
        XCTAssertEqual(fit.includeBackoff, ramp.includeBackoff)
    }

    func testTheDwellShareDominatesTheFittedBlock() {
        let fit = SessionEstimate.fitted(freshRamp(), toMinutes: 4, beatsPerBar: 4)
        let total = SessionEstimate.seconds(forRamp: fit, beatsPerBar: 4)
        let dwell = Double(fit.dwellIntervals) * SessionEstimate.dwellIntervalSeconds(fit, beatsPerBar: 4)
        // Emergent, not enforced (ADR 0129) — but consolidation must own the bulk of the block.
        XCTAssertGreaterThan(dwell / total, 0.65)
        XCTAssertLessThan(dwell / total, 0.80)
    }

    func testFittedDwellFloorsAtOneWhenTheSlotCannotHoldTheStaircase() {
        // 60s target against 63.670s of fixed plateaus ⇒ the arithmetic wants a negative dwell.
        let fit = SessionEstimate.fitted(freshRamp(), toMinutes: 1, beatsPerBar: 4)
        XCTAssertEqual(fit.dwellIntervals, 1)
    }

    func testFittedSecondsRampCountsIntervalsDirectly() {
        // No warm-up, no summit, no backoff → the dwell is the whole ramp: 120s / 6s = 20 intervals.
        let ramp = CommandRamp(working: 120, command: 120, target: 120, stepBPM: 0,
                               intervalCount: 6, unit: .seconds, dwellIntervals: 5,
                               includeBackoff: false)
        let fit = SessionEstimate.fitted(ramp, toMinutes: 2, beatsPerBar: 4)
        XCTAssertEqual(fit.dwellIntervals, 20)
        XCTAssertEqual(SessionEstimate.seconds(forRamp: fit, beatsPerBar: 4), 120, accuracy: 0.001)
    }

    func testNonPositiveMinutesLeavesTheRampUntouched() {
        let ramp = freshRamp()
        XCTAssertEqual(SessionEstimate.fitted(ramp, toMinutes: 0, beatsPerBar: 4), ramp)
        XCTAssertEqual(SessionEstimate.fitted(ramp, toMinutes: -5, beatsPerBar: 4), ramp)
    }
}
