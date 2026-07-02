import XCTest
@testable import Pocket

/// The display-only amplitude compression (ADR 0049). It shapes only the *drawn* bar height,
/// so the contract is: endpoints pinned, monotonic, and it genuinely *lifts* the quiet/mid
/// range (the whole point — a fuller skyline). Pinned here so a future tweak to the curve
/// can't silently invert or overshoot the region (AGENTS.md).
final class WaveformAmplitudeTests: XCTestCase {

    func testEndpointsArePinned() {
        // Silence stays flat; a full bar stays full — the region can't grow or shrink.
        XCTAssertEqual(WaveformAmplitude.display(0), 0, accuracy: 1e-9)
        XCTAssertEqual(WaveformAmplitude.display(1), 1, accuracy: 1e-9)
    }

    func testLiftsTheQuietMidRange() {
        // The reason the curve exists: a mid bar draws *taller* than its linear value, so the
        // skyline fills out instead of hugging the floor.
        XCTAssertGreaterThan(WaveformAmplitude.display(0.25), 0.25)
        XCTAssertGreaterThan(WaveformAmplitude.display(0.5), 0.5)
    }

    func testMonotonicIncreasing() {
        // Louder must never draw shorter — order is preserved so the shape still reads true.
        var previous = -1.0
        for step in 0...20 {
            let value = WaveformAmplitude.display(Double(step) / 20.0)
            XCTAssertGreaterThan(value, previous)
            previous = value
        }
    }

    func testClampsOutOfRangeInput() {
        // A stray reading below 0 or above 1 can't invert the bar or overshoot the ceiling.
        XCTAssertEqual(WaveformAmplitude.display(-0.5), 0, accuracy: 1e-9)
        XCTAssertEqual(WaveformAmplitude.display(1.5), 1, accuracy: 1e-9)
    }

    func testGammaOfOneIsLinearIdentity() {
        // The escape hatch: gamma 1 is the old linear draw, so the curve is a pure opt-in.
        for step in 0...10 {
            let value = Double(step) / 10.0
            XCTAssertEqual(WaveformAmplitude.display(value, gamma: 1.0), value, accuracy: 1e-9)
        }
    }
}
