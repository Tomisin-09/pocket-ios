import XCTest

/// Smoke coverage for the **Settings hub** (ADR 0162) — the destinations that replaced the flat
/// thirteen-section `Form`. The unit suite can't catch broken navigation wiring, and until this ADR
/// `PocketUITests` referenced Settings nowhere at all, so a mis-wired row would have shipped silently.
///
/// Deliberately light, in the shape of `ToolkitUITests`: it drives Home → Settings, asserts the
/// preference rows exist, and opens two of them. It is a wiring guard, not an exhaustive flow — the
/// values themselves are `AppSettingsTests`' job, and over-specifying labels here is what makes a
/// guard brittle to copy edits.
final class SettingsHubUITests: UITestCase {

    @MainActor
    func testSettingsHubOpensAndListsItsDestinations() throws {
        let app = launchApp()

        // The gear in the Home toolbar (ADR 0050 — a push, not a sheet).
        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.uiTimeout), "Settings gear missing on Home")
        gear.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.uiTimeout),
                      "Settings hub did not appear")

        // The rows are NavigationLinks wrapping a LabeledContent, so match by label prefix across any
        // element type rather than assuming a button/cell trait (the ToolkitUITests lesson).
        for title in ["You", "Red Moon Pro", "Appearance", "Sound & feel",
                      "Practice", "Routines", "Song player", "Privacy", "Help & About"] {
            XCTAssertTrue(firstElement(in: app, labelStartingWith: title).waitForExistence(timeout: Self.uiTimeout),
                          "\(title) row missing from the Settings hub")
        }
    }

    /// Opening a destination must land on its own screen — the half a hub can get wrong that merely
    /// rendering the rows does not prove.
    @MainActor
    func testSettingsDestinationsPush() throws {
        let app = launchApp()

        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.uiTimeout), "Settings gear missing on Home")
        gear.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.uiTimeout),
                      "Settings hub did not appear")

        // Privacy, because ADR 0162 D7 rests on this control staying reachable — it is the DUAA
        // "simple, free means of objecting", and a broken push would quietly remove it.
        let privacyRow = firstElement(in: app, labelStartingWith: "Privacy")
        XCTAssertTrue(privacyRow.waitForExistence(timeout: Self.uiTimeout), "Privacy row missing")
        privacyRow.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: Self.uiTimeout),
                      "Privacy screen did not appear")
        app.navigationBars["Privacy"].buttons.firstMatch.tap()

        // Sound & feel, because it hosts the metronome picker the same ADR restyled (D5/D6).
        let soundRow = firstElement(in: app, labelStartingWith: "Sound & feel")
        XCTAssertTrue(soundRow.waitForExistence(timeout: Self.uiTimeout), "Sound & feel row missing")
        XCTAssertTrue(scrollIntoView(soundRow, in: app), "Sound & feel row not reachable by scrolling")
        soundRow.tap()
        XCTAssertTrue(app.navigationBars["Sound & feel"].waitForExistence(timeout: Self.uiTimeout),
                      "Sound & feel screen did not appear")
    }

    /// The first element of any type whose accessibility label begins with `prefix` — robust to whether
    /// a `NavigationLink` surfaces as a button, cell or other element.
    @MainActor
    private func firstElement(in app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }
}
