import XCTest
@testable import Pocket

/// Pure standalone-automator stepping math (ADR 0043, slice 4). The ramp resolves the
/// current BPM from elapsed **bars** or elapsed **seconds**, so both units are pinned here
/// (AGENTS.md).
final class MetronomeAutomatorTests: XCTestCase {

    private func automator(enabled: Bool = true, start: Int = 80, step: Int = 5,
                           interval: Int = 4, unit: MetronomeIntervalUnit = .bars,
                           ceiling: Int = 120) -> MetronomeAutomator {
        MetronomeAutomator(enabled: enabled, startBPM: start, stepBPM: step,
                           intervalCount: interval, unit: unit, ceilingBPM: ceiling)
    }

    // MARK: bars unit

    func testBarsRampStepsEveryNBars() {
        let ramp = automator(start: 80, step: 5, interval: 4, unit: .bars, ceiling: 120)
        XCTAssertEqual(ramp.bpm(elapsedBars: 0, elapsedSeconds: 999), 80)   // seconds ignored in bars mode
        XCTAssertEqual(ramp.bpm(elapsedBars: 3, elapsedSeconds: 0), 80)     // still in the first plateau
        XCTAssertEqual(ramp.bpm(elapsedBars: 4, elapsedSeconds: 0), 85)     // first step at 4 bars
        XCTAssertEqual(ramp.bpm(elapsedBars: 8, elapsedSeconds: 0), 90)
    }

    // MARK: seconds unit

    func testSecondsRampStepsEveryNSeconds() {
        // The benchmark's "+10 bpm every 30 s".
        let ramp = automator(start: 100, step: 10, interval: 30, unit: .seconds, ceiling: 200)
        XCTAssertEqual(ramp.bpm(elapsedBars: 999, elapsedSeconds: 0), 100)  // bars ignored in seconds mode
        XCTAssertEqual(ramp.bpm(elapsedBars: 0, elapsedSeconds: 29.9), 100)
        XCTAssertEqual(ramp.bpm(elapsedBars: 0, elapsedSeconds: 30), 110)
        XCTAssertEqual(ramp.bpm(elapsedBars: 0, elapsedSeconds: 75), 120)   // 2 completed intervals
    }

    // MARK: ceiling

    func testHoldsAtCeiling() {
        let ramp = automator(start: 80, step: 5, interval: 4, unit: .bars, ceiling: 120)
        XCTAssertEqual(ramp.bpm(elapsedBars: 32, elapsedSeconds: 0), 120)   // exactly reaches ceiling
        XCTAssertEqual(ramp.bpm(elapsedBars: 1000, elapsedSeconds: 0), 120) // never overshoots
    }

    func testUnevenStepStillCapsAtCeiling() {
        // 80 → 100 in steps of 7: 80, 87, 94, 101→capped to 100.
        let ramp = automator(start: 80, step: 7, interval: 1, unit: .bars, ceiling: 100)
        XCTAssertEqual(ramp.bpm(elapsedBars: 2, elapsedSeconds: 0), 94)
        XCTAssertEqual(ramp.bpm(elapsedBars: 3, elapsedSeconds: 0), 100)    // 101 clamped
        XCTAssertEqual(ramp.bpm(elapsedBars: 9, elapsedSeconds: 0), 100)
    }

    // MARK: descending

    func testDescendingRampWhenCeilingBelowStart() {
        // A slow-down ramp: 120 → 90, −5 every 2 bars.
        let ramp = automator(start: 120, step: 5, interval: 2, unit: .bars, ceiling: 90)
        XCTAssertEqual(ramp.bpm(elapsedBars: 0, elapsedSeconds: 0), 120)
        XCTAssertEqual(ramp.bpm(elapsedBars: 2, elapsedSeconds: 0), 115)
        XCTAssertEqual(ramp.bpm(elapsedBars: 100, elapsedSeconds: 0), 90)   // floors at the ceiling
    }

