import XCTest
@testable import Pocket

/// `LoopEditSnapshot` — the before-edit capture that powers Undo-on-save (ADR 0019 extended from
/// delete to save). Pure value logic: equality drives whether a toast shows, and `restore` reverts
/// the persisted fields. `Loop` is built **uninserted** (never `context.insert` in the test host —
/// that SIGTRAPs; property logic reads fine off a bare `@Model`).
final class LoopEditSnapshotTests: XCTestCase {

    private func makeLoop() -> Loop {
        let loop = Loop(name: "Verse", start: 0.1, end: 0.3, speed: 0.85, repeats: 4)
        loop.mastery = 3
        loop.focus = 2
        loop.commandTempo = 0.85
        loop.loopType = .riff
        loop.tags = ["solo"]
        loop.colorIndex = 1
        loop.customColorHex = nil
        return loop
    }

    func testUnchangedLoopSnapshotsAreEqual() {
        let loop = makeLoop()
        XCTAssertEqual(LoopEditSnapshot(loop), LoopEditSnapshot(loop))
    }

    func testEachFieldChangeIsDetected() {
        let loop = makeLoop()
        let before = LoopEditSnapshot(loop)

        loop.name = "Chorus";             XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.name = "Verse"               // reset, then vary the next field
        loop.mastery = 5;                 XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.mastery = 3
        loop.focus = nil;                 XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.focus = 2
        loop.commandTempo = 0.9;          XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.commandTempo = 0.85
        loop.loopType = .lick;            XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.loopType = .riff
        loop.tags = ["solo", "fast"];     XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.tags = ["solo"]
        loop.colorIndex = 2;              XCTAssertNotEqual(LoopEditSnapshot(loop), before)
        loop.colorIndex = 1
        loop.customColorHex = "FF0000";   XCTAssertNotEqual(LoopEditSnapshot(loop), before)

        // Back to the original state — equal again.
        loop.customColorHex = nil
        XCTAssertEqual(LoopEditSnapshot(loop), before)
    }

    func testRestoreRevertsEveryCapturedField() {
        let loop = makeLoop()
        let before = LoopEditSnapshot(loop)

        loop.name = "Chorus"
        loop.mastery = nil
        loop.focus = 3
        loop.commandTempo = nil
        loop.loopType = .chords
        loop.tags = []
        loop.colorIndex = nil
        loop.customColorHex = "00FF00"

        before.restore(to: loop)

        XCTAssertEqual(loop.name, "Verse")
        XCTAssertEqual(loop.mastery, 3)
        XCTAssertEqual(loop.focus, 2)
        XCTAssertEqual(loop.commandTempo, 0.85)
        XCTAssertEqual(loop.loopType, .riff)
        XCTAssertEqual(loop.tags, ["solo"])
        XCTAssertEqual(loop.colorIndex, 1)
        XCTAssertNil(loop.customColorHex)
    }
}
