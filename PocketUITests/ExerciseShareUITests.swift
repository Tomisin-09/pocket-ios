import XCTest

/// The two controls ADR 0209 adds to the Exercises library, both of which are **wiring** — the kind
/// of thing a green unit suite says nothing about.
///
/// `ReceivedExerciseTests` covers what the file carries and what lands; neither can tell you whether
/// the share control is on the sheet's toolbar or whether the receive row survived being put inside a
/// menu that used to hide itself. Those are the two ways this feature can be built correctly and
/// still be unreachable.
final class ExerciseShareUITests: UITestCase {

    /// The share control is on the drill's read-only detail sheet (D3), reached the way a player
    /// reaches it: hold the row, then **Details**.
    @MainActor
    func testADrillsDetailSheetOffersToShareIt() throws {
        let app = launchApp()
        try openExercisesLibrary(in: app)

        // "Alternate Picking" is in `PracticePresets.firstRunSlugs`, so a clean install has it, and it
        // collides with no section header — the same row `RowUndoUITests` leans on, for that reason.
        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to open")
        XCTAssertTrue(scrollIntoView(drill, in: app), "the seeded drill was not reachable")

        drill.press(forDuration: 1.0)
        let details = app.buttons["Details"]
        XCTAssertTrue(details.waitForExistence(timeout: Self.uiTimeout), "the row menu offered no Details")
        details.tap()

        // The sheet's own gate first, so a failure below reads as "no share control" rather than
        // "the sheet never opened" — the two are indistinguishable from a bare button query.
        XCTAssertTrue(app.navigationBars["Alternate Picking"].waitForExistence(timeout: Self.uiTimeout),
                      "the detail sheet did not open")

        // `ShareLink` exposes itself as a button labelled Share; the glyph is what is drawn, and the
        // label is the system's, which is why this asks the toolbar for it rather than for an icon.
        let share = app.navigationBars["Alternate Picking"].buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: Self.uiTimeout),
                      "the detail sheet's toolbar carries no share control")
    }

    /// *Receive an exercise…* lives in the options menu, and the menu is now unconditional (D4). The
    /// assertion that matters is the second one: it used to be wrapped in `if !presentExercises
    /// .isEmpty`, which would have hidden this row at exactly the moment it is most wanted.
    @MainActor
    func testTheExercisesLibraryOffersToReceiveOne() throws {
        let app = launchApp()
        try openExercisesLibrary(in: app)

        let options = app.buttons["List options"]
        XCTAssertTrue(options.waitForExistence(timeout: Self.uiTimeout), "no options control on Exercises")
        options.tap()

        XCTAssertTrue(app.buttons["Receive an exercise…"].waitForExistence(timeout: Self.uiTimeout),
                      "the options menu offers no way to receive a shared drill")
    }

    @MainActor
    private func openExercisesLibrary(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()

        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: Self.uiTimeout), "Exercises library row missing")
        exercisesRow.tap()
    }
}
