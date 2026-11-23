import XCTest

/// **Practice as triads opens the form filled in** (ADR 0313 D9), from both doors: the context menu on a
/// row in *My progressions*, and the button on the progression's own screen.
///
/// What the form opens on is unit-tested (`PracticeAsTriadsTests`). What only a driven run can show is that
/// each door reaches the New exercise form and the form shows the seed: named for the progression, on
/// Arpeggios, Triads, with the progression chosen. Two doors, because a half-built door looks finished from
/// the other one. Nothing is created: each form is cancelled, and the progression written here is deleted at
/// the end. The simulator keeps its store, so the progression's name is unique to the run.
final class PracticeAsTriadsUITests: UITestCase {

    @MainActor
    func testBothDoorsOpenTheFormOnTheProgressionAsTriads() throws {
        let app = launchApp()
        openMyProgressions(in: app)
        let name = "Triads door \(Int(Date().timeIntervalSince1970) % 100_000)"
        writeProgression(named: name, in: app)

        // The row's context menu.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the progression just written isn't listed")
        row.press(forDuration: 1.2)
        let menuItem = app.buttons["Practice this progression as triads"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: Self.uiTimeout), "the row's menu has no Practice as triads")
        menuItem.tap()
        assertFormIsFilledIn(for: name, in: app, shot: "practice-as-triads-from-the-menu")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["New arpeggios"]), "Cancel left the form up")

        // The progression's own screen.
        row.tap()
        XCTAssertTrue(app.navigationBars["Edit progression"].waitForExistence(timeout: Self.uiTimeout),
                      "the progression's screen did not open")
        // Below *Any chord*, so off screen at first, where a Form row doesn't exist to XCUI yet.
        let button = app.buttons["progression.practiceAsTriads"]
        XCTAssertTrue(dragIntoReach(button, in: app), "Practice as triads not reachable on its screen")
        XCTAssertEqual(button.label, "Practice this progression as triads")
        attachScreenshot(of: app, named: "practice-as-triads-button")
        button.tap()
        assertFormIsFilledIn(for: name, in: app, shot: "practice-as-triads-from-the-screen")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["New arpeggios"]), "Cancel left the form up")

        // Leave the store as it was found. The last row, so still below the fold on iOS 18.
        let delete = app.buttons["Delete progression"]
        XCTAssertTrue(dragIntoReach(delete, in: app), "Delete progression not reachable by scrolling")
        delete.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.uiTimeout), "Delete didn't ask")
        confirm.tap()
        XCTAssertTrue(app.navigationBars["My progressions"].waitForExistence(timeout: Self.uiTimeout),
                      "deleting didn't return to My progressions")
    }

    /// The form a seed opens: Arpeggios, named for the progression, generating Triads, the progression chosen.
    @MainActor
    private func assertFormIsFilledIn(for name: String, in app: XCUIApplication, shot: String,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["New arpeggios"].waitForExistence(timeout: Self.uiTimeout),
                      "the New exercise form did not open on Arpeggios", file: file, line: line)
        let nameField = app.textFields["e.g. A minor 7 arpeggio"]
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.uiTimeout), "the form has no name field",
                      file: file, line: line)
        XCTAssertEqual(nameField.value as? String, "\(name) as triads", file: file, line: line)
        let triads = app.segmentedControls.buttons["Triads"]
        XCTAssertTrue(triads.waitForExistence(timeout: Self.uiTimeout), "the Shape row isn't showing",
                      file: file, line: line)
        XCTAssertTrue(triads.isSelected, "the form opened on Box, not Triads", file: file, line: line)
        XCTAssertTrue(app.segmentedControls.buttons["Generate"].isSelected, "the form opened on Draw your own",
                      file: file, line: line)
        attachScreenshot(of: app, named: shot)
        // The Progression row is below the fold.
        let progression = app.buttons["triads.progression"]
        XCTAssertTrue(dragUntilItExists(progression, in: app), "the run isn't playing a progression",
                      file: file, line: line)
        XCTAssertEqual(progression.value as? String, name, "the progression chosen isn't this one",
                       file: file, line: line)
    }

    @MainActor
    private func openMyProgressions(in app: XCUIApplication) {
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Toolkit,'")).firstMatch
        XCTAssertTrue(toolkit.waitForExistence(timeout: Self.uiTimeout), "Toolkit card missing on Home")
        XCTAssertTrue(tap(toolkit, until: app.navigationBars["Toolkit"], in: app), "the Toolkit didn't open")
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'My progressions'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "My progressions missing from the Toolkit")
        XCTAssertTrue(tap(row, until: app.navigationBars["My progressions"], in: app),
                      "My progressions didn't open")
    }

    /// G, Em, C in G: the builder opens in G, and its in-key chips come first in the tree, so `firstMatch`
    /// is the in-key chip, not the *Any chord* row's.
    @MainActor
    private func writeProgression(named name: String, in app: XCUIApplication) {
        let new = app.buttons["New progression"].firstMatch
        XCTAssertTrue(new.waitForExistence(timeout: Self.uiTimeout), "New progression missing")
        new.tap()
        let field = app.textFields["progression.builder.name"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "the builder did not open")
        field.tap()
        field.typeText("\(name)\n")
        for label in ["Add G, I", "Add Em, vi", "Add C, IV"] {
            let chip = app.buttons[label].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: Self.uiTimeout), "\(label) missing from the builder")
            XCTAssertTrue(scrollIntoView(chip, in: app), "\(label) not reachable by scrolling")
            chip.tap()
        }
        app.buttons["progression.builder.save"].tap()
        XCTAssertTrue(app.navigationBars["My progressions"].waitForExistence(timeout: Self.uiTimeout),
                      "Save didn't return to My progressions")
    }

    /// Scroll until `element` is in the tree: a Form row below the fold doesn't exist to XCUI until it's
    /// drawn, so `scrollIntoView`, which needs it to exist, can't reach it. Dragged in the margin, since the
    /// form's board and chip strip sit where `swipeUp` would start.
    @MainActor
    private func dragUntilItExists(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.35))
        for _ in 0..<8 where !element.waitForExistence(timeout: 1) {
            low.press(forDuration: 0.05, thenDragTo: high)
        }
        return element.exists
    }

    /// Drag until `element` is drawn and wholly clear of the home indicator, to be tapped. `scrollIntoView`
    /// can't do it here, for two reasons iOS 18 shows on CI: it gives up on a row the Form hasn't drawn yet,
    /// and it stops once the row is `isHittable`, which iOS 18 says of a few points showing under the home
    /// indicator, where a tap goes to the system. Dragged in the margin, as above, and held so the Form
    /// doesn't coast.
    @MainActor
    private func dragIntoReach(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        func inReach() -> Bool {
            guard element.exists, element.isHittable else { return false }
            let window = app.windows.firstMatch.frame
            return element.frame.minY >= window.minY && element.frame.maxY <= window.maxY - 40
        }
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.35))
        for _ in 0..<8 where !inReach() {
            low.press(forDuration: 0.05, thenDragTo: high, withVelocity: .default, thenHoldForDuration: 0.3)
        }
        return inReach()
    }

    /// Kept always: a green run can't see a clipped row, and these are new screens.
    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
