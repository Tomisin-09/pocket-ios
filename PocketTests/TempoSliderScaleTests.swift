import XCTest
@testable import Pocket

/// The perceptual (log) tempo-slider mapping (ADR 0043). The whole point is that the
/// slider's midpoint reads as a *typical* tempo, so the geometric centre and the common-
/// range placement are pinned, along with the bounds, clamping and round-tripping
/// (AGENTS.md — slider mapping is pure logic that breaks silently).
final class TempoSliderScaleTests: XCTestCase {

    private let range = StandaloneMetronomeEngine.bpmRange   // 30...300

    // MARK: bounds

    func testEndsMapToZeroAndOne() {
        XCTAssertEqual(TempoSliderScale.position(forBPM: 30, in: range), 0, accuracy: 1e-9)
        XCTAssertEqual(TempoSliderScale.position(forBPM: 300, in: range), 1, accuracy: 1e-9)
        XCTAssertEqual(TempoSliderScale.bpm(forPosition: 0, in: range), 30)
        XCTAssertEqual(TempoSliderScale.bpm(forPosition: 1, in: range), 300)
    }

    // MARK: the fix — midpoint is the geometric centre, not the arithmetic one

    func testMidpointIsTheGeometricCentre() {
        // √(30·300) ≈ 94.87 → 95, vs the linear midpoint of 165 the perception bug came from.
        XCTAssertEqual(TempoSliderScale.bpm(forPosition: 0.5, in: range), 95)
    }

    func testCommonTemposFillTheCentreOfTheTrack() {
        // On a linear scale 60–120 sits at 0.11–0.33 (left fifth); on the log scale it
        // straddles the middle, so a normal tempo no longer looks slow.
        let low = TempoSliderScale.position(forBPM: 60, in: range)
        let high = TempoSliderScale.position(forBPM: 120, in: range)
        XCTAssertEqual(low, 0.30, accuracy: 0.02)
        XCTAssertGreaterThan(high, 0.5)          // 120 is past the midpoint
        XCTAssertLessThan(high, 0.65)
    }

    // MARK: monotonic + round-trip

    func testPositionIsMonotonicInBPM() {
        let positions = stride(from: 30, through: 300, by: 10).map {
            TempoSliderScale.position(forBPM: $0, in: range)
        }
        XCTAssertEqual(positions, positions.sorted())
        XCTAssertEqual(Set(positions).count, positions.count, "no two tempos share a position")
    }

    func testBPMRoundTripsThroughPosition() {
        for bpm in [30, 45, 60, 90, 95, 120, 160, 200, 300] {
            let restored = TempoSliderScale.bpm(
                forPosition: TempoSliderScale.position(forBPM: bpm, in: range), in: range)
            XCTAssertEqual(restored, bpm, "round-trip drifted for \(bpm)")
        }
    }

    // MARK: clamping

    func testOutOfRangeInputsClamp() {
        XCTAssertEqual(TempoSliderScale.position(forBPM: 10, in: range), 0, accuracy: 1e-9)
        XCTAssertEqual(TempoSliderScale.position(forBPM: 500, in: range), 1, accuracy: 1e-9)
        XCTAssertEqual(TempoSliderScale.bpm(forPosition: -0.5, in: range), 30)
        XCTAssertEqual(TempoSliderScale.bpm(forPosition: 1.5, in: range), 300)
    }
}
