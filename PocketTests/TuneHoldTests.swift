import XCTest
@testable import Pocket

/// Pure hold-to-confirm timing for the tuner (ADR 0115): confirm after holding a note in tune,
/// fire once, and reset on drift / note change.
final class TuneHoldTests: XCTestCase {

    private func reading(midi: Int, cents: Double) -> TunerReading {
        TunerReading(midiNote: midi, noteName: "E", octave: 2, cents: cents)
    }

    func testConfirmsAfterRequiredHoldAndFiresOnce() {
        var hold = TuneHold(requiredHold: 0.8)
        let note = reading(midi: 40, cents: 1)
        XCTAssertFalse(hold.update(reading: note, now: 0.0))    // streak starts
        XCTAssertFalse(hold.update(reading: note, now: 0.5))    // not held long enough
        XCTAssertTrue(hold.update(reading: note, now: 0.9))     // past the threshold → fire
        XCTAssertTrue(hold.isConfirmed)
        XCTAssertFalse(hold.update(reading: note, now: 1.2))    // stays confirmed, doesn't re-fire
    }

    func testOutOfTuneResetsBeforeConfirm() {
        var hold = TuneHold(requiredHold: 0.8)
        hold.update(reading: reading(midi: 40, cents: 2), now: 0.0)
        XCTAssertFalse(hold.update(reading: reading(midi: 40, cents: 20), now: 0.4))  // drifted sharp
        XCTAssertFalse(hold.isConfirmed)
        // Streak must restart from here, so 0.4s later is not yet a full hold.
        XCTAssertFalse(hold.update(reading: reading(midi: 40, cents: 1), now: 0.6))
        XCTAssertTrue(hold.update(reading: reading(midi: 40, cents: 1), now: 1.5))    // 0.9s held
    }

    func testNoteChangeRestartsStreak() {
        var hold = TuneHold(requiredHold: 0.8)
        hold.update(reading: reading(midi: 40, cents: 1), now: 0.0)
        // Move to a different in-tune note before the first could confirm.
        XCTAssertFalse(hold.update(reading: reading(midi: 45, cents: 1), now: 0.5))
        XCTAssertFalse(hold.isConfirmed)
        XCTAssertTrue(hold.update(reading: reading(midi: 45, cents: 1), now: 1.5))   // held new note
        XCTAssertEqual(hold.confirmedMidi, 45)
    }

    func testNilReadingResetsConfirmation() {
        var hold = TuneHold(requiredHold: 0.5)
        hold.update(reading: reading(midi: 40, cents: 0), now: 0.0)
        XCTAssertTrue(hold.update(reading: reading(midi: 40, cents: 0), now: 0.6))
        XCTAssertTrue(hold.isConfirmed)
        XCTAssertFalse(hold.update(reading: nil, now: 0.7))       // silence clears it
        XCTAssertFalse(hold.isConfirmed)
    }
}
