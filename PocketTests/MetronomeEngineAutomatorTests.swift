import XCTest
@testable import Pocket

/// Behaviour of the standalone metronome **engine**'s automator wiring (ADR 0043) — the
/// glue around the pure `MetronomeAutomator` (covered separately). Focus: a manual tempo
/// change **re-bases an armed ramp on the new floor** instead of switching it off, so the
/// panel never drops to "Off" just because you moved the tempo. Runs stopped — no audio is
/// started — so it exercises only the config wiring.
@MainActor
final class MetronomeEngineAutomatorTests: XCTestCase {

    func testChangingFloorReBasesArmedAutomatorInsteadOfTurningItOff() {
        let engine = StandaloneMetronomeEngine()
        engine.setBPM(90)
        engine.setAutomatorMode(.bars)
        XCTAssertEqual(engine.automatorMode, .bars)
        XCTAssertEqual(engine.automatorStartBPM, 90, "floor captured at the current tempo on arm")

        engine.setBPM(110)

        XCTAssertEqual(engine.automatorMode, .bars, "stays armed after a floor change")
        XCTAssertTrue(engine.automatorEnabled)
        XCTAssertEqual(engine.automatorStartBPM, 110, "ramp re-bases on the new floor")
    }

    func testChangingFloorLeavesAnOffAutomatorOff() {
        let engine = StandaloneMetronomeEngine()
        engine.setBPM(90)
        XCTAssertEqual(engine.automatorMode, .off)

        engine.setBPM(120)

        XCTAssertEqual(engine.automatorMode, .off, "a tempo change never arms the automator")
        XCTAssertFalse(engine.automatorEnabled)
    }

    func testNoOpTempoSetDoesNotResetAStartedRamp() {
        let engine = StandaloneMetronomeEngine()
        engine.setBPM(100)
        engine.setAutomatorMode(.bars)
        XCTAssertEqual(engine.automatorStartBPM, 100)

        // Setting the same BPM is a no-op — it must not re-base the floor / restart the climb.
        engine.setBPM(100)
        XCTAssertEqual(engine.automatorStartBPM, 100)
        XCTAssertEqual(engine.automatorMode, .bars)
    }
}
