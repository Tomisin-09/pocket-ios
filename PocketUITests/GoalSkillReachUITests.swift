import XCTest

/// ADR 0216 slice 1 — the goal editor's skill rows: each says what it would pull from the library,
/// and each has an ⓘ that explains the skill **without toggling it**.
///
/// The second half is the one that could break silently. The ⓘ and the keep/drop toggle sit side by
/// side in one list row; nested, a tap on the ⓘ would also drop the skill, and nothing on screen
/// would say so until the goal scheduled less than it should.
///
/// Nothing here is saved — the editor is cancelled — so the test leaves the simulator's store exactly
/// as it found it (the store persists between runs; a saved goal would change the next run's planner).
final class GoalSkillReachUITests: UITestCase {

    @MainActor
    func testSkillRowsSayWhatTheyReachAndTheInfoButtonDoesNotToggle() {
        let app = launchApp()
        // Title *and* blurb: a saved goal from the same template is listed behind the picker as
        // "Build speed, 3 skills, NORMAL", and the store outlives the run, so the title alone can
        // match that row instead of the template.
        openNewGoalEditor(from: "Build speed, Push picking", in: app)

        let skill = app.buttons["Alternate picking"]
        XCTAssertTrue(skill.waitForExistence(timeout: Self.uiTimeout), "no Alternate picking row")
        // A reach line is always present — a count, or "Nothing in your library yet". Which one
        // depends on what this simulator's store holds, so only its presence is asserted.
        XCTAssertFalse((skill.value as? String ?? "").isEmpty, "the skill row carries no reach line")
        XCTAssertTrue(skill.isSelected, "a template's skills start kept")

        let info = app.buttons["About Alternate picking"]
        XCTAssertTrue(info.exists, "no ⓘ beside the skill")
        info.tap()
        let explanation = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Strict down")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: Self.uiTimeout), "the ⓘ opened nothing")

        let dismiss = app.otherElements["PopoverDismissRegion"]
        if dismiss.exists { dismiss.tap() }
        XCTAssertTrue(waitForDisappearance(of: explanation), "the explanation didn't close")
        XCTAssertTrue(skill.isSelected, "tapping the ⓘ dropped the skill — the two taps are nested")

        app.buttons["Cancel"].tap()
    }

    // MARK: - Steps

    /// Home → Practice → Today's session → Add a goal → the named template, stopping on the editor.
    @MainActor
    private func openNewGoalEditor(from template: String, in app: XCUIApplication) {
        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(tap(practice, until: app.navigationBars["Practice"], in: app), "the Practice tap never landed")

        let planner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Today's session")).firstMatch
        XCTAssertTrue(planner.waitForExistence(timeout: Self.uiTimeout), "no Today's session row")
        planner.tap()

        let add = app.buttons["Add a goal for this session"]
        XCTAssertTrue(add.waitForExistence(timeout: Self.uiTimeout), "the planner never opened")
        add.tap()

        // Template rows combine title and blurb into one label, so they are matched by prefix.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", template)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the template picker never opened")
        row.tap()
        XCTAssertTrue(app.buttons["Normal"].waitForExistence(timeout: Self.uiTimeout),
                      "the goal editor never opened")
    }
}
