import XCTest

/// **The tile beside Toolkit**, driven (ADR 0235 D6): it opens My tabs, says *Hold to change* until it has
/// been changed, and a hold picks another Toolkit tool, which it then names and opens. The launch resets
/// the choice under `-uiTesting` (`AppSettings.resetHomeTool`), so this starts from My tabs every run and
/// leaves nothing for the next test.
final class HomeToolTileUITests: UITestCase {

    @MainActor
    func testHoldingTheTilePicksWhatItOpens() {
        let app = launchApp()
        let tile = app.buttons["home.toolTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: Self.uiTimeout), "no tile beside Toolkit")
        XCTAssertTrue(scrollIntoView(tile, in: app), "the tile beside Toolkit isn't reachable")
        XCTAssertEqual(tile.label, "My tabs, tabs you write on the neck", "it opens My tabs until changed")
        XCTAssertTrue(app.staticTexts["Hold to change"].exists, "no caption before it's been changed")

        tile.press(forDuration: 1.2)
        let glossary = app.buttons["Glossary"].firstMatch
        XCTAssertTrue(glossary.waitForExistence(timeout: Self.uiTimeout), "holding the tile showed no menu")
        attach(app, named: "home-tool-menu")
        if glossary.isHittable {
            glossary.tap()
        } else {
            // A menu row CI's iOS 18 finds but won't call hittable; a tap at its centre lands all the same.
            glossary.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(waitForLabel("Glossary, chord, scale and theory terms", on: tile),
                      "the tile didn't take the tool's name: \(tile.label)")
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["Hold to change"]), "the caption stayed")
        tile.tap()
        XCTAssertTrue(app.navigationBars["Glossary"].waitForExistence(timeout: Self.uiTimeout),
                      "the tile didn't open the tool it names")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
