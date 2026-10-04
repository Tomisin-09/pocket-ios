import XCTest

/// **Watch it on the neck**, driven (ADR 0254). What lights, what the line says and when the board moves are
/// unit-tested (`PieceNeckTests`); what only a driven run shows is a door, the sheet, and the loop's own clock
/// reaching the neck.
///
/// **The first UI test that plays a loop's audio.** A failure at the play step can be the simulator's audio
/// as much as the sheet, so read the attachment before the code.
///
/// The way in is the naming seed with its six notes placed on the neck (`-seedWatchPiece`): Song library ▸
/// the song ▸ hold the loop ▸ *Watch it on the neck*. The seed is put back on each launch, and every other
/// test's launch takes it out.
final class WatchOnNeckUITests: UITestCase {

    /// The player loads the song's audio before it shows; generous, as the shoot's is.
    private let playerTimeout: TimeInterval = 90
    /// The loop's own audio loads on the first play, then waits for the pass's first tap.
    private let audioTimeout: TimeInterval = 30
    /// The sheet's title, which its navigation bar is found by: the UI test target can't see the app's.
    private let title = "Watch it on the neck"

    /// Stopped, the neck holds the lick and says how much of it is there (D4); playing, the note being heard
    /// is what it says; stopped again, it goes back.
    @MainActor
    func testTheNeckLightsTheHeardNoteAndGoesBackWhenStopped() {
        let app = openWatch()
        let neck = app.descendants(matching: .any)["watch.neck"]
        XCTAssertTrue(neck.waitForExistence(timeout: Self.uiTimeout), "no neck on the sheet")
        XCTAssertEqual(neck.value as? String, "6 on the neck", "stopped, it says what's on the neck")
        attach(app, named: "watch-stopped")

        let play = app.buttons["watch.play"]
        XCTAssertTrue(play.waitForExistence(timeout: Self.uiTimeout), "no play button")
        XCTAssertEqual(play.label, "Play the loop")
        play.tap()
        XCTAssertTrue(waitForLabel("Stop the loop", on: play, timeout: audioTimeout),
                      "the loop never started: \(play.label)")

        // Every one of the seed's six is on the neck, so whichever is heard first reads "… string, fret …".
        XCTAssertTrue(waitForValue(of: neck, matching: "value CONTAINS %@", "string, fret"),
                      "the neck never lit a note as the loop played: \(String(describing: neck.value))")
        attach(app, named: "watch-playing")

        play.tap()
        XCTAssertTrue(waitForLabel("Play the loop", on: play), "the loop didn't stop: \(play.label)")
        XCTAssertTrue(waitForValue(of: neck, matching: "value == %@", "6 on the neck"),
                      "stopping didn't put the neck back: \(String(describing: neck.value))")

        app.navigationBars[title].buttons["Done"].tap()
    }

    // MARK: - The way in

    @MainActor
    private func openWatch(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(extraArguments: [UITestHooks.watchPieceArgument], file: file, line: line)

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

        let loop = app.buttons["Play Verse riff"]
        XCTAssertTrue(loop.waitForExistence(timeout: Self.uiTimeout), "no Verse riff row", file: file, line: line)
        loop.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Edit loop"].waitForExistence(timeout: Self.uiTimeout),
                      "holding the loop didn't open Edit loop", file: file, line: line)

        let watch = app.buttons["loopEdit.watch"]
        XCTAssertTrue(reveal(watch, in: app), "no \(title) in Edit loop — did the seed place the notes?",
                      file: file, line: line)
        watch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: Self.uiTimeout),
                      "Watch it on the neck didn't open", file: file, line: line)
        return app
    }

    /// Wait for `element`'s value to match: what the neck says changes with the loop's clock, so reading it
    /// outright asks what it said at an instant.
    @MainActor
    private func waitForValue(of element: XCUIElement, matching format: String, _ argument: String) -> Bool {
        let settled = expectation(for: NSPredicate(format: format, argument), evaluatedWith: element)
        return XCTWaiter().wait(for: [settled], timeout: audioTimeout) == .completed
    }

    /// Drag up until `element` is drawn and in reach, as `NameTheNotesUITests` does it: a Form draws its rows
    /// only as they come near the screen, and Edit loop opens at half height, where `swipeUp()` lands on the
    /// sheet's top edge rather than its rows. Each drag holds at its end, so the Form stops where it's left.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        _ = element.waitForExistence(timeout: 2)
        for attempt in 0..<12 {
            if inReach(element, in: app) { return true }
            let start = attempt.isMultiple(of: 2) ? 0.85 : 0.55
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start - 0.4)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
        }
        return inReach(element, in: app)
    }

    /// Whole on screen and 40 points clear of the home indicator: iOS 18 calls a button hittable with 11
    /// points of it showing at the foot of the screen, and a tap there goes to the system.
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
