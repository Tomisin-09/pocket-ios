import XCTest

/// The doors ADR 0236 adds, as wiring. `TakeExportTests` covers what a file is called and where it is
/// staged; neither can say whether *Export take…* is on the menu a player holds, or whether tapping it
/// reaches the share sheet. A `ShareLink` inside a `contextMenu` is exactly the kind of thing that can
/// be built right and still do nothing.
///
/// **The share sheet is found by `ActivityListView`**, the identifier UIKit has given its activity
/// sheet since iOS 13. The sheet runs out of process and draws blank in a screenshot, so the tree is
/// the only witness. The file name is checked by its extension rather than its full text, since the
/// date in it is the seed's, and the seed's date is yesterday's.
final class ExportUITests: UITestCase {

    /// Hold the seeded take in the Journal, then **Export take…**, and the share sheet opens on a file.
    @MainActor
    func testATakeInTheJournalExportsFromItsHoldMenu() throws {
        let app = launchApp(extraArguments: ["-seedHistory"])
        let take = try openJournalTake(in: app)

        take.press(forDuration: 1.0)
        let export = app.buttons["Export take…"]
        XCTAssertTrue(export.waitForExistence(timeout: Self.uiTimeout), "the take's hold menu has no Export take…")
        export.tap()

        assertShareSheetOpens(on: ".m4a", in: app)
    }

    /// The take's own screen (ADR 0174) offers the same item in its **Take actions** menu.
    @MainActor
    func testATakesOwnScreenExportsFromItsActionsMenu() throws {
        let app = launchApp(extraArguments: ["-seedHistory"])
        try openJournalTake(in: app).tap()

        // Tapped by coordinate: a toolbar `Menu` is found but never hittable on CI's iOS 18. If the
        // control were really dead the menu wouldn't open, and the next wait fails.
        let actions = app.buttons["Take actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: Self.uiTimeout), "the take's screen did not open")
        actions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let export = app.buttons["Export take…"]
        XCTAssertTrue(export.waitForExistence(timeout: Self.uiTimeout), "Take actions has no Export take…")
        export.tap()

        assertShareSheetOpens(on: ".m4a", in: app)
    }

    // MARK: - Steps

    /// Home → Journal → the seeded take's row, scrolled into reach.
    @MainActor
    private func openJournalTake(in app: XCUIApplication) throws -> XCUIElement {
        let journal = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journal.waitForExistence(timeout: Self.uiTimeout), "no Journal card on Home")
        journal.tap()
        XCTAssertTrue(app.buttons["Journal options"].waitForExistence(timeout: Self.uiTimeout),
                      "the Journal did not open")

        let take = app.buttons[UITestHooks.takeRowOpen].firstMatch
        XCTAssertTrue(take.waitForExistence(timeout: Self.uiTimeout), "no seeded take in the Journal")
        XCTAssertTrue(scrollIntoView(take, in: app), "the seeded take was not reachable")
        return take
    }

    @MainActor
    private func assertShareSheetOpens(on fileExtension: String, in app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: Self.uiTimeout),
                      "Export take… did not open the share sheet")
        let named = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", fileExtension)).firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: Self.uiTimeout),
                      "the share sheet opened, but not on a \(fileExtension) file")
    }
}
