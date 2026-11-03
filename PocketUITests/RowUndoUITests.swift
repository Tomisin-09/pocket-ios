import XCTest

/// Regression guard for the **Undo doesn't restore the row until you leave and come back** bug
/// (Slice 3, found on device 2026-07-29).
///
/// Two causes compounded, and neither was reachable from a unit test — both were *wiring*:
/// 1. `.pocketRowUndoHost()` owned the coordinator itself, but a modifier applied inside a view's
///    `body` publishes its environment to that view's **descendants** only. The screen's own
///    `@Environment(\.rowDeletion)` resolved from its parent — the default no-op seam — so every
///    pending-row filter silently did nothing. The coordinator is now owned by the screen.
/// 2. The trailing swipe used `Button(role: .destructive)`, which plays SwiftUI's own row-removal
///    animation on tap regardless of the data. That made the row *look* deleted, so cause 1 was
///    invisible until Undo failed to bring it back. The swipe button is now a plain tinted button.
///
/// The observable contract this pins: after Undo, the row is back **on the same screen**, with no
/// navigation in between.
///
/// **It raced its own subject, and turned `main` red on 2026-07-29** (CI run 30441349304, the
/// post-merge build of PR #188 — nothing in that PR touched row actions). The undo toast lives for
/// `RowDeletionCoordinator.window`, counted from the Delete tap; this test then waited up to five
/// seconds for the row to vanish *before* looking for Undo, so on a slow runner the button it
/// finally found had already expired: `waitForExistence` passed, `tap()` reported "No matches
/// found". Two changes, because either alone only narrows the gap:
/// - the wait order is inverted here — grab the thing on a clock first;
/// - `RowDeletionCoordinator.window` is stretched under `-uiTesting`, since the four-second figure
///   is a *product* decision this test was never asserting.
final class RowUndoUITests: UITestCase {

    @MainActor
    func testUndoRestoresADeletedRowWithoutLeavingTheScreen() throws {
        let app = launchApp()

        try openExercisesFromHome(in: app)

        // "Alternate Picking" is in `PracticePresets.firstRunSlugs`, so a clean install has it, and it
        // collides with no section header (unlike "Legato", which is also a template section).
        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to delete")
        scrollIntoView(drill, in: app)

        drill.swipeLeft()
        let deleteButton = app.buttons["Delete Alternate Picking"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: Self.uiTimeout), "trailing swipe offered no Delete")
        deleteButton.tap()

        // Reach for **Undo first**. The toast and the row's disappearance come from one state
        // change, so both are true at the same instant — but only the toast is on a clock, and any
        // wait placed in front of it is spent out of the undo window (see the flake note above).
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.uiTimeout), "no Undo toast after deleting")

        // The row leaves because the *filter* hid it — nothing is deleted yet.
        XCTAssertTrue(waitForDisappearance(of: drill), "the deleted row stayed on screen")

        undo.tap()

        // The whole point: back immediately, on this screen, with no navigation.
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout),
                      "Undo did not restore the row in place (host/environment scoping regression)")
    }

    /// The **Journal** feed's undo, which the library test above does not reach: a different screen,
    /// a different coordinator, and a second *gesture*. Delete here is on the hold menu as well as a
    /// trailing swipe (ADR 0285, which ended 2026-08-06's hold-only rule), and this is the only test
    /// that would catch the hold menu being wired to nothing. The swipe has its own test below.
    ///
    /// A clean install's Journal is empty, so the test **writes its own note** through the app's real
    /// capture path rather than a seeded fixture — no test-only code in the app, and the write half of
    /// the feature gets walked on the way in.
    ///
    /// A take would have been the more valuable subject — its delete removes an audio file — but a
    /// take cannot be created in the simulator at all: it needs a real microphone. The Takes sheet
    /// shares this screen's coordinator, gesture and deferral, so this covers the pattern; the audio
    /// path itself stays a device check.
    @MainActor
    func testUndoRestoresADeletedJournalNote() throws {
        let app = launchApp()
        // Unique per run. The simulator keeps the app's store between test runs, so a fixed string
        // accumulates a row per run on a dev machine — and then `firstMatch` finds *last* run's copy
        // still on screen after this run's is deleted, failing on a bug that isn't there.
        let noteText = "Undo test note \(UUID().uuidString.prefix(6))"
        try writeAJournalNote(noteText, in: app)
        try openJournalFromHome(in: app)

        let note = app.cells.containing(.staticText, identifier: noteText).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "the note just written isn't on the feed")

        note.press(forDuration: 1.2)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: Self.uiTimeout), "the hold menu offered no Delete")
        deleteButton.tap()

        // Undo first — it is the thing on a clock. See the flake note on the test above.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.uiTimeout), "no Undo toast after deleting a note")
        XCTAssertTrue(waitForDisappearance(of: note), "the deleted note stayed on screen")

        undo.tap()
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "Undo did not restore the journal note")
    }

    /// The Journal's **trailing swipe** (ADR 0285), which sits beside the hold menu above. Two things
    /// it must do, and the first is the reason the swipe was refused until then: a swipe on its own
    /// deletes **nothing** (`allowsFullSwipe: false`), and the button it shows is a plain one, so Undo
    /// brings the row back rather than a `.destructive` animation taking it away for good.
    @MainActor
    func testJournalSwipeShowsDeleteAndUndoRestoresTheNote() throws {
        let app = launchApp()
        let noteText = "Swipe test note \(UUID().uuidString.prefix(6))"
        try writeAJournalNote(noteText, in: app)
        try openJournalFromHome(in: app)

        let note = app.cells.containing(.staticText, identifier: noteText).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "the note just written isn't on the feed")

        // A drag across the **whole row**, not `swipeLeft()`. XCUITest's swipe stops short of a full
        // swipe, so with `allowsFullSwipe: true` it still only shows the button, and this test passed
        // against that mutant (2026-11-03). Edge to edge is the gesture a full swipe deletes on.
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: note.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: Self.uiTimeout), "the trailing swipe offered no Delete")
        // The swipe alone removed nothing: no toast, and the note is still there.
        XCTAssertFalse(app.buttons["Undo"].exists, "a full swipe on its own started a delete (it must be off)")
        XCTAssertTrue(note.exists, "a full swipe on its own removed the note")
        // Kept, so the row with its Delete showing can be looked at, not only asserted on.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "journal-swipe-delete"
        shot.lifetime = .keepAlways
        add(shot)
        deleteButton.tap()

        // Undo first — it is the thing on a clock. See the flake note on the first test.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: Self.uiTimeout), "no Undo toast after the swipe's Delete")
        XCTAssertTrue(waitForDisappearance(of: note), "the swiped-away note stayed on screen")

        undo.tap()
        XCTAssertTrue(note.waitForExistence(timeout: Self.uiTimeout), "Undo did not restore the swiped-away note")
    }
}
