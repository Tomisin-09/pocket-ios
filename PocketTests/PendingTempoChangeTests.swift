import XCTest
@testable import Pocket

/// The tempo-change warning's pure derivation (ADR 0131): what boundary a running ramp is approaching,
/// how far away it is, and whether that is close enough to warn about. Exercised as plain values — no
/// engine, no UI — because this is boundary arithmetic, the logic that breaks silently (AGENTS.md).
final class PendingTempoChangeTests: XCTestCase {

    private func ramp(working: Int = 80, command: Int = 100, target: Int = 106,
                      step: Int = 5, interval: Int = 4, unit: MetronomeIntervalUnit = .bars,
                      dwell: Int = 4, backoff: Bool = true) -> CommandRamp {
        CommandRamp(working: working, command: command, target: target, stepBPM: step,
                    intervalCount: interval, unit: unit, dwellIntervals: dwell,
                    includeBackoff: backoff)
    }

    // MARK: - CommandRamp: which boundary, and how far

    /// Plateaus for the default ramp are 80,85,90,95 (1 interval each), 100 (4), 106 (1), 94 (1),
    /// at 4 bars per interval — so the first boundary is at bar 4.
    func testReportsTheNextPlateauAndItsDistance() {
        let change = ramp().pendingChange(elapsedBars: 1, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 80)
        XCTAssertEqual(change?.to, 85)
        XCTAssertEqual(change?.unitsRemaining, 3)        // boundary at bar 4
        XCTAssertEqual(change?.plateauUnits, 4)
        XCTAssertTrue(change?.isRise == true)
    }

    /// The dwell is four intervals, so its boundary is sixteen bars from where it starts (bar 16 → 32).
    func testDwellReportsItsFullLengthNotOneInterval() {
        let change = ramp().pendingChange(elapsedBars: 17, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 100)
        XCTAssertEqual(change?.to, 106)
        XCTAssertEqual(change?.plateauUnits, 16)         // 4 intervals × 4 bars
        XCTAssertEqual(change?.unitsRemaining, 15)       // boundary at bar 32
    }

    /// A drop reads as a drop — the backoff must warn too, or the session's last step is the one
    /// surprise left in it.
    func testBackoffIsNotARise() {
        let change = ramp().pendingChange(elapsedBars: 33, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 106)
        XCTAssertEqual(change?.to, 94)
        XCTAssertFalse(change?.isRise == true)
    }

    /// The end of the ramp is a boundary like any other, reported with no destination (ADR 0131 §4).
    func testRampEndReportsNilDestination() {
        let change = ramp().pendingChange(elapsedBars: 37, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 94)
        XCTAssertNil(change?.to)
        XCTAssertFalse(change?.isRise == true)
        XCTAssertEqual(change?.caption, "Last bar")
    }

    /// Past the end there is nothing left to approach.
    func testFinishedRampHasNoPendingChange() {
        XCTAssertNil(ramp().pendingChange(elapsedBars: 40, elapsedSeconds: 0))
    }

    func testSecondsKeyedRampMeasuresInSeconds() {
        let change = ramp(interval: 30, unit: .seconds).pendingChange(elapsedBars: 0,
                                                                     elapsedSeconds: 10)
        XCTAssertEqual(change?.from, 80)
        XCTAssertEqual(change?.to, 85)
        XCTAssertEqual(change?.unitsRemaining, 20)
        XCTAssertEqual(change?.unit, .seconds)
    }

    /// A single-plateau ramp still reports its own end rather than nothing at all.
    func testSinglePlateauRampWarnsOfItsEnd() {
        let flat = CommandRamp(working: 100, command: 100, target: 100, stepBPM: 0,
                               intervalCount: 4, unit: .bars, dwellIntervals: 1,
                               includeBackoff: false)
        let change = flat.pendingChange(elapsedBars: 1, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 100)
        XCTAssertNil(change?.to)
    }

    // MARK: - The window, and the half-plateau clamp (§2)

    /// A bar-keyed ramp warns for the final bar of a four-bar plateau — a quarter of it.
    func testWindowIsOneBarOnABarKeyedRamp() {
        let cmd = ramp()
        XCTAssertFalse(cmd.pendingChange(elapsedBars: 2.5, elapsedSeconds: 0)?
            .isArmed(bpm: 100, beatsPerBar: 4) == true)
        XCTAssertTrue(cmd.pendingChange(elapsedBars: 3.2, elapsedSeconds: 0)?
            .isArmed(bpm: 100, beatsPerBar: 4) == true)
    }

    /// **The clamp that stops the feature being permanently lit.** With one bar per interval, an
    /// unclamped one-bar window would cover a one-interval plateau entirely — the warning would never
    /// turn off. Clamped to half the plateau it arms only in the back half of the bar.
    func testWindowNeverExceedsHalfThePlateau() {
        let tight = ramp(interval: 1)
        let atStart = tight.pendingChange(elapsedBars: 0.1, elapsedSeconds: 0)
        let pastHalf = tight.pendingChange(elapsedBars: 0.6, elapsedSeconds: 0)
        XCTAssertEqual(atStart?.window(bpm: 100, beatsPerBar: 4), 0.5)
        XCTAssertFalse(atStart?.isArmed(bpm: 100, beatsPerBar: 4) == true)
        XCTAssertTrue(pastHalf?.isArmed(bpm: 100, beatsPerBar: 4) == true)
    }

