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
        // name alone matches two buttons. The picker's list is the one holding the *New skill* row —
        // never its *Your own* header: iOS 18 reads a section header back in capitals ("YOUR OWN")
        // where iOS 26 does not, so a header match passes locally and finds nothing on CI.
        let pickerList = app.collectionViews.containing(.button, identifier: "New skill").firstMatch
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
        // Works on is one tap down since ADR 0258, on Feel & skills; the row's label carries its value.
        let feel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Feel & skills")).firstMatch
        XCTAssertTrue(reveal(feel, in: app), "the ⓘ sheet has no Feel & skills row")
        XCTAssertTrue(tap(feel, until: app.navigationBars["Feel & skills"], in: app), "Feel & skills didn't open")

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
        // Back to the sheet, whose Done closes it: a pushed screen carries no Done of its own.
        app.navigationBars["Feel & skills"].buttons.firstMatch.tap()
        app.buttons["Done"].tap()
    }

    /// ADR 0309 D4: making a *Your own practice* drill, **Works on** can be set before Create, and the pick
    /// lands back in the form. The picker is a sheet over the form, and a sheet's write is the part that has
    /// broken before on iOS 18. Nothing is created: the sheet is cancelled, so the library is untouched.
    @MainActor
    func testWorksOnCanBeSetWhileMakingYourOwnPractice() {
        let app = launchApp()
        openNewExerciseSheet(in: app)
        // Last in the template list, so it isn't in the tree until the list is scrolled to it; the shared
        // `chooseTemplate` asks for the row before it scrolls, which only works for rows near the top.
        let freeform = app.buttons["template.freeform"]
        XCTAssertTrue(reveal(freeform, in: app), "Your own practice isn't in the template list")
        freeform.tap()

        let addSkills = app.buttons["Add skills"]
        XCTAssertTrue(reveal(addSkills, in: app), "making Your own practice offers no Works on")
        addSkills.tap()
        let picker = app.navigationBars["Works on"]
        XCTAssertTrue(picker.waitForExistence(timeout: Self.uiTimeout), "Add skills opened no picker")
        let skill = app.buttons["Alternate picking"]
        XCTAssertTrue(reveal(skill, in: app), "Alternate picking isn't in the picker")
        skill.tap()
        XCTAssertTrue(skill.isSelected, "the tap didn't pick the skill")
        picker.buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: picker), "the picker didn't close on Done")

        let row = app.staticTexts["Alternate picking"]
        XCTAssertTrue(reveal(row, in: app), "the picked skill didn't land in Works on")
        XCTAssertTrue(app.buttons["Change skills"].exists, "Works on still offers Add rather than Change")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "create-form-works-on"
        shot.lifetime = .keepAlways
        add(shot)

        // Back to the template picker, whose Cancel closes the sheet without making anything.
        app.navigationBars.buttons.firstMatch.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.uiTimeout), "no way out of the create sheet")
        cancel.tap()
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
        openPracticeLibrary("Exercises", in: app)
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
