import XCTest
@testable import Pocket

/// Undo and redo for any editor (ADR 0235 D9): the stacks, the bound, and the landing, with a step of the
/// test's own, so nothing here leans on Name the notes. `NamingHistoryTests` pins Name the notes' step.
final class EditHistoryTests: XCTestCase {

    /// A line of letters and where the cursor was. The cursor never counts as a change.
    private struct Letters: EditStep {
        var text: [Character]
        var active: Int

        init(_ text: String, at active: Int = 0) {
            self.text = Array(text)
            self.active = active
        }

        func changes(_ other: Letters) -> Bool { text != other.text }
        func landing(from current: Letters) -> Int {
            EditHistory<Letters>.landing(from: current.text, to: text, otherwise: active)
        }
    }

    func testAChangeGoesBackAndComesAgainLandingOnWhatChanged() throws {
        var history = EditHistory<Letters>()
        let before = Letters("abc", at: 3)
        let after = Letters("abXc", at: 3)
        history.record(before, now: after)

        let undone = try XCTUnwrap(history.undo(from: after))
        XCTAssertEqual(undone.text, before.text)
        XCTAssertEqual(undone.active, 2, "on the letter that went, not where the cursor was")
        XCTAssertTrue(history.canRedo)

        let redone = try XCTUnwrap(history.redo(from: undone))
        XCTAssertEqual(redone.text, after.text)
        XCTAssertEqual(redone.active, 2, "and on it again")
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testMovingTheCursorAloneIsNoStep() {
        var history = EditHistory<Letters>()
        history.record(Letters("abc", at: 0), now: Letters("abc", at: 2))
        XCTAssertFalse(history.canUndo)
    }

    func testAFreshChangeEndsTheRedoTrail() throws {
        var history = EditHistory<Letters>()
        history.record(Letters("a"), now: Letters("ab"))
        let undone = try XCTUnwrap(history.undo(from: Letters("ab")))
        XCTAssertTrue(history.canRedo)
        history.record(undone, now: Letters("aZ"))
        XCTAssertFalse(history.canRedo)
    }

    func testItKeepsTheLatestHundred() {
        var history = EditHistory<Letters>()
        for index in 0..<(EditHistory<Letters>.limit + 5) {
            history.record(Letters(String(repeating: "a", count: index)),
                           now: Letters(String(repeating: "a", count: index + 1)))
        }
        XCTAssertEqual(EditHistory<Letters>.limit, 100)
        XCTAssertEqual(history.undos.count, 100)
        XCTAssertEqual(history.undos.first?.text.count, 5, "the oldest five went, not the newest")
    }

    func testNothingToUndoOrRedoIsNil() {
        var history = EditHistory<Letters>()
        XCTAssertNil(history.undo(from: Letters("a")))
        XCTAssertNil(history.redo(from: Letters("a")))
    }

    func testTheLandingIsTheFirstDifferenceAndNeverPastTheEnd() {
        func landing(_ current: [Int], _ restored: [Int], _ fallback: Int) -> Int {
            EditHistory<Letters>.landing(from: current, to: restored, otherwise: fallback)
        }
        XCTAssertEqual(landing([1, 2, 3], [1, 9, 3], 0), 1)
        XCTAssertEqual(landing([1, 2, 3], [1, 2], 0), 1, "something added lands where it was, kept inside")
        XCTAssertEqual(landing([1, 2], [1, 2, 3], 0), 2, "something taken out comes back where it was")
        XCTAssertEqual(landing([1, 2, 3], [1, 2, 3], 1), 1, "nothing differs: where the step was")
        XCTAssertEqual(landing([1, 2, 3], [1, 2, 3], 7), 2, "and never past the end")
        XCTAssertEqual(landing([1], [], 3), 0)
    }
}
