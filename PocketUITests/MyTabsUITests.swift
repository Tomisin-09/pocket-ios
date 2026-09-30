import XCTest

/// **My tabs and the writer**, driven (ADR 0235). The rules are unit-tested (`TabDraftTests`,
/// `TabContentTests`); what only a driven run shows is the wiring: a tap on the shared neck filling the +,
/// the strip saying so, the tab kept on its first note, and the list it lands in.
///
/// The simulator keeps its store between runs, so this asserts a **delta** (a row more than before), and
/// takes its tab back out at the end.
final class MyTabsUITests: UITestCase {

    @MainActor
    func testWritingATabAddsItToMyTabs() {
        let app = launchApp()
        openMyTabs(in: app)
        let before = app.cells.count

        app.navigationBars["My tabs"].buttons["New tab"].tap()
        XCTAssertTrue(app.navigationBars["New tab"].waitForExistence(timeout: Self.uiTimeout), "the writer didn't open")

        spot("G string, fret 2,", in: app).tap()
        XCTAssertTrue(waitForLabel("Note 1, G2", on: chip(0, in: app)), "the tap didn't write note 1")
        spot("G string, fret 4,", in: app).tap()
        XCTAssertTrue(waitForLabel("Note 2, G4", on: chip(1, in: app)), "the + didn't move on to note 2")

        app.buttons["tab.barLine"].tap()
        let bar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Bar line before the next note you write")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: Self.uiTimeout), "no bar line in the strip")
        app.buttons["tab.undo"].tap()
        XCTAssertTrue(waitForDisappearance(of: bar), "↶ didn't take the bar line back")
        attach(app, named: "my-tabs-writer")

        app.navigationBars["New tab"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["My tabs"].waitForExistence(timeout: Self.uiTimeout))
        let written = app.cells.element(boundBy: 0)
        XCTAssertTrue(written.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(app.cells.count, before + 1, "the tab wasn't kept")
        // A cell's own label is empty; the row's words are on the link inside it.
        let words = written.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Untitled tab")).firstMatch
        XCTAssertTrue(words.exists, "the new tab isn't the top row")
        XCTAssertTrue(words.label.contains("2 notes"), words.label)
        attach(app, named: "my-tabs-list")

        // Leave nothing behind: delete it, and leave the screen, which closes the undo window.
        written.swipeLeft()
        app.buttons["Delete Untitled tab"].firstMatch.tap()
        app.navigationBars["My tabs"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Toolkit"].waitForExistence(timeout: Self.uiTimeout))
    }

    /// A tab opens to read, with Edit into the writer (ADR 0235 D2).
    @MainActor
    func testATabOpensToReadWithEdit() {
        let app = launchApp()
        openMyTabs(in: app)
        app.navigationBars["My tabs"].buttons["New tab"].tap()
        XCTAssertTrue(app.navigationBars["New tab"].waitForExistence(timeout: Self.uiTimeout))
        spot("B string, fret 3,", in: app).tap()
        XCTAssertTrue(waitForLabel("Note 1, B3", on: chip(0, in: app)))
        app.navigationBars["New tab"].buttons["Done"].tap()

        let written = app.cells.element(boundBy: 0)
        XCTAssertTrue(written.waitForExistence(timeout: Self.uiTimeout))
        written.tap()
        XCTAssertTrue(app.buttons["tab.edit"].waitForExistence(timeout: Self.uiTimeout), "no Edit on the tab")
        XCTAssertTrue(app.descendants(matching: .any)["piece.tab"].exists, "the tab isn't drawn")
        app.buttons["tab.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit tab"].waitForExistence(timeout: Self.uiTimeout), "Edit didn't open it")
        XCTAssertEqual(chip(0, in: app).label, "Note 1, B3")

        // Back out to the list and take it out again.
        app.navigationBars["Edit tab"].buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["My tabs"].waitForExistence(timeout: Self.uiTimeout))
        let row = app.cells.element(boundBy: 0)
        row.swipeLeft()
        app.buttons["Delete Untitled tab"].firstMatch.tap()
        app.navigationBars["My tabs"].buttons.element(boundBy: 0).tap()
    }

    // MARK: - The way in

    @MainActor
    private func openMyTabs(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(toolkit.waitForExistence(timeout: Self.uiTimeout), "no Toolkit on Home", file: file, line: line)
        XCTAssertTrue(tap(toolkit, until: app.navigationBars["Toolkit"], in: app), "the Toolkit didn't open",
                      file: file, line: line)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My tabs,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "no My tabs row", file: file, line: line)
        row.tap()
        XCTAssertTrue(app.navigationBars["My tabs"].waitForExistence(timeout: Self.uiTimeout), "My tabs didn't open",
                      file: file, line: line)
    }

    @MainActor
    private func spot(_ prefix: String, in app: XCUIApplication) -> XCUIElement {
        let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(spot.waitForExistence(timeout: Self.uiTimeout), "no \(prefix) on the neck")
        return spot
    }

    @MainActor
    private func chip(_ index: Int, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["tab.chip.\(index)"]
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
