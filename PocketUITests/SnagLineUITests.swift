import XCTest

/// **A line on a snag**, from the waveform (ADR 0238). The rules — which loop's Journal, which kind, one
/// line read the same from both places — are unit-tested (`SnagLineTests`). What only a driven run shows is
/// the wiring: that a hold on a *Snags* row opens the sheet rather than seeking, and that what's saved there
/// comes back under the row and into the sheet.
///
/// The way in is the naming seed (`-seedNamingPiece`): its song has *Verse riff* and starts every launch
/// with no snags and no notes, so the snag this makes, and its line, are new on every run.
final class SnagLineUITests: UITestCase {

    /// The player loads the song's audio before it shows; generous, as the shoot's is.
    private let playerTimeout: TimeInterval = 90

    @MainActor
    func testHoldingASnagRowLeavesALineUnderIt() {
        let app = openSnagsPanel()
        let hint = app.staticTexts["Hold a snag to leave a line on it, for when you come back."]
        XCTAssertTrue(hint.waitForExistence(timeout: Self.uiTimeout), "no hint while no snag has a line")

        let time = app.staticTexts.matching(identifier: "snags.time").firstMatch
        XCTAssertTrue(reveal(time, in: app), "the snag's row isn't in reach")
        time.press(forDuration: 1.0)

        // Any type: a vertical-axis `TextField` is exposed as a text field on iOS 26 and as a text view on
        // earlier systems (`UITestHooks.routineDescriptionField`), and CI runs iOS 18.
        let field = app.descendants(matching: .any)["snag.lineField"]
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "holding the row didn't open the sheet")
        let words = "The slide into the ninth lands late"
        XCTAssertFalse(app.staticTexts[words].exists, "the line was there before it was written")
        field.tap()
        field.typeText(words)
        attach(app, named: "snag-line-writing")
        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(waitForDisappearance(of: field), "Save didn't close the sheet")
        XCTAssertTrue(app.staticTexts[words].waitForExistence(timeout: Self.uiTimeout), "the line isn't under its row")
        XCTAssertFalse(hint.exists, "the hint stays once a line shows what one is")
        attach(app, named: "snag-line-saved")

        // Back in, the sheet holds what was written.
        XCTAssertTrue(reveal(time, in: app), "the snag's row isn't in reach")
        time.press(forDuration: 1.0)
        XCTAssertTrue(field.waitForExistence(timeout: Self.uiTimeout), "a second hold didn't open the sheet")
        XCTAssertEqual(field.value as? String, words, "the sheet didn't open on the line")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: field), "Cancel didn't close the sheet")
        XCTAssertTrue(app.staticTexts[words].exists, "Cancel took the line away")

        // The marker's sheet moved into the same modifier (`PanelRowSheets`), and no test opened it before.
        let markers = app.buttons["Markers, collapsed"]
        XCTAssertTrue(reveal(markers, in: app), "no Markers panel")
        markers.tap()
        let marker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Go to ")).firstMatch
        XCTAssertTrue(reveal(marker, in: app), "no marker row in reach")
        marker.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Edit marker"].waitForExistence(timeout: Self.uiTimeout),
                      "holding a marker row didn't open Edit marker")
        app.navigationBars["Edit marker"].buttons["Cancel"].tap()
    }

    // MARK: - The way in

    /// Song library ▸ the seeded song ▸ play *Verse riff* ▸ **Snag** ▸ pause ▸ open *Snags*.
    @MainActor
    private func openSnagsPanel(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument], file: file, line: line)

        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home",
                      file: file, line: line)
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open",
                      file: file, line: line)

        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library",
                      file: file, line: line)
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable", file: file, line: line)
        song.tap()
        XCTAssertTrue(app.buttons["Back to library"].waitForExistence(timeout: playerTimeout),
                      "the song player never opened", file: file, line: line)

        let play = app.buttons["Play Verse riff"]
        XCTAssertTrue(play.waitForExistence(timeout: Self.uiTimeout), "no Verse riff row", file: file, line: line)
        play.tap()
        let snag = app.buttons["Snag"]
        XCTAssertTrue(snag.waitForExistence(timeout: Self.uiTimeout), "no Snag button with the loop running",
                      file: file, line: line)
        snag.tap()
        // Stop the playhead: a screen redrawing every frame makes every query after this wait on it.
        let pause = app.buttons["Pause Verse riff"]
        if pause.waitForExistence(timeout: 2) { pause.tap() }

        let header = app.buttons["Snags, collapsed"]
        XCTAssertTrue(reveal(header, in: app), "no Snags panel", file: file, line: line)
        header.tap()
        XCTAssertTrue(app.buttons["Snags, expanded"].waitForExistence(timeout: Self.uiTimeout),
                      "the Snags panel didn't open", file: file, line: line)
        return app
    }

    /// Drag the panels up until `element` is drawn and in reach. The drag starts low, in the panels' own
    /// scroll view: a swipe across the middle of the screen lands on the waveform, which scrubs.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<8 {
            if inReach(element, in: app) { return true }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
        }
        return inReach(element, in: app)
    }

    /// Whole on screen and clear of the home indicator: iOS 18 calls an element hittable with a sliver of
    /// it showing there, and the touch goes to the system (`NameTheNotesUITests.inReach`).
    @MainActor
    private func inReach(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let window = app.windows.firstMatch.frame
        return element.frame.minY >= window.minY && element.frame.maxY <= window.maxY - 40
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
