import XCTest
@testable import Pocket

/// Pure reading-smoothing for the tuner (ADR 0115): cents easing on a held note, snap on a note
/// change, and dropout-hold before blanking. UI-free, so the settling behaviour is pinned here.
final class TunerSmootherTests: XCTestCase {

    private func reading(midi: Int, cents: Double) -> TunerReading {
        TunerReading(midiNote: midi, octave: 4, cents: cents, spelling: .default)
    }

    func testFirstReadingPassesThrough() {
        var smoother = TunerSmoother()
        let out = smoother.ingest(reading(midi: 69, cents: 12))
        XCTAssertEqual(out?.cents, 12)
    }

    func testSameNoteEasesCentsTowardFresh() {
        var smoother = TunerSmoother(smoothing: 0.3, holdFrames: 8)
        smoother.ingest(reading(midi: 69, cents: 0))
        let out = smoother.ingest(reading(midi: 69, cents: 10))
        // EMA: 0·0.7 + 10·0.3 = 3 — between the old and the new, not a jump to 10.
        XCTAssertEqual(out?.cents ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(out?.midiNote, 69)
    }

    func testNoteChangeSnapsWithoutEasing() {
        var smoother = TunerSmoother(smoothing: 0.3, holdFrames: 8)
        smoother.ingest(reading(midi: 69, cents: 40))
        let out = smoother.ingest(reading(midi: 64, cents: -20))
        XCTAssertEqual(out?.midiNote, 64)
        XCTAssertEqual(out?.cents, -20)          // snapped, not averaged across notes
    }

    func testHoldsThroughBriefDropoutThenBlanks() {
        var smoother = TunerSmoother(smoothing: 0.3, holdFrames: 3)
        smoother.ingest(reading(midi: 69, cents: 5))
        XCTAssertNotNil(smoother.ingest(nil))    // miss 1 — hold
        XCTAssertNotNil(smoother.ingest(nil))    // miss 2 — hold
        XCTAssertNil(smoother.ingest(nil))       // miss 3 — reached holdFrames → blank
    }

    func testConfidentReadingResetsMissStreak() {
        var smoother = TunerSmoother(smoothing: 0.3, holdFrames: 2)
        smoother.ingest(reading(midi: 69, cents: 5))
        smoother.ingest(nil)                     // miss 1
        smoother.ingest(reading(midi: 69, cents: 6))  // confident again → streak resets
        XCTAssertNotNil(smoother.ingest(nil))    // this is miss 1 again, not miss 2 → still held
    }

    func testResetClearsCurrent() {
        var smoother = TunerSmoother()
        smoother.ingest(reading(midi: 69, cents: 5))
        smoother.reset()
        XCTAssertNil(smoother.current)
    }
}
