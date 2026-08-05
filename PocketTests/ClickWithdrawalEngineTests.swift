import XCTest
@testable import Pocket

/// The click withdrawal where it meets the engine (ADR 0132 §4, §8): the three exclusions, the origin
/// capture, and `scheduledLevel`'s **precedence chain**.
///
/// That chain is now `count-in > warning > withdrawal > strum pattern > meter` with four writers on
/// one channel, and ADR 0131 already flagged that reading order is no longer a safe way to know what
/// wins — so the order is asserted here rather than inferred from the source. Runs stopped: no audio
/// is started, only the scheduling decision is exercised.
@MainActor
final class ClickWithdrawalEngineTests: XCTestCase {

    /// Run `body` with the stored withdrawal tier pinned, restoring whatever was there before —
    /// `AppSettings.clickWithdrawal` reads `UserDefaults.standard`, which is shared across the suite.
    private func withWithdrawal(_ value: ClickWithdrawal, _ body: () -> Void) {
        let key = AppSettings.Key.clickWithdrawal
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(value.rawValue, forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        body()
    }

    /// An engine standing in for the free-play metronome tool: the one host that opts in.
    private func metronomeTool() -> StandaloneMetronomeEngine {
        let engine = StandaloneMetronomeEngine()      // 4/4, no subdivision ⇒ one tick a beat
        engine.allowsClickWithdrawal = true
        return engine
    }

    // MARK: the exclusions (§4, as amended)

    /// Withdrawal is opt-in per host, so every other screen driving this engine — every exercise run,
    /// every routine block — keeps its click whatever the stored tier says.
    func testAnyOtherHostKeepsItsClick() {
        withWithdrawal(.deep) {
            let engine = StandaloneMetronomeEngine()   // no opt-in
            XCTAssertEqual(engine.activeWithdrawal, .off)
            XCTAssertEqual(engine.scheduledLevel(forTick: 16, ticksPerBeat: 1), .accent,
                           "a bar deep would have silenced still sounds off the metronome tool")
        }
    }

    /// The click withdraws when it is a **steady** click: arming and starting the free-play automator
    /// suspends it for the climb.
    func testARunningRampSuspendsWithdrawal() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            XCTAssertEqual(engine.activeWithdrawal, .deep, "steady click — the tier applies")

            engine.setAutomatorMode(.bars)
            XCTAssertEqual(engine.activeWithdrawal, .deep, "arming alone doesn't climb (ADR 0048)")

            engine.automatorRunning = true
            XCTAssertEqual(engine.activeWithdrawal, .off, "a live climb suspends it")
        }
    }

    /// The withdrawal/strum edge is **mutually exclusive rather than ordered** (§4): an armed pattern
    /// excludes withdrawal, so a bar the cycle would have silenced still plays its slots.
    func testAnArmedStrumPatternKeepsItsRhythm() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            engine.strumSchedule = .init(levels: [.accent, nil, .beat, nil], ticksPerBeat: 1)

            XCTAssertEqual(engine.activeWithdrawal, .off,
                           "a strum pattern's rhythm is the lesson, not the scaffolding")
            XCTAssertEqual(engine.scheduledLevel(forTick: 16, ticksPerBeat: 1), .accent,
                           "a bar deep would have silenced still plays the pattern")
            XCTAssertNil(engine.scheduledLevel(forTick: 17, ticksPerBeat: 1),
                         "the pattern's own rest, not a withdrawal")
        }
    }

    // MARK: precedence

    /// Withdrawal outranks the meter: a silenced bar schedules nothing even though the meter would
    /// have accented its downbeat.
    func testWithdrawalOutranksTheMeterDefault() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()

            XCTAssertEqual(engine.scheduledLevel(forTick: 0, ticksPerBeat: 1), .accent,
                           "bar 0 is full, so the meter still decides")
            XCTAssertEqual(engine.scheduledLevel(forTick: 8, ticksPerBeat: 1), .accent,
                           "bar 2 is downbeat-only — beat 1 sounds, at accent")
            XCTAssertNil(engine.scheduledLevel(forTick: 9, ticksPerBeat: 1),
                         "…and nothing else in that bar does")
            XCTAssertNil(engine.scheduledLevel(forTick: 16, ticksPerBeat: 1),
                         "bar 4 is silent under deep")
        }
    }

    // MARK: the captured origin (§8)

    func testTheCycleStartsAtThePhaseAnchorWhenEligibleFromTheStart() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            XCTAssertEqual(engine.captureDrillOrigin(eligibleAt: 0, ticksPerBeat: 1), 0)
            XCTAssertEqual(engine.drillOriginTick, 0)
        }
    }

    /// Becoming eligible mid-bar must not offset the cycle from the meter — bar 0 waits for the next
    /// downbeat. This is the switched-on-mid-run and the ramp-just-stopped case.
    func testBecomingEligibleMidBarWaitsForTheNextDownbeat() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            XCTAssertEqual(engine.captureDrillOrigin(eligibleAt: 13, ticksPerBeat: 1), 16)
        }
    }

    /// An excluded run **drops** the origin rather than freezing it, so a suspended cycle restarts at
    /// bars 1–2 full instead of resuming wherever the tick counter got to.
    func testAnExcludedRunDropsTheOrigin() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            _ = engine.scheduledLevel(forTick: 0, ticksPerBeat: 1)
            XCTAssertEqual(engine.drillOriginTick, 0, "captured while eligible")

            engine.automatorRunning = true                     // a climb starts
            _ = engine.scheduledLevel(forTick: 4, ticksPerBeat: 1)
            XCTAssertNil(engine.drillOriginTick, "suspended ⇒ the cycle has no origin to carry")

            engine.automatorRunning = false                    // …and stops, mid-bar
            _ = engine.scheduledLevel(forTick: 21, ticksPerBeat: 1)
            XCTAssertEqual(engine.drillOriginTick, 24,
                           "the cycle restarts on the next downbeat, at bars 1–2 full")
        }
    }

    /// **Re-captured, never carried.** Carrying an origin across a re-anchor would place every later
    /// silent bar in the wrong spot — a defect that reads as "the feature feels wrong" rather than as
    /// a bug. Re-capturing restarts the cycle at bars 1–2 full, which is the right behaviour anyway:
    /// after a manual disruption you re-establish the pulse before withdrawing it again.
    func testAManualTempoChangeRestartsTheCycleFull() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            engine.captureDrillOrigin(eligibleAt: 0, ticksPerBeat: 1)
            XCTAssertNotNil(engine.drillOriginTick)

            // Stopped, `reanchorPhase` is a no-op, so drop the origin the way a live one would — the
            // assertion is that a dropped origin re-captures at the new grid's tick 0, not carries.
            engine.resetDrillOrigin()
            XCTAssertNil(engine.drillOriginTick)
            XCTAssertEqual(engine.captureDrillOrigin(eligibleAt: 0, ticksPerBeat: 1), 0)
        }
    }

    // MARK: the indicator's reading (§7)

    func testAStoppedEngineReportsAFullClick() {
        withWithdrawal(.deep) {
            let engine = metronomeTool()
            XCTAssertEqual(engine.heardWithdrawalLevel, .full,
                           "nothing is being heard, so the dots must not read as withdrawn")
        }
    }
}
