import XCTest

/// ADR 0216 slice 2 — shaping what a drill is for. Two journeys, and each leaves the simulator's
/// store as it found it, because the store outlives the run (a leftover skill or an edited seed drill
/// would change the next run's starting point):
///
/// 1. A skill **made** from the goal editor's picker shows the player's own words behind its ⓘ, and
///    is then deleted from the same picker.
/// 2. A seeded drill **narrowed** away from one of its type's skills says *Set by you*, and the reset
///    takes it back to *From its type*.
final class SkillsYouShapeUITests: UITestCase {

    @MainActor
    func testASkillYouMakeShowsYourOwnWordsBehindItsInfoButton() {
        let app = launchApp()
        // Title *and* blurb: a saved goal from the same template is listed behind the picker as
        // "Build speed, 3 skills, NORMAL", so the title alone can match that row instead.
        openNewGoalEditor(from: "Build speed, Push picking", in: app)
        // Unique per run: a name already taken offers no way to make it again.
        let name = "Looping \(UUID().uuidString.prefix(4))"
        let description = "Layering parts with a pedal"

        let addSkills = app.buttons["Add skills"]
        XCTAssertTrue(reveal(addSkills, in: app), "the goal editor has no Add skills")
        addSkills.tap()
        let newSkill = app.buttons["New skill"]
        XCTAssertTrue(newSkill.waitForExistence(timeout: Self.uiTimeout), "the picker offers no way to make a skill")
        newSkill.tap()

        let form = app.navigationBars["New skill"]
        XCTAssertTrue(form.waitForExistence(timeout: Self.uiTimeout), "New skill opened no form")
        type(name, into: field(labelled: "Skill name", in: app))
        type(description, into: field(labelled: "What it is", in: app))
        form.buttons["Save"].tap()

        // The picker is a sheet over the editor, and a kept skill is a row in both at once, so the
        // name alone matches two buttons. The picker's list is the one with a *Your own* section.
        let pickerList = app.collectionViews.containing(.staticText, identifier: "Your own").firstMatch
        let made = pickerList.buttons[name]
        XCTAssertTrue(made.waitForExistence(timeout: Self.uiTimeout), "the new skill isn't in the picker")
        XCTAssertTrue(made.isSelected, "a skill made from the picker is kept straight away")
        app.navigationBars["Add skills"].buttons["Done"].tap()

        let row = app.buttons[name]
        XCTAssertTrue(reveal(row, in: app), "the new skill isn't a row in the goal")
        app.buttons["About \(name)"].tap()
        let words = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", description)).firstMatch
        XCTAssertTrue(words.waitForExistence(timeout: Self.uiTimeout), "the ⓘ doesn't show the player's words")
        let dismiss = app.otherElements["PopoverDismissRegion"]
        if dismiss.exists { dismiss.tap() }
        XCTAssertTrue(waitForDisappearance(of: words), "the explanation didn't close")

        // Leave the store as it was: delete the skill where it was made.
        XCTAssertTrue(reveal(addSkills, in: app), "Add skills went missing")
        addSkills.tap()
        let listed = pickerList.buttons[name]
        XCTAssertTrue(listed.waitForExistence(timeout: Self.uiTimeout), "the skill isn't under Your own")
        listed.swipeLeft()
        app.buttons["Delete"].tap()
        let confirm = app.buttons["Delete skill"]
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.uiTimeout), "delete asked for no confirmation")
        confirm.tap()
        XCTAssertTrue(waitForDisappearance(of: listed), "the deleted skill is still listed")
        app.navigationBars["Add skills"].buttons["Done"].tap()
        XCTAssertFalse(app.buttons[name].exists, "the goal still offers a deleted skill")
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testNarrowingADrillSaysSetByYouAndTheResetGoesBack() {
        let app = launchApp()
        openExerciseDetail(named: "Alternate Picking", in: app)

        let change = app.buttons["Change skills"]
        XCTAssertTrue(reveal(change, in: app), "no Works on section on a Picking drill")
        change.tap()

        let picker = app.navigationBars["Works on"]
        XCTAssertTrue(picker.waitForExistence(timeout: Self.uiTimeout), "Change skills opened no picker")
        let alternate = app.buttons["Alternate picking"]
        XCTAssertEqual(alternate.value as? String, "From its type", "a type's skill isn't badged as one")
        XCTAssertTrue(alternate.isSelected)
        alternate.tap()
        XCTAssertFalse(alternate.isSelected, "the tap didn't drop the skill")
        picker.buttons["Done"].tap()

        let setByYou = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Set by you.")).firstMatch
        XCTAssertTrue(reveal(setByYou, in: app), "a narrowed drill doesn't say it was set by the player")
        let reset = app.buttons["Use its type’s skills"]
        XCTAssertTrue(reveal(reset, in: app), "a narrowed drill offers no way back to its type")
        reset.tap()

        let fromType = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "From its type")).firstMatch
        XCTAssertTrue(fromType.waitForExistence(timeout: Self.uiTimeout), "the reset didn't go back to the type")
        XCTAssertFalse(reset.exists, "the reset is still offered after resetting")
        app.buttons["Done"].tap()
    }

    // MARK: - Steps

    /// Home → Practice → Today's session → Add a goal → the template whose row label starts with
    /// `prefix`, stopping on the editor.
    @MainActor
    private func openNewGoalEditor(from prefix: String, in app: XCUIApplication) {
        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(tap(practice, until: app.navigationBars["Practice"], in: app), "the Practice tap never landed")
        let planner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Today's session")).firstMatch
        XCTAssertTrue(planner.waitForExistence(timeout: Self.uiTimeout), "no Today's session row")
        planner.tap()
        let add = app.buttons["Add a goal for this session"]
        XCTAssertTrue(add.waitForExistence(timeout: Self.uiTimeout), "the planner never opened")
        add.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the template picker never opened")
        row.tap()
        XCTAssertTrue(app.buttons["Normal"].waitForExistence(timeout: Self.uiTimeout), "the goal editor never opened")
    }

    /// Home → Practice → Exercises → the named drill's run screen → its ⓘ sheet.
    @MainActor
    private func openExerciseDetail(named name: String, in app: XCUIApplication) {
        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(tap(practice, until: app.navigationBars["Practice"], in: app), "the Practice tap never landed")
        let exercises = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercises.waitForExistence(timeout: Self.uiTimeout), "no Exercises row")
        exercises.tap()
        let drill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no \(name) drill in the library")
        drill.tap()
        let info = app.buttons["Exercise details"]
        XCTAssertTrue(info.waitForExistence(timeout: Self.uiTimeout), "the run screen never opened")
        info.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: Self.uiTimeout), "the ⓘ sheet never opened")
    }

    /// Swipes until the element is on screen. A `Form` builds its rows lazily, so a row below the fold
    /// isn't in the tree until it is scrolled to — and `scrollIntoView` gives up on an element that
    /// doesn't exist yet before its first swipe.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// A text field or, for a multi-line one, a text view — SwiftUI's `axis: .vertical` field is
    /// exposed as the latter.
    @MainActor
    private func field(labelled label: String, in app: XCUIApplication) -> XCUIElement {
        let view = app.textViews[label]
        return view.waitForExistence(timeout: 2) ? view : app.textFields[label]
    }

    @MainActor
    private func type(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: Self.uiTimeout), "no field to type into")
        element.tap()
        element.typeText(text)
    }
}
