import XCTest

/// **A planner session is temporary until it is saved** (ADR 0243).
///
/// The rules are pure and pinned in `TemporarySessionTests`: which routines a surface lists, which
/// ones a Start replaces, what a session is called. What is here is the wiring no unit test can
/// reach. Start on the review screen writes a temporary session, not a saved one. Routines leaves it
/// out. *Save as a routine* on the finish screen keeps it. The routine screen under the player
/// re-reads itself after that save, which is the gap the ADR's Consequences named. And the next Start
/// deletes the last one rather than hiding it.
///
/// **One test, two sessions**, because the second half is about what the second Start does to the
/// first. Each is a Quick one: one block of three drills and so no rest, since a rest counts down
/// for three minutes with nothing to skip. Each is named with a per-run token, so leftovers on a
/// dirty simulator can't match.
///
/// **Every assertion is a delta**, for the reason `RoutineLibraryUITests` gives: the simulator keeps
/// its store between runs. The count on Practice's Routines row is read before and compared after,
/// and the one routine this saves is deleted at the end, which the last count checks.
///
/// **It never searches the library.** Leaving a screen whose search is active means ending the
/// search first, and the control that does that is not the same on CI's iOS 18 as on iOS 26. The
/// count says what the library holds, and a just-saved routine is the top row under the default
/// newest-first sort.
final class TemporarySessionUITests: UITestCase {

    @MainActor
    func testAPlannerSessionIsTemporaryUntilSavedAndTheNextStartReplacesIt() throws {
        let app = launchApp()
        let token = Int.random(in: 100_000...999_999)
        let first = "Temp A \(token)"
        let second = "Temp B \(token)"

        openPractice(in: app)
        let before = try routineCount(in: app)

        // 1. Run a session and leave it unsaved. Its own screen offers Save, not Edit (D4).
        runPlannerSession(named: first, in: app)
        XCTAssertTrue(app.buttons["Save as a routine"].exists,
                      "the finish screen offered no Save as a routine for a temporary session")
        finishSession(in: app)
        let firstBar = app.navigationBars[first]
        XCTAssertTrue(firstBar.buttons["Save"].waitForExistence(timeout: Self.uiTimeout),
                      "a temporary session's own screen should offer Save where a saved routine has Edit")
        XCTAssertFalse(firstBar.buttons["Edit"].exists, "a temporary session took Edit before it was saved")

        // 2. Routines doesn't count it (D2).
        goBack(from: first, to: "Today's session", in: app)
        goBack(from: "Today's session", to: "Practice", in: app)
        XCTAssertEqual(try routineCount(in: app), before, "Routines counted a temporary session")

        // 3. Run a second one, and save it from the finish screen (D4).
        runPlannerSession(named: second, in: app)
        let save = app.buttons["Save as a routine"]
        XCTAssertTrue(save.exists, "the finish screen offered no Save as a routine")
        save.tap()
        XCTAssertTrue(app.staticTexts["Saved to your routines"].waitForExistence(timeout: Self.uiTimeout),
                      "Save as a routine didn't give way to the line saying it was saved")
        finishSession(in: app)
        XCTAssertTrue(app.navigationBars[second].buttons["Edit"].waitForExistence(timeout: Self.uiTimeout),
                      "the routine screen under the player still treats a saved session as temporary")
        // Two sessions built from one library minutes apart share most of their drills and loops, and
        // replacing the first must leave the second's blocks pointing at them. Deleting the first
        // through the wrong context turned every shared block into *Unit removed* (`Routine.
        // deleteTemporaries`). Only bites when they overlap — they did on every run while building.
        XCTAssertFalse(app.staticTexts["Unit removed"].exists,
                       "replacing the first session unlinked blocks the second shares with it")
        goBack(from: second, to: "Today's session", in: app)
        goBack(from: "Today's session", to: "Practice", in: app)
        XCTAssertEqual(try routineCount(in: app), before + 1, "Save as a routine didn't put it in Routines")

        // 4. The first was deleted by the second Start, not just hidden (D3). Home's rail lists every
        //    routine practised, temporary or not, so the first would still be on it.
        goBack(from: "Practice", to: nil, in: app)
        let card = { (name: String) in
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        }
        XCTAssertTrue(card(second).waitForExistence(timeout: Self.uiTimeout),
                      "the saved session isn't on Home")
        XCTAssertFalse(card(first).exists, "the first temporary session survived the next Start")

        // 5. Put the simulator back. Newest first, so the saved session is the top row; the delete
        //    commits when the screen is left (`RowDeletionCoordinator`).
        openPractice(in: app)
        openRoutines(in: app)
        let row = app.cells.containing(.staticText, identifier: second).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the saved session isn't in Routines")
        row.swipeLeft()
        let delete = app.buttons["Delete \(second)"]
        XCTAssertTrue(delete.waitForExistence(timeout: Self.uiTimeout), "no Delete on the saved session's row")
        delete.tap()
        goBack(from: "Routines", to: "Practice", in: app)
        XCTAssertEqual(try routineCount(in: app), before, "the saved session was left behind")
    }

