import XCTest
@testable import Pocket

/// Loops inside the block model (ADR 0129, extended after the 2026-07-31 device pass).
///
/// Two gaps closed here. A loop block in a generated session was **allotted a slot and ignored it** —
/// `LoopRunView` never read `plannedMinutes` at all — and a loop's staircase showed the same
/// `working == command` collapse `Exercise.rampFloor` had already fixed: only command and reach
/// rendered, no warm-up and no back off, because `LoopCommandRamp.make(loop:)` took the raw `speed`.
final class LoopBlockFitTests: XCTestCase {

    /// A loop over a 2-minute song covering 10% of it — a 12-second region.
    private func loop(speed: Double, command: Double? = nil, dwell: Int = 4,
                      repsPerStep: Int = 1) -> Loop {
        let loop = Loop(name: "Chorus lick", start: 0.1, end: 0.2, speed: speed, repeats: 3)
        loop.song = Song(title: "Test", duration: 120,
                         ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        loop.commandTempo = command
        loop.rampDwellIntervals = dwell
        loop.rampRepsPerStep = repsPerStep
        return loop
    }

    // MARK: - The staircase actually climbs (the rampFloor collapse)

    func testAnUnmeasuredLoopDerivesAFloorBelowCommand() {
        let subject = loop(speed: 0.80)
        XCTAssertFalse(subject.hasMeasuredCommand)
        XCTAssertEqual(subject.command, 0.80, accuracy: 0.0001)
        XCTAssertEqual(subject.rampFloor, 0.65, accuracy: 0.0001)
        XCTAssertLessThan(subject.rampFloor, subject.command)
    }

    func testAMeasuredLoopKeepsItsOwnStoredFloorWhenItIsLower() {
        let subject = loop(speed: 0.60, command: 0.85)
        XCTAssertEqual(subject.rampFloor, 0.60, accuracy: 0.0001)
    }

    func testAMeasuredLoopWhoseSpeedCaughtUpIsHeldBelowCommand() {
        let subject = loop(speed: 0.85, command: 0.85)
        XCTAssertEqual(subject.rampFloor, 0.80, accuracy: 0.0001)
        XCTAssertLessThan(subject.rampFloor, subject.command)
    }

    func testTheFloorNeverFallsBelowThePlaybackFloor() {
        let subject = loop(speed: TempoMath.minSpeed)
        XCTAssertGreaterThanOrEqual(subject.rampFloor, TempoMath.minSpeed)
    }

    /// The user-visible symptom: only *command* and *reach* rendered on an un-measured loop's
    /// staircase — no warm-up bar to climb from and no back-off tail to land on.
    func testAnUnmeasuredLoopNowWarmsUpAndBacksOff() {
        let ramp = loop(speed: 0.80).ramp
        XCTAssertLessThan(ramp.working, ramp.command)
        XCTAssertGreaterThan(ramp.plateaus.count, 2)
        XCTAssertEqual(ramp.plateaus.first?.bpm, ramp.working)
        XCTAssertLessThan(ramp.plateaus.last?.bpm ?? 0, ramp.command)
    }

    // MARK: - Pricing a loop ramp (percent units, not BPM)

    func testAPassCostsMoreTheSlowerItIsPlayed() {
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: 12, percent: 100), 12, accuracy: 0.001)
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: 12, percent: 50), 24, accuracy: 0.001)
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: 12, percent: 80), 15, accuracy: 0.001)
    }

    func testDegeneratePassInputsAreZeroNotInfinite() {
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: 12, percent: 0), 0)
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: 0, percent: 85), 0)
        XCTAssertEqual(LoopEstimate.passSeconds(regionSeconds: -5, percent: 85), 0)
    }

    func testAFlatRampIsItsPassesTimesTheirCost() {
        // No climb, no summit, no back off: 4 dwell intervals × 2 passes each at 85% of a 12s region.
        let ramp = LoopCommandRamp.make(working: 0.85, command: 0.85, target: 0.85, warmupSteps: 0,
                                        dwellIntervals: 4, includeBackoff: false, repsPerStep: 2)
        XCTAssertEqual(ramp.plateaus.map(\.bpm), [85])
        XCTAssertEqual(LoopEstimate.seconds(forRamp: ramp, regionSeconds: 12),
                       8 * 12 * 100.0 / 85.0, accuracy: 0.001)
    }

    func testTheWarmUpPlateauIsPricedAtItsOwnSlowerSpeed() {
        let ramp = LoopCommandRamp.make(working: 0.50, command: 1.0, target: 1.0, warmupSteps: 0,
                                        dwellIntervals: 1, includeBackoff: false, repsPerStep: 1)
        XCTAssertEqual(ramp.plateaus.map(\.bpm), [50, 100])
        // One pass at 50% (20s) + one at 100% (10s) — a flat average would have said 2 × 10s.
        XCTAssertEqual(LoopEstimate.seconds(forRamp: ramp, regionSeconds: 10), 30, accuracy: 0.001)
    }

    // MARK: - Fitting a loop block to its allotment

    func testALoopRampStretchesItsDwellToFillTheBlock() {
        let ramp = loop(speed: 0.85, command: 0.85).ramp
        let fit = LoopEstimate.fitted(ramp, toMinutes: 3, regionSeconds: 12)
        XCTAssertGreaterThan(fit.dwellIntervals, ramp.dwellIntervals)
        // The staircase's shape is untouched — only the hold at command grows.
        XCTAssertEqual(fit.plateaus.map(\.bpm), ramp.plateaus.map(\.bpm))
        XCTAssertEqual(fit.working, ramp.working)
        XCTAssertEqual(fit.target, ramp.target)
    }

    func testALoopFitIsBoundedByItsAuthoredDwellToo() {
        let ramp = loop(speed: 0.85, command: 0.85, dwell: 4).ramp
        let fit = LoopEstimate.fitted(ramp, toMinutes: 30, regionSeconds: 12)
        XCTAssertEqual(fit.dwellIntervals, 10)   // 2.5 × 4, the shared `clampedDwell` bound
    }

    func testANonPositiveAllotmentLeavesTheLoopRampUntouched() {
        let ramp = loop(speed: 0.85, command: 0.85).ramp
        XCTAssertEqual(LoopEstimate.fitted(ramp, toMinutes: 0, regionSeconds: 12), ramp)
    }

    /// A region of zero seconds (an unresolved song) must not divide by zero or fit to nothing.
    func testAnEmptyRegionIsInert() {
        let ramp = loop(speed: 0.85, command: 0.85).ramp
        XCTAssertEqual(LoopEstimate.fitted(ramp, toMinutes: 5, regionSeconds: 0), ramp)
        XCTAssertEqual(LoopEstimate.minutes(forRamp: ramp, regionSeconds: 0), 1)
    }

    func testEffectiveMinutesReportWhatTheLoopWillActuallyPlay() {
        let subject = loop(speed: 0.85, command: 0.85)
        let asked = 30
        let effective = LoopEstimate.effectiveMinutes(forRamp: subject.ramp, plannedMinutes: asked,
                                                      regionSeconds: subject.regionSeconds)
        XCTAssertLessThan(effective, asked, "a bounded fit must not claim the whole allotment")
        XCTAssertEqual(effective,
                       LoopEstimate.minutes(forRamp: LoopEstimate.fitted(subject.ramp, toMinutes: asked,
                                                                          regionSeconds: 12),
                                            regionSeconds: 12))
    }

    func testTheRegionIsTheLoopsShareOfItsSong() {
        XCTAssertEqual(loop(speed: 0.85).regionSeconds, 12, accuracy: 0.001)
    }
}