    /// One bar in *seconds* scales with the tempo and the meter — the reason the window isn't a fixed
    /// number of seconds. 4/4 at 60 BPM is four seconds; at 120 it's two.
    func testSecondsWindowScalesWithTempoAndMeter() throws {
        let change = try XCTUnwrap(ramp(interval: 30, unit: .seconds)
            .pendingChange(elapsedBars: 0, elapsedSeconds: 1))
        XCTAssertEqual(change.window(bpm: 60, beatsPerBar: 4), 4, accuracy: 0.001)
        XCTAssertEqual(change.window(bpm: 120, beatsPerBar: 4), 2, accuracy: 0.001)
        XCTAssertEqual(change.window(bpm: 60, beatsPerBar: 3), 3, accuracy: 0.001)
    }

    /// A loop ramp counts whole **passes**, so a one-pass plateau's clamped window is half a pass —
    /// unreachable from an integer rep count. Those plateaus therefore stay quiet rather than lighting
    /// permanently, which is the safe way for the deferred §7 to be unbuilt.
    func testLoopSinglePassPlateausStayQuiet() {
        let loop = LoopCommandRamp.make(working: 0.7, command: 0.9, target: 1.0, warmupSteps: 1)
        for reps in [0, 1, 6, 7] {                      // warm-up ×2, summit, backoff
            let change = loop.pendingChange(elapsedBars: Double(reps), elapsedSeconds: 0)
            XCTAssertFalse(change?.isArmed(bpm: 100, beatsPerBar: 4) == true,
                           "a one-pass plateau should not arm from a whole-pass count (rep \(reps))")
        }
    }

    /// The loop **dwell** is four passes, so its window is a whole pass and it does warn — on the last
    /// one. Pinned because it is the one place a loop ramp currently speaks.
    func testLoopDwellWarnsOnItsFinalPass() {
        let loop = LoopCommandRamp.make(working: 0.7, command: 0.9, target: 1.0, warmupSteps: 1)
        XCTAssertFalse(loop.pendingChange(elapsedBars: 4, elapsedSeconds: 0)?
            .isArmed(bpm: 100, beatsPerBar: 4) == true)
        XCTAssertTrue(loop.pendingChange(elapsedBars: 5, elapsedSeconds: 0)?
            .isArmed(bpm: 100, beatsPerBar: 4) == true)
    }

    // MARK: - Captions (the accessible carrier, §3a)

    func testCaptionNamesTheDirectionAndDestination() {
        XCTAssertEqual(ramp().pendingChange(elapsedBars: 1, elapsedSeconds: 0)?.caption,
                       "Speeding up to 85")
        XCTAssertEqual(ramp().pendingChange(elapsedBars: 33, elapsedSeconds: 0)?.caption,
                       "Backing off to 94")
    }

    // MARK: - MetronomeAutomator (the free-play linear ramp)

    private func linear(start: Int = 90, ceiling: Int = 105, step: Int = 5,
                        interval: Int = 4, unit: MetronomeIntervalUnit = .bars,
                        enabled: Bool = true) -> MetronomeAutomator {
        MetronomeAutomator(enabled: enabled, startBPM: start, stepBPM: step,
                           intervalCount: interval, unit: unit, ceilingBPM: ceiling)
    }

    func testLinearRampReportsItsNextStep() {
        let change = linear().pendingChange(elapsedBars: 1, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 90)
        XCTAssertEqual(change?.to, 95)
        XCTAssertEqual(change?.unitsRemaining, 3)
        XCTAssertEqual(change?.plateauUnits, 4)
    }

    /// The ceiling plateau holds for one interval and then the ramp is finished, so its boundary is
    /// the end of the climb and carries no destination.
    func testLinearRampCeilingWarnsOfTheEnd() {
        let change = linear().pendingChange(elapsedBars: 13, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 105)
        XCTAssertNil(change?.to)
    }

    func testLinearRampPastTheCeilingHasNothingPending() {
        XCTAssertNil(linear().pendingChange(elapsedBars: 17, elapsedSeconds: 0))
    }

    /// A slow-down ramp reports a fall, and never overshoots below its ceiling.
    func testLinearSlowDownIsNotARise() {
        let change = linear(start: 120, ceiling: 100).pendingChange(elapsedBars: 1, elapsedSeconds: 0)
        XCTAssertEqual(change?.from, 120)
        XCTAssertEqual(change?.to, 115)
        XCTAssertFalse(change?.isRise == true)
    }

    func testDisabledOrFlatRampHasNothingPending() {
        XCTAssertNil(linear(enabled: false).pendingChange(elapsedBars: 1, elapsedSeconds: 0))
        XCTAssertNil(linear(start: 100, ceiling: 100).pendingChange(elapsedBars: 1, elapsedSeconds: 0))
        XCTAssertNil(linear(step: 0).pendingChange(elapsedBars: 1, elapsedSeconds: 0))
    }

    // MARK: - The setting

    func testWarningSettingDefaultsToShowAndFallsBackSafely() {
        XCTAssertEqual(AppSettings.resolvedTempoWarning(storedValue: nil), .show)
        XCTAssertEqual(AppSettings.resolvedTempoWarning(storedValue: "off"), .off)
        XCTAssertEqual(AppSettings.resolvedTempoWarning(storedValue: "show"), .show)
        // The deferred `sound` mode (§5/§6) degrades to showing the warning, never to silence.
        XCTAssertEqual(AppSettings.resolvedTempoWarning(storedValue: "sound"), .show)
        XCTAssertEqual(AppSettings.resolvedTempoWarning(storedValue: "nonsense"), .show)
    }
}
