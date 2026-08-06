import XCTest

/// Smoke coverage for the **Toolkit hub** (ADR 0096) — the reference destination added over the last
/// build. The unit suite can't catch broken navigation wiring, so this drives Home → Toolkit and
/// asserts the hub and its two Slice-1 sections (My chords, Glossary) actually appear, then opens My
/// chords. It's a wiring guard, not an exhaustive flow — deliberately light given the sim's cold-start
/// variance.
final class ToolkitUITests: UITestCase {

    @MainActor
    func testToolkitHubOpensAndListsItsSections() throws {
        let app = launchApp()

        // Match by label prefix, not the full subtitle — the card's subtitle changes as the hub grows
        // (it read "chords, scales and theory reference", now "your chords and a music glossary"), and a
        // hard-coded full label made this wiring guard brittle to copy edits.
        let toolkitCard = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(toolkitCard.waitForExistence(timeout: Self.uiTimeout), "Toolkit card missing on Home")
        // Home groups its strips into titled sections (ADR 0102); Toolkit sits in the "Your stuff"
        // section and starts below the fold — scroll it into view before tapping rather than assuming
        // it's on the first screen.
        XCTAssertTrue(scrollIntoView(toolkitCard, in: app), "Toolkit card not reachable by scrolling")
        toolkitCard.tap()

        // The hub pushed onto the home stack (ADR 0096 Slice 1).
        XCTAssertTrue(app.navigationBars["Toolkit"].waitForExistence(timeout: Self.uiTimeout),
                      "Toolkit hub did not appear")

        // Its two Slice-1 sections. The rows are NavigationLinks with a custom accessibility label, so
        // match by label prefix across any element type rather than assuming a button/cell trait.
        let myChordsRow = firstElement(in: app, labelStartingWith: "My chords")
        XCTAssertTrue(myChordsRow.waitForExistence(timeout: Self.uiTimeout), "My chords section missing in Toolkit")
        XCTAssertTrue(firstElement(in: app, labelStartingWith: "Glossary").exists,
                      "Glossary section missing in Toolkit")

        // Opening My chords must land on its own screen — either the populated grid or the empty state.
        myChordsRow.tap()
        let landed = app.navigationBars["My chords"].waitForExistence(timeout: Self.uiTimeout)
            || app.staticTexts["No saved chords yet"].waitForExistence(timeout: Self.uiTimeout)
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