    // MARK: - Steps

    /// Practice ▸ Today's session ▸ Quick ▸ Generate, name it, Start, past the tune-up question, and
    /// skip every block to the finish screen.
    @MainActor
    private func runPlannerSession(named name: String, in app: XCUIApplication) {
        let planner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Today's session")).firstMatch
        XCTAssertTrue(tap(planner, until: app.navigationBars["Today's session"], in: app),
                      "the planner never opened")
        // Quick: one block, so no rest to sit through. The length is seeded from the profile (S2).
        let quick = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Quick")).firstMatch
        XCTAssertTrue(quick.waitForExistence(timeout: Self.uiTimeout), "no Quick length")
        quick.tap()
        let generate = app.buttons["Generate today's session"]
        XCTAssertTrue(generate.waitForExistence(timeout: Self.uiTimeout), "no Generate button")
        generate.tap()

        let field = app.textFields["Routine name"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the review screen never opened")
        let generated = field.value as? String ?? ""
        focusAtEnd(field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: generated.count + 2) + name)
        dismissKeyboard(in: app)
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: Self.uiTimeout),
                      "the review screen didn't take the name")

        let start = app.buttons["Start routine"]
        XCTAssertTrue(start.waitForExistence(timeout: Self.uiTimeout), "no Start on the review screen")
        start.tap()

        // ADR 0195 asks first, by default.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: Self.uiTimeout) { notNow.tap() }

        let recap = app.staticTexts["Session complete"]
        for _ in 0..<8 where !recap.exists {
            let skip = app.buttons["Skip to next block"]
            guard skip.waitForExistence(timeout: Self.uiTimeout) else { break }
            skip.tap()
        }
        XCTAssertTrue(recap.waitForExistence(timeout: Self.uiTimeout), "the session never reached its finish screen")
    }

    /// The finish screen's **Done**, which closes the player. Scrolled to first: the note sits above it.
    @MainActor
    private func finishSession(in app: XCUIApplication) {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: Self.uiTimeout), "no Done on the finish screen")
        scrollIntoView(done, in: app)
        done.tap()
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["Session complete"]), "Done didn't close the player")
    }

    // MARK: - Reach

    @MainActor
    private func openPractice(in app: XCUIApplication) {
        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(tap(practice, until: app.navigationBars["Practice"], in: app), "Practice never opened")
    }

    @MainActor
    private func openRoutines(in app: XCUIApplication) {
        XCTAssertTrue(tap(routinesRow(in: app), until: app.navigationBars["Routines"], in: app),
                      "Routines never opened")
    }

    /// Practice's **Routines** row, labelled `Routines, N` (`PracticeView.libraryRow`).
    @MainActor
    private func routinesRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Routines, ")).firstMatch
    }

    /// The `N` in that label: how many routines the library holds.
    @MainActor
    private func routineCount(in app: XCUIApplication) throws -> Int {
        let row = routinesRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "no Routines row on Practice")
        let count = row.label.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) }
        return try XCTUnwrap(count.flatMap { Int($0) }, "the Routines row reads '\(row.label)'")
    }

    /// Back one screen, by the leading item of the bar being **left** — named, because a screen under
    /// a pushed one leaves its bar in the tree too.
    @MainActor
    private func goBack(from leaving: String, to arriving: String?, in app: XCUIApplication) {
        let bar = app.navigationBars[leaving]
        XCTAssertTrue(bar.waitForExistence(timeout: Self.uiTimeout), "not on '\(leaving)' to go back from")
        bar.buttons.element(boundBy: 0).tap()
        if let arriving {
            XCTAssertTrue(app.navigationBars[arriving].waitForExistence(timeout: Self.uiTimeout),
                          "left '\(leaving)' and never reached '\(arriving)'")
        } else {
            XCTAssertTrue(waitForDisappearance(of: bar), "never left '\(leaving)'")
        }
    }

    /// Tap `field` past the end of its text until it actually holds keyboard focus, so the caret is
    /// at the end and the deletes that follow clear the whole name.
    ///
    /// **At 80% of the width, not the 95% `RoutineLibraryUITests.clear` uses.** On iOS 18 this field
    /// reports its whole *row* as its frame (x 20–382 on a 402-wide screen), while the text field
    /// that takes the touch sits inside the row's 20 pt margins. A tap at 95% landed in the margin,
    /// three times running, and `typeText` failed with "Neither element nor any descendant has
    /// keyboard focus"; iOS 26 reports the field's own frame and took it. 80% is inside the field on
    /// both and still well past the end of a dated name. It also waits for the focus, rather than
    /// assuming a tap landed.
    @MainActor
    private func focusAtEnd(_ field: XCUIElement) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
            let took = expectation(for: focused, evaluatedWith: field)
            if XCTWaiter().wait(for: [took], timeout: 3) == .completed { return }
        }
        XCTFail("the name field never took keyboard focus")
    }

    /// By coordinate, for the reason `RoutineLibraryUITests.dismissKeyboard` gives.
    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["Dismiss keyboard"]
        guard done.exists else { return }
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
