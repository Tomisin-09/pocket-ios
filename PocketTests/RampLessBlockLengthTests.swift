import XCTest
@testable import Pocket

/// **A block without a ramp still has a length** (ADR 0141).
///
/// Every rule here fails *silently* if it's wrong: a session that quietly misreports its own length,
/// a block that ends when the player expected it to run open-ended, or one that never ends when they
/// expected it to move on. Nothing throws, so it is asserted rather than eyeballed on a routine.
final class RampLessBlockLengthTests: XCTestCase {

    // MARK: - The three-way rule (L1 / L4 / L6)

    func testAnAllotmentIsUsedAsGiven() {
        XCTAssertEqual(RampLessBlockLength.minutes(plannedMinutes: 12, usesAuthoredLength: false,
                                                   fallback: 5), 12)
    }

    func testDecliningTheFitRunsOpenEnded() {
        // ADR 0141 L4, the load-bearing property: ADR 0104 / 0135's open-ended block survives exactly,
        // as a choice rather than as the only option.
        XCTAssertNil(RampLessBlockLength.minutes(plannedMinutes: 12, usesAuthoredLength: true,
                                                  fallback: 5))
        XCTAssertNil(RampLessBlockLength.minutes(plannedMinutes: nil, usesAuthoredLength: true,
                                                  fallback: 5))
    }

    func testAHandAuthoredBlockTakesItsModesDefault() {
        // No session ever sized it, and it did *not* decline anything — the two `nil` cases that
        // `effectivePlannedMinutes` folds together and this rule has to keep apart.
        XCTAssertEqual(RampLessBlockLength.minutes(plannedMinutes: nil, usesAuthoredLength: false,
                                                   fallback: 5), 5)
    }

    func testNoAllotmentAndNoDefaultIsOpenEnded() {
        XCTAssertNil(RampLessBlockLength.minutes(plannedMinutes: nil, usesAuthoredLength: false,
                                                  fallback: nil))
    }

    func testANonPositiveLengthIsOpenEndedRatherThanInstant() {
        // A zero-minute block would otherwise finish the instant it appeared, which is not a length.
        XCTAssertNil(RampLessBlockLength.minutes(plannedMinutes: 0, usesAuthoredLength: false,
                                                  fallback: 5))
    }

    func testOnlyTheRampLessModesCarryADefault() {
        // The trainer prices itself from its staircase; handing it a default would be a second,
        // competing answer to the same question.
        XCTAssertNil(RampLessBlockLength.defaultMinutes(for: .trainer))
        XCTAssertEqual(RampLessBlockLength.defaultMinutes(for: .ear), RampLessBlockLength.earMinutes)
        XCTAssertEqual(RampLessBlockLength.defaultMinutes(for: .improvise),
                       RampLessBlockLength.improviseMinutes)
    }

    func testEarIsTheShorterDefault() {
        // L6's reasoning, asserted so a later tweak can't quietly invert it: internalising a phrase is
        // attention-dense, a jam needs a run-up.
        XCTAssertLessThan(RampLessBlockLength.earMinutes, RampLessBlockLength.improviseMinutes)
    }

    // MARK: - Ending on a region boundary (L2 — never cut a phrase)

    func testAnOpenEndedBlockNeverEndsOnItsOwn() {
        XCTAssertFalse(RampLessBlockLength.isUp(elapsed: 9_999, planned: nil))
        XCTAssertNil(RampLessBlockLength.remaining(elapsed: 10, planned: nil))
        XCTAssertNil(RampLessBlockLength.remainingLabel(elapsed: 10, planned: nil))
    }

    func testTheDeadlineRoundsUpToAWholeCycle() {
        // A 10-second region and a planned end 25 s after playback began: the block runs to 30 s, the
        // third boundary — never stopping 5 s into a phrase.
        let start = Date(timeIntervalSince1970: 1_000)
        let plannedEnd = start.addingTimeInterval(25)
        let deadline = RampLessBlockLength.finishTime(plannedEnd: plannedEnd, playbackStart: start,
                                                      cycleSeconds: 10)
        XCTAssertEqual(deadline.timeIntervalSince(start), 30, accuracy: 1e-9)
    }

    func testADeadlineAlreadyOnABoundaryDoesNotSlipAWholeCycle() {
        let start = Date(timeIntervalSince1970: 1_000)
        let deadline = RampLessBlockLength.finishTime(plannedEnd: start.addingTimeInterval(20),
                                                      playbackStart: start, cycleSeconds: 10)
        XCTAssertEqual(deadline.timeIntervalSince(start), 20, accuracy: 1e-9)
    }

    func testSilenceHasNoPhraseToProtect() {
        // Nothing sounding, or a region of no length: the planned end stands, with no rounding.
        let start = Date(timeIntervalSince1970: 1_000)
        let plannedEnd = start.addingTimeInterval(25)
        XCTAssertEqual(RampLessBlockLength.finishTime(plannedEnd: plannedEnd, playbackStart: nil,
                                                      cycleSeconds: 10), plannedEnd)
        XCTAssertEqual(RampLessBlockLength.finishTime(plannedEnd: plannedEnd, playbackStart: start,
                                                      cycleSeconds: 0), plannedEnd)
    }

    func testPlaybackStartingAfterThePlannedEndDoesNotPushTheDeadlineBack() {
        // Guards the sign: a block whose time ran out while paused must not be extended by pressing
        // play, which naive rounding on a negative interval would do.
        let plannedEnd = Date(timeIntervalSince1970: 1_000)
        let deadline = RampLessBlockLength.finishTime(plannedEnd: plannedEnd,
                                                      playbackStart: plannedEnd.addingTimeInterval(5),
                                                      cycleSeconds: 10)
        XCTAssertEqual(deadline, plannedEnd)
    }

    func testASlowerTempoMakesALongerCycle() {
        // The rounding reads the *live* rate, so slowing a loop down mid-block lengthens the phrase
        // the block waits out.
        XCTAssertEqual(RampLessBlockLength.cycleSeconds(regionSeconds: 10, percent: 100), 10,
                       accuracy: 1e-9)
        XCTAssertEqual(RampLessBlockLength.cycleSeconds(regionSeconds: 10, percent: 50), 20,
                       accuracy: 1e-9)
        XCTAssertEqual(RampLessBlockLength.cycleSeconds(regionSeconds: 0, percent: 100), 0)
        XCTAssertEqual(RampLessBlockLength.cycleSeconds(regionSeconds: 10, percent: 0), 0)
    }

    // MARK: - The readout (L3 — a mirror, not an arcade)

    func testTheReadoutCountsDownAndFloorsAtZero() {
        XCTAssertEqual(RampLessBlockLength.remainingLabel(elapsed: 0, planned: 300), "5:00 left")
        XCTAssertEqual(RampLessBlockLength.remainingLabel(elapsed: 271, planned: 300), "0:29 left")
        XCTAssertEqual(RampLessBlockLength.remainingLabel(elapsed: 300, planned: 300), "0:00 left")
        // Overrun while the last phrase plays out reads as zero, never as a negative or a count-up.
        XCTAssertEqual(RampLessBlockLength.remainingLabel(elapsed: 340, planned: 300), "0:00 left")
    }
}
