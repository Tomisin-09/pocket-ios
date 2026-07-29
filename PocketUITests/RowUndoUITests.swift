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
final class RowUndoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUndoRestoresADeletedRowWithoutLeavingTheScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] // suppress the first-launch profile intake covering Home
        app.launch()

        try openExercisesLibrary(in: app)

        // "Alternate Picking" is in `PracticePresets.firstRunSlugs`, so a clean install has it, and it
        // collides with no section header (unlike "Legato", which is also a template section).
        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: 20), "no seeded exercise to delete")
        var swipes = 0
        while !drill.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }

        drill.swipeLeft()
        let deleteButton = app.buttons["Delete Alternate Picking"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "trailing swipe offered no Delete")
        deleteButton.tap()

        // Reach for **Undo first**. The toast and the row's disappearance come from one state
        // change, so both are true at the same instant — but only the toast is on a clock, and any
        // wait placed in front of it is spent out of the undo window (see the flake note above).
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "no Undo toast after deleting")

        // The row leaves because the *filter* hid it — nothing is deleted yet.
        XCTAssertTrue(waitForDisappearance(of: drill, timeout: 5), "the deleted row stayed on screen")

        undo.tap()

        // The whole point: back immediately, on this screen, with no navigation.
        XCTAssertTrue(drill.waitForExistence(timeout: 5),
                      "Undo did not restore the row in place (host/environment scoping regression)")
    }

    // MARK: - Helpers

    /// Home → Practice → Exercises. Generous timeouts: on a cold simulator each screen only paints
    /// once first-launch seeding has run, the same variance `PracticeRunUITests` allows for.
    @MainActor
    private func openExercisesLibrary(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5), "Practice card missing")
        var swipes = 0
        while !practiceCard.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(practiceCard.isHittable, "Practice card not reachable by scrolling")
        practiceCard.tap()

        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: 20), "Exercises library row missing")
        exercisesRow.tap()
    }

    @MainActor
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
