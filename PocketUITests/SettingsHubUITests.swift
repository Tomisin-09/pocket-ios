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
        for title in ["You", "Appearance", "Sound & feel",
                      "Practice", "Routines", "Song player", "Your data", "Help & About"] {
            XCTAssertTrue(firstElement(in: app, labelStartingWith: title).waitForExistence(timeout: Self.uiTimeout),
                          "\(title) row missing from the Settings hub")
        }
        // Privacy held one control, the analytics switch, and went with analytics (ADR 0239). Asserted
        // after the rows above have rendered, so its absence is a fact about a loaded hub rather than
        // about one still arriving.
        XCTAssertFalse(firstElement(in: app, labelStartingWith: "Privacy").exists,
                       "a Privacy row is back on the Settings hub, with nothing behind it to control")
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

        // Your data, because it is where a player's only copy of their library is made (ADR 0181), and
        // a broken push would quietly take that away. It sits where Privacy did until ADR 0239.
        let dataRow = firstElement(in: app, labelStartingWith: "Your data")
        XCTAssertTrue(dataRow.waitForExistence(timeout: Self.uiTimeout), "Your data row missing")
        dataRow.tap()
        XCTAssertTrue(app.navigationBars["Your data"].waitForExistence(timeout: Self.uiTimeout),
                      "Your data screen did not appear")
        app.navigationBars["Your data"].buttons.firstMatch.tap()

        // Sound & feel, because it hosts the metronome picker the same ADR restyled (D5/D6).
        let soundRow = firstElement(in: app, labelStartingWith: "Sound & feel")
        XCTAssertTrue(soundRow.waitForExistence(timeout: Self.uiTimeout), "Sound & feel row missing")
        XCTAssertTrue(scrollIntoView(soundRow, in: app), "Sound & feel row not reachable by scrolling")
        soundRow.tap()
        XCTAssertTrue(app.navigationBars["Sound & feel"].waitForExistence(timeout: Self.uiTimeout),
                      "Sound & feel screen did not appear")
    }

    /// **Help & About carries the rating door** (ADR 0214 D8). Asserted here rather than left to the
    /// manual's C9 check, which proves only that the *string* exists in the source — not that the row
    /// is reachable, which is the half this class exists for.
    ///
    /// The label only. Following the `Link` is impossible: it leaves the app for the App Store, where
    /// XCUITest cannot go. Nor can any test assert the *other* half of ADR 0214 — whether iOS drew the
    /// system prompt — because `requestReview()` never reports back.
    @MainActor
    func testHelpAndAboutOffersAWayToRate() throws {
        let app = launchApp()

        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.uiTimeout), "Settings gear missing on Home")
        gear.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.uiTimeout),
                      "Settings hub did not appear")

        let aboutRow = firstElement(in: app, labelStartingWith: "Help & About")
        XCTAssertTrue(aboutRow.waitForExistence(timeout: Self.uiTimeout), "Help & About row missing")
        XCTAssertTrue(scrollIntoView(aboutRow, in: app), "Help & About row not reachable by scrolling")
        aboutRow.tap()
        XCTAssertTrue(app.navigationBars["Help & About"].waitForExistence(timeout: Self.uiTimeout),
                      "Help & About screen did not appear")

        let rateRow = firstElement(in: app, labelStartingWith: "Rate Red Moon")
        XCTAssertTrue(rateRow.waitForExistence(timeout: Self.uiTimeout),
                      "Rate Red Moon row missing from Help & About")

        // The screen itself, so a layout regression in this section is visible rather than inferred
        // from a label existing — the row sits between Diagnostics and the two legal links.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "help-and-about"
        shot.lifetime = .keepAlways
        add(shot)
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
