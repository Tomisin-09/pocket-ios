import XCTest

/// **The way off the keyboard** (`KeyboardDismissAccessory`), driven on the metronome — the screen it
/// was reported missing from (device, iOS 26.6), and the screen where the accessory it replaced drew
/// four checkmarks at once with the automator on, one for the screen and one per number field.
///
/// Counted, not just found: "a checkmark exists" passed with four of them.
final class KeyboardDismissUITests: UITestCase {

    /// Computed, not stored: `NSPredicate` is not `Sendable`, so a stored static fails Swift 6.
    private static var checkmark: NSPredicate { NSPredicate(format: "label == %@", "Dismiss keyboard") }

    @MainActor
    func testTheMetronomesNumberFieldsHaveOneCheckmarkThatCommits() throws {
        let app = launchApp()
        let card = app.buttons["Metronome, standalone click and tempo trainer"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout), "no Metronome tile on Home")
        XCTAssertTrue(scrollIntoView(card, in: app), "Metronome tile not reachable by scrolling")
        card.tap()

        // The tempo: a number pad, so no Return key — the checkmark is the only way off.
        let tempo = app.textFields["Tempo in beats per minute"]
        XCTAssertTrue(tempo.waitForExistence(timeout: Self.uiTimeout), "the metronome did not open")
        tempo.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: Self.uiTimeout))
        // No deletes first: focusing empties the field (its old value becomes the prompt), so typing
        // replaces. This test found that — it typed into `|90` and got 12090, clamped to 300.
        tempo.typeText("120")

        let checkmarks = app.buttons.matching(Self.checkmark)
        XCTAssertTrue(checkmarks.firstMatch.waitForExistence(timeout: Self.uiTimeout),
                      "no checkmark above the tempo's number pad")
        XCTAssertEqual(checkmarks.count, 1)
        // The transport steps aside while typing, so the field isn't squeezed against it.
        XCTAssertFalse(app.buttons["Start"].exists, "Start stayed pinned above the keyboard")

        checkmarks.firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch), "the checkmark left the keyboard up")
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: Self.uiTimeout),
                      "Start did not come back with the keyboard gone")
        let committed = expectation(for: NSPredicate(format: "value == %@", "120"), evaluatedWith: tempo)
        XCTAssertEqual(XCTWaiter().wait(for: [committed], timeout: Self.uiTimeout), .completed,
                       "dismissing did not commit the typed tempo — the field reads \(String(describing: tempo.value))")

        // The automator's fields: three of them, and the old accessory drew a checkmark for each.
        app.buttons["By Bars"].tap()
        let interval = app.textFields["Interval"]
        XCTAssertTrue(interval.waitForExistence(timeout: Self.uiTimeout), "the automator did not arm")
        interval.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertTrue(checkmarks.firstMatch.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(checkmarks.count, 1, "one checkmark, however many fields the screen holds")
        checkmarks.firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(of: app.keyboards.firstMatch))
    }
}
