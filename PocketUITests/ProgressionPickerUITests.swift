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

    @MainActor
    private func openSheet(_ use: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(scrollIntoView(use, in: app), "Use a progression not reachable by scrolling")
        use.tap()
        XCTAssertTrue(app.buttons["progression.add"].waitForExistence(timeout: Self.uiTimeout),
                      "the progression sheet did not open")
    }
}
