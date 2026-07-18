import XCTest
@testable import Pocket

/// The **pure Hear scheduling math** (ADR 0097) — verifies `HearPlan` turns an ordered note list into
/// correctly timed note events for both the block-chord and melodic-line cases, and that rests keep the
/// walk aligned. This is the logic that drifted (S3) before it was pinned to absolute deadlines; these
/// tests are the safety net that lets `HearSequencer` stay a thin dispatcher over it. All pure, no audio.
final class HearPlanTests: XCTestCase {

    // MARK: - Block chord (stride 0)

    func testBlockChordAllOnsetAtZeroAndReleaseTogether() {
        let events = HearPlan.events(notes: [60, 64, 67], stride: 0, duration: 1.8)

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.midi), [60, 64, 67])
        for event in events {
            XCTAssertEqual(event.onset, 0, accuracy: 1e-9, "every block note onsets at 0")
            XCTAssertEqual(event.offset, 1.8, accuracy: 1e-9, "every block note releases after `duration`")
        }
    }

    func testBlockChordIsPolyphonic() {
        XCTAssertFalse(HearPlan.isMonophonic(stride: 0))
    }

    // MARK: - Melodic line (stride > 0)

    func testMelodicLineOnsetsAreEvenlySpacedFromStart() {
        let events = HearPlan.events(notes: [60, 62, 64, 65], stride: 0.4, duration: 0.32)

        // Absolute deadlines: each onset is index*stride, never a running sum that could drift.
        for (index, event) in events.enumerated() {
            XCTAssertEqual(event.onset, Double(index) * 0.4, accuracy: 1e-9)
            XCTAssertEqual(event.offset, event.onset + 0.32, accuracy: 1e-9, "releases `duration` later")
        }
    }

    func testMelodicLineIsMonophonic() {
        XCTAssertTrue(HearPlan.isMonophonic(stride: 0.3))
    }

    // MARK: - Rests

    func testRestConsumesItsSlotButEmitsNoEvent() {
        // A custom drill's empty cell: index 1 is a rest, so the note after it keeps slot index 2.
        let events = HearPlan.events(notes: [60, nil, 64], stride: 0.5, duration: 0.4)

        XCTAssertEqual(events.count, 2, "the rest emits no event")
        XCTAssertEqual(events.map(\.midi), [60, 64])
        XCTAssertEqual(events.map(\.onset), [0.0, 1.0], "the surviving notes keep their walk slots (0, 2)")
    }

    func testLeadingAndTrailingRestsStillAdvanceSlots() {
        let events = HearPlan.events(notes: [nil, 60, nil], stride: 0.5, duration: 0.4)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.onset ?? -1, 0.5, accuracy: 1e-9, "the note sits in slot 1, not slot 0")
    }

    func testAllRestsProduceNoEvents() {
        XCTAssertTrue(HearPlan.events(notes: [nil, nil, nil], stride: 0.5, duration: 0.4).isEmpty)
    }

    func testEmptyInputProducesNoEvents() {
        XCTAssertTrue(HearPlan.events(notes: [], stride: 0.5, duration: 0.4).isEmpty)
    }

    // MARK: - MIDI clamping

    func testOutOfRangeNotesAreClampedIntoMIDIRange() {
        let events = HearPlan.events(notes: [-5, 300, 64], stride: 0.3, duration: 0.2)

        XCTAssertEqual(events.map(\.midi), [0, 255, 64], "notes clamp to UInt8 bounds, never crash")
    }

    // MARK: - Round-trip length (up-and-back)

    func testRoundTripSequenceKeepsEveryNoteAndTotalDuration() {
        // "Up and back" hands the sequencer the ascending line then its reverse; the plan should time
        // all of them on one continuous walk (no gap, no overlap at the turn).
        let ascending = [60, 62, 64]
        let notes: [Int?] = (ascending + ascending.reversed()).map(Optional.init)
        let stride = 0.5
        let events = HearPlan.events(notes: notes, stride: stride, duration: 0.45)

        XCTAssertEqual(events.count, 6)
        XCTAssertEqual(events.map(\.onset), [0.0, 0.5, 1.0, 1.5, 2.0, 2.5])
        XCTAssertEqual(events.map(\.midi), [60, 62, 64, 64, 62, 60])
    }
}
