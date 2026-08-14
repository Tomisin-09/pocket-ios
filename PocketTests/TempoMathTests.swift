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
        // The ceiling came down to 1.5× with ADR 0124 — one axis for the slider, the automator
        // ramp and every percent field, so this constant is the single place it moves.
        XCTAssertEqual(TempoMath.speed(forPosition: 1), 1.5, accuracy: 0.0001)
        XCTAssertEqual(TempoMath.maxSpeed, 1.5, accuracy: 0.0001)
    }

    func testSplitPositionIsFullSpeed() {
        // 1.0× sits at the asymmetric split, left of centre.
        XCTAssertEqual(TempoMath.speed(forPosition: TempoMath.splitPosition), 1.0, accuracy: 0.0001)
        XCTAssertLessThan(TempoMath.splitPosition, 0.5 + 0.05)
        XCTAssertGreaterThan(TempoMath.splitPosition, 0.5)
    }

    func testSpeedAndPositionAreInverse() {
        for speed in stride(from: TempoMath.minSpeed, through: TempoMath.maxSpeed, by: 0.05) {
            let roundTrip = TempoMath.speed(forPosition: TempoMath.position(forSpeed: speed))
            XCTAssertEqual(roundTrip, speed, accuracy: 0.0001)
        }
    }

    func testSpeedClampsOutOfRangePosition() {
        XCTAssertEqual(TempoMath.speed(forPosition: -1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(TempoMath.speed(forPosition: 2), 1.5, accuracy: 0.0001)
    }

    // MARK: speed clamp + custom entry (ADR 0124)

    func testClampedSpeedHoldsTheAxisEnds() {
        XCTAssertEqual(TempoMath.clamped(speed: 0.9), 0.9, accuracy: 1e-9)
        XCTAssertEqual(TempoMath.clamped(speed: TempoMath.minSpeed), TempoMath.minSpeed, accuracy: 1e-9)
        XCTAssertEqual(TempoMath.clamped(speed: TempoMath.maxSpeed), TempoMath.maxSpeed, accuracy: 1e-9)
    }

    func testClampedSpeedPullsALegacyValueOntoTheAxis() {
        // A loop authored under the old 2.0× ceiling must not hand the engine a rate the slider
        // can no longer reach — the read-side guard, since nothing was rewritten in storage.
        XCTAssertEqual(TempoMath.clamped(speed: 2.0), 1.5, accuracy: 1e-9)
        XCTAssertEqual(TempoMath.clamped(speed: 0.1), 0.25, accuracy: 1e-9)
    }

    func testSpeedEntryAcceptsPlainAndDecoratedNumbers() {
        XCTAssertEqual(TempoMath.parse(speedEntry: "0.85"), .valid(0.85))
        XCTAssertEqual(TempoMath.parse(speedEntry: " 1.25× "), .valid(1.25))
        XCTAssertEqual(TempoMath.parse(speedEntry: "1.25x"), .valid(1.25))
        XCTAssertEqual(TempoMath.parse(speedEntry: "0,75"), .valid(0.75))   // comma decimal separator
    }

    func testSpeedEntryNamesOutOfRangeRatherThanClamping() {
        // Silently accepting 1.5 for a typed 2 would read as the field eating the keystrokes.
        XCTAssertEqual(TempoMath.parse(speedEntry: "2"), .outOfRange)
        XCTAssertEqual(TempoMath.parse(speedEntry: "0.1"), .outOfRange)
        XCTAssertEqual(TempoMath.parse(speedEntry: "1.5"), .valid(1.5))     // the boundary is inclusive
    }

    func testSpeedEntryRejectsNonNumbers() {
        XCTAssertEqual(TempoMath.parse(speedEntry: ""), .notANumber)
        XCTAssertEqual(TempoMath.parse(speedEntry: "fast"), .notANumber)
        XCTAssertEqual(TempoMath.parse(speedEntry: "×"), .notANumber)
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

    // MARK: tap tempo — trailing window and outlier rejection (ADR 0166)

    /// Tap timestamps whose successive gaps are `gaps`, starting at 0 — the tests below are
    /// all written in terms of gaps, since that is what the reading is actually taken from.
    private func taps(gaps: [TimeInterval]) -> [TimeInterval] {
        var times: [TimeInterval] = [0]
        var clock: TimeInterval = 0
        for gap in gaps {
            clock += gap
            times.append(clock)
        }
        return times
    }

    func testTapTempoWindowReadsTheEndOfTheRunNotItsMean() {
        // A passage that drifts 89 → 93 BPM. The old all-gaps mean landed between the two
        // and fitted neither end of it; the window reads where the tapping finished.
        let gaps = Array(repeating: 60.0 / 89.0, count: 20)
            + Array(repeating: 60.0 / 93.0, count: TempoMath.tapWindow)
        let times = taps(gaps: gaps)

        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0, 93, accuracy: 1e-6)

        // The behaviour this replaced, kept explicit so the difference can't quietly vanish.
        let everyGap = TempoMath.bpm(fromTapTimes: times, window: 0) ?? 0
        XCTAssertGreaterThan(everyGap, 89)
        XCTAssertLessThan(everyGap, 91)
    }

    func testTapTempoReconvergesAfterALongSteadyRun() {
        // The old mean froze: with 40 gaps banked a new tap moved it by a fortieth, so
        // "keep tapping until it settles" never settled. The window turns over instead.
        let steady = Array(repeating: 0.6, count: 40)                       // 100 BPM
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: steady)) ?? 0, 100, accuracy: 1e-6)

        let shifted = steady + Array(repeating: 0.5, count: TempoMath.tapWindow + 1)   // 120 BPM
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: shifted)) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoWindowDropsTheGapBeyondIt() {
        // A 0.55 s opening gap — inside the tolerance band around the 0.5 s median, so it
        // survives rejection and this isolates the window itself. With `tapWindow` clean
        // gaps after it, the opener sits one place past the edge and is not read.
        let gaps = [0.55] + Array(repeating: 0.5, count: TempoMath.tapWindow)
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0, 120, accuracy: 1e-6)

        // One fewer clean gap and the opener is inside the window, pulling the mean down.
        let narrower = Array(gaps.dropLast())
        let mean = narrower.reduce(0, +) / Double(narrower.count)
        let reading = TempoMath.bpm(fromTapTimes: taps(gaps: narrower)) ?? 0
        XCTAssertEqual(reading, 60.0 / mean, accuracy: 1e-6)
        XCTAssertLessThan(reading, 120)                 // direction, not just the arithmetic
    }

    func testTapTempoAbsorbsAnEarlyTapWhenBothHalvesAreInTheWindow() {
        // The device symptom that widened `tapWindow` (ADR 0166 §Revision). A mistimed tap
        // is a *paired* error — early by 0.06 s shortens one gap and lengthens the next by
        // the same 0.06 — so the two cancel in the mean and the reading doesn't move. That
        // only holds while both halves are inside the window; at the old width one half
        // rolled out and the survivor showed. Both are inside the tolerance band, so this
        // is cancellation doing the work, not rejection.
        let gaps = Array(repeating: 0.5, count: 5)
            + [0.44, 0.56]
            + Array(repeating: 0.5, count: TempoMath.tapWindow - 7)
        XCTAssertEqual(gaps.count, TempoMath.tapWindow)
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoRejectsADoubleTap() {
        // One stray extra tap splits a gap in half. Both halves sit 50% from the median and
        // are dropped — without rejection the window would hand them ¼ of the reading.
        let gaps: [TimeInterval] = [0.5, 0.5, 0.5, 0.25, 0.25, 0.5, 0.5, 0.5]
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoRejectsAMissedBeat() {
        // A skipped tap doubles one gap — the other classic tapping error.
        let gaps: [TimeInterval] = [0.5, 0.5, 0.5, 1.0, 0.5, 0.5, 0.5, 0.5]
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0, 120, accuracy: 1e-6)
    }

    func testTapTempoKeepsGenuineDrift() {
        // 89 → 93 BPM across one window is ~4.5% — real movement, not a fumble. Every gap
        // must survive, or the tolerance is flattening the drift it exists to follow.
        let gaps = (0..<TempoMath.tapWindow).map { step -> TimeInterval in
            let fraction = Double(step) / Double(TempoMath.tapWindow - 1)
            return 60.0 / (89.0 + 4.0 * fraction)
        }
        let mean = gaps.reduce(0, +) / Double(gaps.count)
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0,
                       60.0 / mean, accuracy: 1e-6)
    }

    func testTapTempoKeepsEveryGapBelowTheRejectionFloor() {
        // Three gaps is below the floor: there is no majority to be an outlier *from*, so
        // even a wild gap is averaged rather than discarded.
        XCTAssertEqual(TempoMath.minGapsForOutlierRejection, 4)
        let gaps: [TimeInterval] = [0.5, 0.5, 1.4]                          // mean 0.8
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: taps(gaps: gaps)) ?? 0,
                       60.0 / 0.8, accuracy: 1e-6)
    }

    func testTapTempoWindowArgumentIsHonoured() {
        // `window: 0` keeps the unwindowed mean expressible — on genuinely steady material
        // more samples is the better estimator, and the ADR trades that away deliberately.
        // Every gap here is inside the tolerance band, so only the window separates the two.
        let gaps = Array(repeating: 0.5, count: 20) + Array(repeating: 0.55, count: 4)
        let times = taps(gaps: gaps)

        let recent = Array(gaps.suffix(TempoMath.tapWindow))
        let windowedMean = recent.reduce(0, +) / Double(recent.count)
        let everyGapMean = gaps.reduce(0, +) / Double(gaps.count)
        XCTAssertNotEqual(windowedMean, everyGapMean, accuracy: 1e-4)       // the fixture bites

        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times) ?? 0,
                       60.0 / windowedMean, accuracy: 1e-6)
        XCTAssertEqual(TempoMath.bpm(fromTapTimes: times, window: 0) ?? 0,
                       60.0 / everyGapMean, accuracy: 1e-6)
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