    // MARK: guards

    func testDisabledStaysAtStart() {
        let ramp = automator(enabled: false, start: 80, ceiling: 120)
        XCTAssertEqual(ramp.bpm(elapsedBars: 100, elapsedSeconds: 100), 80)
    }

    func testNonPositiveStepOrIntervalIsFlat() {
        XCTAssertEqual(automator(step: 0).bpm(elapsedBars: 100, elapsedSeconds: 0), 80)
        XCTAssertEqual(automator(interval: 0).bpm(elapsedBars: 100, elapsedSeconds: 0), 80)
    }

    func testStartEqualsCeilingIsFlat() {
        XCTAssertEqual(automator(start: 100, ceiling: 100).bpm(elapsedBars: 100, elapsedSeconds: 0), 100)
    }

    func testNegativeElapsedClampsToStart() {
        XCTAssertEqual(automator().bpm(elapsedBars: -5, elapsedSeconds: -5), 80)
    }

    // MARK: derived

    func testStepsToCeiling() {
        XCTAssertEqual(automator(start: 80, step: 5, ceiling: 120).stepsToCeiling, 8)
        XCTAssertEqual(automator(start: 80, step: 7, ceiling: 100).stepsToCeiling, 3)   // ceil(20/7)
        XCTAssertEqual(automator(start: 100, ceiling: 100).stepsToCeiling, 0)
    }

    func testHasReachedCeiling() {
        let ramp = automator(start: 80, step: 5, interval: 4, unit: .bars, ceiling: 120)
        XCTAssertFalse(ramp.hasReachedCeiling(elapsedBars: 4, elapsedSeconds: 0))
        XCTAssertTrue(ramp.hasReachedCeiling(elapsedBars: 32, elapsedSeconds: 0))
    }

    // MARK: completion (auto-stop at the top of the climb, slice 7)

    func testCompletionIntervalIsCeilingPlateauHeldOneInterval() {
        // 80 → 120, +5 every 4 bars: 8 steps to the ceiling, finished after the 9th plateau.
        XCTAssertEqual(automator(start: 80, step: 5, interval: 4, ceiling: 120).completionInterval, 36)
        // Uneven: 80 → 100 step 7 = ceil(20/7)=3 steps, +1 plateau, ×4 bars.
        XCTAssertEqual(automator(start: 80, step: 7, interval: 4, ceiling: 100).completionInterval, 16)
    }

    func testCompletionIntervalIsNilForFlatRamp() {
        XCTAssertNil(automator(start: 100, ceiling: 100).completionInterval)
        XCTAssertNil(automator(enabled: false).completionInterval)
        XCTAssertNil(automator(step: 0).completionInterval)
    }

    func testIsFinishedOnlyAfterCeilingHeldFullInterval() {
        // 80 → 120, +5 every 4 bars: ceiling reached at 32 bars, finished at 36.
        let ramp = automator(start: 80, step: 5, interval: 4, unit: .bars, ceiling: 120)
        XCTAssertFalse(ramp.isFinished(elapsedBars: 32, elapsedSeconds: 0))   // just reached the top
        XCTAssertFalse(ramp.isFinished(elapsedBars: 35, elapsedSeconds: 0))
        XCTAssertTrue(ramp.isFinished(elapsedBars: 36, elapsedSeconds: 0))    // ceiling held one interval
    }

    func testIsFinishedHonoursTheUnit() {
        // Seconds-mode ramp ignores elapsed bars for completion.
        let ramp = automator(start: 100, step: 10, interval: 30, unit: .seconds, ceiling: 120)
        // 2 steps to ceiling (120), +1 plateau, ×30 s = 90 s.
        XCTAssertEqual(ramp.completionInterval, 90)
        XCTAssertFalse(ramp.isFinished(elapsedBars: 9999, elapsedSeconds: 89))
        XCTAssertTrue(ramp.isFinished(elapsedBars: 0, elapsedSeconds: 90))
    }
}
