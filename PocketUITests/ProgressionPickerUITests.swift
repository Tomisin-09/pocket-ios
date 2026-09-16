import XCTest

/// **Use a progression fills the drill being built** (ADR 0218).
///
/// Which chords a progression resolves to is unit-tested (`ProgressionInsertTests`). What only a UI test
/// can see is the round trip: the sheet opens from the editor, *Add* writes rows back through the
/// editor's binding, and a drill that already has chords asks before anything is replaced. Rows are
/// counted by their *Swap chord* buttons — one per chord row — never by section header text, which
/// iOS 18 capitalises.
final class ProgressionPickerUITests: UITestCase {

    @MainActor
    func testAProgressionFillsTheDrillAndAReplaceAsksFirst() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)
        chooseTemplate("chords", in: app)

        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Swap chord '"))
        let use = app.buttons["progression.use"]
        XCTAssertTrue(use.waitForExistence(timeout: Self.uiTimeout), "Use a progression missing from the editor")
        let before = rows.count

        // First insert — into an empty drill, so no question is asked.
        openSheet(use, in: app)
        let addButton = app.buttons["progression.add"]
        XCTAssertEqual(addButton.label, "Add 4 chords", "the sheet should open on the four-chord loop")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "use-a-progression-sheet"
        shot.lifetime = .keepAlways
        add(shot)
        addButton.tap()

        XCTAssertTrue(app.buttons["Swap chord Em"].waitForExistence(timeout: Self.uiTimeout),
                      "the four-chord loop in G did not land in the drill")
        XCTAssertEqual(rows.count - before, 4, "I – V – vi – IV should add exactly four rows")

        // Second insert — the drill has chords now, so Add must ask.
        openSheet(use, in: app)
        let threeChords = app.buttons["progression.template.one-four-five"]
        XCTAssertTrue(threeChords.waitForExistence(timeout: Self.uiTimeout), "I – IV – V row missing")
        threeChords.tap()
        XCTAssertEqual(addButton.label, "Add 3 chords")
        addButton.tap()

        let replace = app.buttons["Replace them"]
        XCTAssertTrue(replace.waitForExistence(timeout: Self.uiTimeout),
                      "a drill that already has chords added to without asking")
        replace.tap()

        XCTAssertTrue(waitForDisappearance(of: app.buttons["Swap chord Em"]),
                      "Replace kept the chords it should have replaced")
        XCTAssertEqual(rows.count - before, 3, "Replace should leave exactly the three new chords")
    }

    /// **A progression written mid-drill is selected and adds** (ADR 0218 D10) — the builder opens from
    /// the sheet, a name and two tapped chords save, the sheet comes back with it chosen, and *Add*
    /// writes exactly those chords. The simulator keeps its store between runs, so earlier runs' saved
    /// progressions are still listed; the assertions are about the one just written and the row delta.
    @MainActor
    func testAProgressionWrittenMidDrillIsSelectedAndAdds() throws {
        let app = launchApp()
        openNewExerciseSheet(in: app)
        chooseTemplate("chords", in: app)

        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Swap chord '"))
        let use = app.buttons["progression.use"]
        XCTAssertTrue(use.waitForExistence(timeout: Self.uiTimeout), "Use a progression missing from the editor")
        let before = rows.count
        openSheet(use, in: app)

        let write = app.buttons["progression.new"]
        XCTAssertTrue(write.waitForExistence(timeout: Self.uiTimeout), "New progression missing from the sheet")
        XCTAssertTrue(scrollIntoView(write, in: app), "New progression not reachable by scrolling")
        write.tap()

        let name = app.textFields["progression.builder.name"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.uiTimeout), "the builder did not open")
        name.tap()
        name.typeText("Changes test\n")

        // The builder opens in G. In-key chips come first in the tree, so `firstMatch` is the in-key
        // Em and C, not the any-chord row's.
        for label in ["Add Em, vi", "Add C, IV"] {
            let chip = app.buttons[label].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: Self.uiTimeout), "\(label) missing from the builder")
            XCTAssertTrue(scrollIntoView(chip, in: app), "\(label) not reachable by scrolling")
            chip.tap()
        }
        attachScreenshot(of: app, named: "progression-builder")
        app.buttons["progression.builder.save"].tap()

        // The sheet's Add button is in the tree the whole time the builder is over it, so wait for the
        // builder to go and for the label to settle — not for an element that never left.
        XCTAssertTrue(waitForDisappearance(of: app.buttons["progression.builder.save"]),
                      "the builder did not close on Save")
        let addButton = app.buttons["progression.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.uiTimeout), "the sheet did not come back")
        XCTAssertTrue(waitForLabel("Add 2 chords", on: addButton),
                      "the progression just written should be the selection, not \(addButton.label)")
        attachScreenshot(of: app, named: "sheet-with-a-written-progression")
        addButton.tap()

        XCTAssertTrue(app.buttons["Swap chord Em"].waitForExistence(timeout: Self.uiTimeout),
                      "the written progression did not land in the drill")
        XCTAssertEqual(rows.count - before, 2)
    }

    /// Kept always: a green run can't see a clipped row or a crowded diagram, and these are new screens.
    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    private func openSheet(_ use: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(scrollIntoView(use, in: app), "Use a progression not reachable by scrolling")
        use.tap()
        XCTAssertTrue(app.buttons["progression.add"].waitForExistence(timeout: Self.uiTimeout),
                      "the progression sheet did not open")
    }
}
