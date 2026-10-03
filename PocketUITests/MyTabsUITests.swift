import XCTest

/// **My tabs and the writer**, driven (ADR 0235). The rules are unit-tested (`TabDraftTests`,
/// `TabContentTests`); what only a driven run shows is the wiring: a tap on the shared neck filling the +,
/// the strip saying so and keeping the + in sight, the tab kept on its first note, and the list it lands in.
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

        write("G string, fret 2,", as: "Note 1, G2", at: 0, in: app)
        write("G string, fret 4,", as: "Note 2, G4", at: 1, in: app)

        app.buttons["tab.barLine"].tap()
        let bar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Bar line before the next note you write")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: Self.uiTimeout), "no bar line in the strip")
        app.buttons["tab.undo"].tap()
        XCTAssertTrue(waitForDisappearance(of: bar), "↶ didn't take the bar line back")

        // Six more run the strip past the screen's width. The + stays the lit chip as it moves on, so it
        // has to be followed for its own sake, or it walks off the right edge (it did, 2026-10-03).
        let more = [("D", 2), ("D", 4), ("A", 2), ("A", 3), ("B", 1), ("B", 3)]
        for (offset, (string, fret)) in more.enumerated() {
            let index = offset + 2
            write("\(string) string, fret \(fret),", as: "Note \(index + 1), \(string)\(fret)", at: index, in: app)
        }
        let slot = app.descendants(matching: .any)["tab.slot"]
        let inSight = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: slot)
        XCTAssertEqual(XCTWaiter().wait(for: [inSight], timeout: Self.uiTimeout), .completed,
                       "the + went off the strip's edge")
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
        XCTAssertTrue(words.label.contains("8 notes"), words.label)
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
        write("B string, fret 3,", as: "Note 1, B3", at: 0, in: app)
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
        // Retried like the card: a tap as the Toolkit slid in opened nothing, once in each test (2026-10-03).
        XCTAssertTrue(tap(row, until: app.navigationBars["My tabs"], in: app), "My tabs didn't open",
                      file: file, line: line)
    }

    @MainActor
    private func spot(_ prefix: String, in app: XCUIApplication) -> XCUIElement {
        let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(spot.waitForExistence(timeout: Self.uiTimeout), "no \(prefix) on the neck")
        return spot
    }

    /// Tap a spot on the neck and wait for it to fill chip `index`, as `label`. Tapped again only while that
    /// chip doesn't exist: a tap as the writer arrived filled nothing, once in each test (2026-10-03). A slow
    /// first tap that lands after the second makes two notes, and the next call's label check fails on it.
    @MainActor
    private func write(_ prefix: String, as label: String, at index: Int, in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) {
        let filled = chip(index, in: app)
        for _ in 0..<2 where !filled.exists {
            spot(prefix, in: app).tap()
            _ = filled.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(waitForLabel(label, on: filled), "the tap didn't write note \(index + 1)", file: file, line: line)
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
