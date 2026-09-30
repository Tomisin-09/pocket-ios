import XCTest
@testable import Pocket

/// Undo and redo in Name the notes (ADR 0234 D6), and where a placed note moves the strip (D3).
final class NamingHistoryTests: XCTestCase {

    private let standard = [64, 59, 55, 50, 45, 40]

    private func step(_ labels: [PieceLabel?], active: Int = 0, openMidi: [Int]? = nil) -> NamingHistory.Step {
        NamingHistory.Step(taps: labels.enumerated().map { .init(seconds: Double($0.offset), label: $0.element) },
                           openMidi: openMidi ?? standard, tuningLabel: "Guitar · Standard", active: active)
    }

    func testAChangeIsOneStepBackAndForward() throws {
        var history = NamingHistory()
        let before = step([nil, nil, nil], active: 1)
        let after = step([nil, .fretted(string: 2, fret: 7), nil], active: 2)
        history.record(before, now: after)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)

        let undone = try XCTUnwrap(history.undo(from: after))
        XCTAssertEqual(undone.taps, before.taps)
        XCTAssertEqual(undone.active, 1, "lands on the note that changed, not where the strip had moved to")
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)

        let redone = try XCTUnwrap(history.redo(from: undone))
        XCTAssertEqual(redone.taps, after.taps)
        XCTAssertEqual(redone.active, 1, "and back on it")
        XCTAssertNil(history.redo(from: redone), "nothing left to redo")
    }

    func testNothingChangedIsNoStep() {
        var history = NamingHistory()
        let same = step([.pitchClass(9), nil])
        history.record(same, now: step([.pitchClass(9), nil], active: 1))
        XCTAssertFalse(history.canUndo, "a move with no change isn't something to undo")
    }

    func testANewTuningAloneIsAStep() {
        var history = NamingHistory()
        history.record(step([nil]), now: step([nil], openMidi: [62, 59, 55, 50, 45, 38]))
        XCTAssertTrue(history.canUndo, "the strings come back with the frets")
    }

    func testAFreshChangeEndsTheRedoTrail() throws {
        var history = NamingHistory()
        let first = step([nil, nil])
        let second = step([.pitchClass(0), nil])
        history.record(first, now: second)
        let undone = try XCTUnwrap(history.undo(from: second))
        history.record(undone, now: step([nil, .pitchClass(2)]))
        XCTAssertFalse(history.canRedo)
    }

    func testTheHistoryIsBounded() {
        var history = NamingHistory()
        for index in 0...(NamingHistory.limit + 10) {
            history.record(step([.pitchClass(index % 12)]), now: step([.pitchClass((index + 1) % 12)]))
        }
        XCTAssertEqual(history.undos.count, NamingHistory.limit)
    }

    func testATapTakenOutOrAddedLandsWhereItWas() {
        let three: [PieceTranscription.Tap] = [.init(seconds: 1), .init(seconds: 2), .init(seconds: 3)]
        let withoutTheMiddle: [PieceTranscription.Tap] = [.init(seconds: 1), .init(seconds: 3)]
        XCTAssertEqual(NamingHistory.landing(from: withoutTheMiddle, to: three, otherwise: 0), 1,
                       "undoing a tap taken out lands on it")
        XCTAssertEqual(NamingHistory.landing(from: three, to: withoutTheMiddle, otherwise: 0), 1,
                       "redoing it lands where it was")
        XCTAssertEqual(NamingHistory.landing(from: three, to: [.init(seconds: 1), .init(seconds: 2)], otherwise: 0), 1,
                       "the last taken out lands on the new last")
        XCTAssertEqual(NamingHistory.landing(from: three, to: three, otherwise: 2), 2, "no tap differs: stay")
        XCTAssertEqual(NamingHistory.landing(from: three, to: [], otherwise: 2), 0)
    }

    // MARK: - Moving on (D3)

    func testPlacingMovesOnAndTheMarksStayBehind() {
        XCTAssertEqual(NamingCursor.afterPlacing(at: 11, count: 16, chords: false),
                       NamingCursor.Move(active: 12, marked: 11))
    }

    func testWithChordsOnOrOnTheLastNoteItStays() {
        XCTAssertEqual(NamingCursor.afterPlacing(at: 3, count: 16, chords: true),
                       NamingCursor.Move(active: 3, marked: nil), "a shape takes several taps")
        XCTAssertEqual(NamingCursor.afterPlacing(at: 15, count: 16, chords: false),
                       NamingCursor.Move(active: 15, marked: nil), "nowhere to go")
    }
}
