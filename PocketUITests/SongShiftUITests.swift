import XCTest

/// **A song raised to meet your tuning** (ADR 0305 D4), driven. What the lines say and how a piece moves are
/// unit-tested (`SongShiftTests`); what only a driven run shows is the wiring: Edit song's stepper writes the
/// song, the song player's strip says so, the chip opens Edit song, and *Back to the recording* takes it off.
///
/// The way in is the naming seed's song (`-seedWatchPiece`), which the seed puts back to *as recorded* on
/// every launch, so a run that stops halfway leaves nothing raised for the next test.
final class SongShiftUITests: UITestCase {

    /// The player loads the song's audio before it shows.
    private let playerTimeout: TimeInterval = 90

    @MainActor
    func testRaisingTheSongMarksThePlayerAndTheMarkOpensEditSong() {
        let app = launchApp(extraArguments: ["-seedWatchPiece"])
        let heading = openPlayer(in: app)
        XCTAssertFalse(heading.label.contains("Raised"), "as recorded, nothing is marked")

        // Song details ▸ Edit ▸ Pitch, raised one semitone.
        heading.press(forDuration: 1.0)
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: Self.uiTimeout), "Song details didn't open")
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit song"].waitForExistence(timeout: Self.uiTimeout),
                      "Edit song didn't open")
        let stepper = app.steppers["songEdit.pitch.stepper"]
        XCTAssertTrue(reveal(stepper, in: app), "no Pitch stepper in Edit song")
        // The + is named *Increment* on some systems and not on others; it's the stepper's second button.
        let named = stepper.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'increment'")).firstMatch
        (named.exists ? named : stepper.buttons.element(boundBy: 1)).tap()
        let line = app.staticTexts["songEdit.pitch.line"]
        XCTAssertTrue(line.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertTrue(line.label.hasPrefix("Up 1 semitone"), "the line reads \(line.label)")
        app.navigationBars["Edit song"].buttons["Done"].tap()
        // Back on Song details, whose own Done is on the left.
        XCTAssertTrue(edit.waitForExistence(timeout: Self.uiTimeout), "Edit song didn't close")
        attach(app, named: "Song details after Done")
        app.buttons["Done"].firstMatch.tap()

        // Back to the player: the strip says it's raised.
        let raised = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Raised 1 semitone")).firstMatch
        XCTAssertTrue(raised.waitForExistence(timeout: Self.uiTimeout), "the song player doesn't mark the shift")
        attach(app, named: "Song player, raised")

        // The mark sits at the strip's trailing edge, under the song's other facts. The strip is one element
        // for VoiceOver, so the mark is tapped where it's drawn.
        raised.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.85)).tap()
        XCTAssertTrue(app.navigationBars["Edit song"].waitForExistence(timeout: Self.uiTimeout),
                      "the mark didn't open Edit song")
        let reset = app.buttons["songEdit.pitch.reset"]
        XCTAssertTrue(reveal(reset, in: app), "no Back to the recording")
        reset.tap()
        app.navigationBars["Edit song"].buttons["Done"].tap()
        XCTAssertTrue(heading.waitForExistence(timeout: Self.uiTimeout))
        let cleared = NSPredicate(format: "NOT (label CONTAINS %@)", "Raised")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: cleared, evaluatedWith: heading)],
                                        timeout: Self.uiTimeout), .completed, "the mark stayed after going back")
    }

    /// Song library ▸ the seeded song: the strip's heading, one element that reads the title first.
    @MainActor
    private func openPlayer(in app: XCUIApplication) -> XCUIElement {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()
        let heading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test,")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: playerTimeout), "the song player never opened")
        return heading
    }

    /// Swipe up until `element` is drawn and hittable. A Form builds its rows only as they come near the
    /// screen, so the Pitch row doesn't exist until Edit song has scrolled: `scrollIntoView` gives up on an
    /// element that doesn't exist yet. On a miss, the tree goes in the report.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists, element.isHittable { return true }
            app.swipeUp(velocity: .slow)
        }
        if element.exists, element.isHittable { return true }
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Tree when \(element) wasn't found"
        tree.lifetime = .keepAlways
        add(tree)
        attach(app, named: "Not found")
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
