import XCTest

/// **Choosing a moon theme** (ADR 0311 D7, ADR 0312 D1), driven: Settings ▸ Appearance's Theme row
/// opens the Theme screen, a tap applies a card at once with no Save, and the row then says the new
/// theme. Without the plan, Blood Moon still applies and any other card opens the wall.
///
/// The colours themselves are `MoonThemeTests`' and `BrandColorContrastTests`' job; green tests can't
/// see a colour that reads wrong, which is what the phone pass is for. This guards the wiring.
final class ThemeUITests: UITestCase {

    @MainActor
    func testATapAppliesATheme() {
        let app = launchApp()
        let themeRow = openAppearance(in: app)
        XCTAssertTrue(themeRow.label.contains("Blood Moon") || (themeRow.value as? String) == "Blood Moon",
                      "a fresh launch isn't on Blood Moon: \(themeRow.label)")

        XCTAssertTrue(tap(themeRow, until: app.navigationBars["Theme"], in: app), "the Theme screen didn't open")
        let harvest = app.buttons[UITestHooks.themeCard("harvest")]
        XCTAssertTrue(harvest.waitForExistence(timeout: Self.uiTimeout))
        harvest.tap()
        XCTAssertTrue(harvest.isSelected, "Harvest Moon wasn't marked as the theme after the tap")
        XCTAssertFalse(app.buttons[UITestHooks.themeCard("blood")].isSelected, "Blood Moon stayed selected too")

        app.navigationBars["Theme"].buttons.firstMatch.tap()
        let row = app.descendants(matching: .any)[UITestHooks.themeRow]
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertTrue(row.label.contains("Harvest Moon") || (row.value as? String)?.contains("Harvest Moon") == true,
                      "the Theme row doesn't say the theme it applied: \(row.label)")
    }

    @MainActor
    func testWithoutThePlanAThemeOpensTheWall() {
        let app = launchApp(extraArguments: [UITestHooks.planArgument, UITestHooks.planFree])
        let themeRow = openAppearance(in: app)
        XCTAssertTrue(tap(themeRow, until: app.navigationBars["Theme"], in: app), "the Theme screen didn't open")

        // Locked, not hidden: the screen is open, the cards are drawn, and a theme says it needs the plan.
        let cold = app.buttons[UITestHooks.themeCard("cold")]
        XCTAssertTrue(cold.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(cold.value as? String, "Needs the plan", "Cold Moon drew no lock without the plan")
        let blood = app.buttons[UITestHooks.themeCard("blood")]
        XCTAssertNotEqual(blood.value as? String, "Needs the plan", "Blood Moon drew a lock")

        let wall = app.staticTexts[UITestHooks.planWallHeadline]
        XCTAssertTrue(tap(cold, until: wall, in: app), "Cold Moon applied without the plan")
        app.buttons["Not now"].tap()
        XCTAssertTrue(blood.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertTrue(blood.isSelected, "closing the wall left a theme other than Blood Moon applied")
    }

    /// Home → Settings → Appearance, returning the Theme row.
    @MainActor
    private func openAppearance(in app: XCUIApplication) -> XCUIElement {
        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.uiTimeout), "Settings gear missing on Home")
        gear.tap()
        let appearance = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance")).firstMatch
        XCTAssertTrue(tap(appearance, until: app.navigationBars["Appearance"], in: app), "Appearance didn't open")
        let row = app.descendants(matching: .any)[UITestHooks.themeRow]
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "no Theme row on Appearance")
        return row
    }
}
