import XCTest
@testable import Pocket

/// The tempo a player can now **type** into the metronome's readout (`TypableTempo`, review note
/// 2026-08-17). The field hands whatever was typed straight to `setBPM` and then reads the stored
/// value back, so the guarantee it relies on is the engine's: a value outside `bpmRange` is clamped,
/// never rejected and never stored. Typing is the first way in that can name a number the range
/// doesn't contain — ±1, the slider and TAP could only ever land inside it — so the clamp is now
/// load-bearing rather than defensive.
@MainActor
final class MetronomeTempoEntryTests: XCTestCase {

    private let range = StandaloneMetronomeEngine.bpmRange   // 30...300

    func testTypedTempoAboveTheRangeClampsToTheCeiling() {
        let engine = StandaloneMetronomeEngine()

        engine.setBPM(999)

        XCTAssertEqual(engine.bpm, range.upperBound,
                       "a typed value above the range is clamped, so the field resyncs to the ceiling")
    }

    func testTypedTempoBelowTheRangeClampsToTheFloor() {
        let engine = StandaloneMetronomeEngine()

        engine.setBPM(0)

        XCTAssertEqual(engine.bpm, range.lowerBound,
                       "a typed 0 is clamped, not stored — a stopped metronome is `stop`, not 0 BPM")
    }

    func testTypedTempoInsideTheRangeIsTakenExactly() {
        let engine = StandaloneMetronomeEngine()

        engine.setBPM(138)

        XCTAssertEqual(engine.bpm, 138, "the jump typing exists for: 96 to 138 without 42 taps")
    }

    /// The typed path is the same manual path as the steppers, so it must re-base an armed ramp on
    /// the new floor rather than leaving the automator climbing from a tempo no longer on screen.
    func testTypedTempoReBasesAnArmedRamp() {
        let engine = StandaloneMetronomeEngine()
        engine.setBPM(90)
        engine.setAutomatorMode(.bars)
        XCTAssertEqual(engine.automatorStartBPM, 90)

        engine.setBPM(138)

        XCTAssertEqual(engine.automatorStartBPM, 138, "typing re-bases the ramp exactly as a stepper does")
        XCTAssertEqual(engine.automatorMode, .bars, "and leaves it armed")
    }
}
