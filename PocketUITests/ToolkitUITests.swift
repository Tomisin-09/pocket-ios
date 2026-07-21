import XCTest

/// Smoke coverage for the **Toolkit hub** (ADR 0096) — the reference destination added over the last
/// build. The unit suite can't catch broken navigation wiring, so this drives Home → Toolkit and
/// asserts the hub and its two Slice-1 sections (My chords, Glossary) actually appear, then opens My
/// chords. It's a wiring guard, not an exhaustive flow — deliberately light given the sim's cold-start
/// variance.
final class ToolkitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testToolkitHubOpensAndListsItsSections() throws {
        let app = XCUIApplication()
        app.launch()

        let toolkitCard = app.buttons["Toolkit, chords, scales and theory reference"]
        XCTAssertTrue(toolkitCard.waitForExistence(timeout: 5), "Toolkit card missing on Home")
        // Home groups its strips into titled sections (ADR 0102); Toolkit sits in the "Your stuff"
        // section and starts below the fold — scroll it into view before tapping rather than assuming
        // it's on the first screen.
        var swipes = 0
        while !toolkitCard.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(toolkitCard.isHittable, "Toolkit card not reachable by scrolling")
        toolkitCard.tap()

        // The hub pushed onto the home stack (ADR 0096 Slice 1).
        XCTAssertTrue(app.navigationBars["Toolkit"].waitForExistence(timeout: 5),
                      "Toolkit hub did not appear")

        // Its two Slice-1 sections. The rows are NavigationLinks with a custom accessibility label, so
        // match by label prefix across any element type rather than assuming a button/cell trait.
        let myChordsRow = firstElement(in: app, labelStartingWith: "My chords")
        XCTAssertTrue(myChordsRow.waitForExistence(timeout: 5), "My chords section missing in Toolkit")
        XCTAssertTrue(firstElement(in: app, labelStartingWith: "Glossary").exists,
                      "Glossary section missing in Toolkit")

        // Opening My chords must land on its own screen — either the populated grid or the empty state.
        myChordsRow.tap()
        let landed = app.navigationBars["My chords"].waitForExistence(timeout: 5)
            || app.staticTexts["No saved chords yet"].waitForExistence(timeout: 5)
        XCTAssertTrue(landed, "My chords screen did not appear")
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
