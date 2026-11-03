import XCTest

/// Getting a note into the Journal and the Journal on screen, through the app's own capture path, for the
/// tests that need a row to act on: `RowUndoUITests` (delete and Undo) and `JournalThreadUITests` (ADR 0286).
/// Moved here from `RowUndoUITests`, where they were private, when the thread test needed them too.
extension UITestCase {

    /// Write one note against a seeded drill, through the app's own capture path: Exercises → the
    /// drill's run screen → Start → the nav-bar quick-note button → Save → Stop. Leaves the app back
    /// on Home.
    ///
    /// Deliberately the **toolbar** button (ADR 0142) rather than the review bar's Journal pill: the
    /// bar is the last thing in a long `ScrollView`, so on a fresh run screen it isn't in the
    /// accessibility tree at all until you scroll it in. A toolbar item always is.
    ///
    /// **The run is started first** because since ADR 0221 D7 the pencil shows only where the review
    /// bar doesn't — running, or inside a routine. A stopped screen has the bar's Journal instead.
    /// Nothing here waits for the ramp: the note is written over the live run, which is the state the
    /// quick-note sheet exists for, and Stop ends it before a completion screen could appear.
    @MainActor
    func writeAJournalNote(_ text: String, in app: XCUIApplication) throws {
        try openExercisesFromHome(in: app)

        let drill = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to write a note against")
        scrollIntoView(drill, in: app)
        drill.tap()

        let start = app.buttons["Start training routine"]
        XCTAssertTrue(start.waitForExistence(timeout: Self.uiTimeout), "no Start on the run screen")
        // Stopped and standalone, the review bar's Journal writes, so the pencil is not offered too.
        // Checked only once Start proves the screen is up, and the same query must then find the
        // pencil below — so this can't pass by looking too early or at the wrong label.
        let quickNote = app.buttons["Write a quick journal note"]
        XCTAssertFalse(quickNote.exists, "the pencil shows on a stopped run screen (ADR 0221 D7)")
        start.tap()

        XCTAssertTrue(quickNote.waitForExistence(timeout: Self.uiTimeout),
                      "no quick-note button on the running screen (ADR 0221 D7)")
        quickNote.tap()

        // `TextField(axis: .vertical)` surfaces as a text *view* on some runtimes and a text field on
        // others, so accept either rather than pinning the test to one of them.
        let field = composerField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the quick-note sheet has no field")
        field.tap()
        field.typeText(text)

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: Self.uiTimeout), "no Save button on the quick-note sheet")
        save.tap()

        let stop = app.buttons["Stop and reset"]
        XCTAssertTrue(stop.waitForExistence(timeout: Self.uiTimeout), "no Stop on the running screen")
        stop.tap()

        try returnHome(in: app)
    }

    @MainActor
    func composerField(in app: XCUIApplication) -> XCUIElement {
        let placeholder = "What just happened?"
        let asField = app.textFields[placeholder]
        return asField.waitForExistence(timeout: Self.uiTimeout) ? asField : app.textViews[placeholder]
    }

    /// Pop back to Home. The run screen is three levels deep (Home → Practice hub → Exercises
    /// library → run), so this walks the back button until Home's own first card shows up rather
    /// than counting taps.
    @MainActor
    func returnHome(in app: XCUIApplication) throws {
        let homeMarker = app.buttons["Practice, your exercises and training runs"]
        var backs = 0
        while !homeMarker.exists && backs < 5 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: Self.uiTimeout) else { break }
            back.tap()
            backs += 1
        }
        XCTAssertTrue(homeMarker.waitForExistence(timeout: Self.uiTimeout), "never got back to Home")
    }

    /// Home → Journal.
    @MainActor
    func openJournalFromHome(in app: XCUIApplication) throws {
        let journalCard = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journalCard.waitForExistence(timeout: Self.uiTimeout), "Journal card missing")
        XCTAssertTrue(scrollIntoView(journalCard, in: app), "Journal card not reachable by scrolling")
        journalCard.tap()
    }

    /// Home → Practice → Exercises.
    @MainActor
    func openExercisesFromHome(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()

        XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: Self.uiTimeout),
                      "Practice hub did not open from Home")
        openPracticeLibrary("Exercises", in: app)
    }
}
