import XCTest

/// **Watch it on the neck**, driven (ADR 0254). What lights, what the line says and when the board moves are
/// unit-tested (`PieceNeckTests`); what only a driven run shows is a door, the sheet, and the loop's own clock
/// reaching the neck.
///
/// **The first UI test that plays a loop's audio.** A failure at the play step can be the simulator's audio
/// as much as the sheet, so read the attachment before the code.
///
/// The way in is the naming seed with its six notes placed on the neck (`-seedWatchPiece`): Song library ▸
/// the song ▸ hold the loop ▸ *Watch it on the neck*, or on into *Active listening* ▸ *Saved on this loop*.
/// The seed is put back on each launch, and every other test's launch takes it out.
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

    /// The door under *Saved on this loop* shares its Form row with *Name the notes*, and a row holding two
    /// buttons can fire both on one tap: this one opens the sheet, and Name the notes doesn't come with it or
    /// after it. (`NameTheNotesUITests` taps the other button of the pair.)
    @MainActor
    func testSavedOnThisLoopOpensItAndNotNameTheNotes() {
        let app = openEditLoop()
        let train = app.buttons["Active listening on this loop"]
        XCTAssertTrue(reveal(train, in: app), "no Active listening in Edit loop")
        train.tap()
        XCTAssertTrue(app.navigationBars["Active listening"].waitForExistence(timeout: Self.uiTimeout),
                      "Active listening didn't open")

        let watch = app.buttons["count.saved.watch"]
        XCTAssertTrue(reveal(watch, in: app), "no \(title) under Saved on this loop — did the seed place the notes?")
        watch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: Self.uiTimeout),
                      "\(title) didn't open from Saved on this loop")
        XCTAssertFalse(app.navigationBars["Name the notes"].exists, "the tap opened Name the notes as well")

        app.navigationBars[title].buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Name the notes"].waitForExistence(timeout: 2),
                       "Name the notes opened once the sheet closed: the tap fired both buttons")
    }

    /// **What's picked** on the song map (ADR 0308): the toolbar's **Pick** (ADR 0310 D2), a tap on a piece, then
    /// the bar's **Watch**. (*Pick pieces…* on a piece's hold menu starts the same picking.) The
    /// sheet is headed by what was picked, plays from where it starts, and the riff's notes light as it plays.
    /// The seed's song has no sections, so it picks the riff's piece; what a section's name picks, and what
    /// the sheet is called for two, are unit-tested (`SongMapPickingTests`), as is the merge
    /// (`SectionWatchTests`).
    @MainActor
    func testAPieceWatchedFromThePickingBarLightsItsNotes() {
        let app = launchApp(extraArguments: [UITestHooks.watchPieceArgument])
        openSongDetails(in: app)
        let map = app.buttons["Map the song"]
        XCTAssertTrue(reveal(map, in: app), "Song details has no Map the song")
        // Tapped until the map is up: on the iOS 18 simulator the first tap, just after Song details had
        // risen, was lost and the test waited on a map that never opened.
        let riff = app.buttons["Verse riff, notes"]
        XCTAssertTrue(tap(map, until: riff, in: app), "the riff's piece isn't on the map")
        // Picking from the toolbar (ADR 0310 D2): nothing picked, and a tap on the piece picks it.
        let pick = app.navigationBars["Naming test"].buttons["Pick"]
        XCTAssertTrue(pick.waitForExistence(timeout: Self.uiTimeout), "the map's toolbar has no Pick")
        pick.tap()
        let nothing = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Tap pieces")).firstMatch
        XCTAssertTrue(nothing.waitForExistence(timeout: Self.uiTimeout), "picking didn't start with nothing picked")
        XCTAssertFalse(pick.exists, "Pick stays in the toolbar while picking")
        riff.tap()

        let watch = app.buttons["map.pick.watch"]
        XCTAssertTrue(watch.waitForExistence(timeout: Self.uiTimeout), "no Watch on the picking bar")
        XCTAssertEqual(watch.label, title, "VoiceOver reads Watch by the sheet's full name")
        XCTAssertTrue(watch.isEnabled, "Watch is off with the riff picked")
        attach(app, named: "watch-picking-bar")
        watch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: Self.uiTimeout),
                      "\(title) didn't open from the picking bar")
        XCTAssertTrue(app.staticTexts["Verse riff"].exists, "the sheet isn't headed by what was picked")
        let neck = app.descendants(matching: .any)["watch.neck"]
        XCTAssertEqual(neck.value as? String, "6 on the neck", "the riff's six aren't all on the neck")

        // At the slowest tempo, so the lit stretch outlasts CI's 5–10 s between reads of the neck (PR #403).
        let slower = app.buttons["Slow down"]
        for _ in 0..<20 where slower.isEnabled { slower.tap() }
        XCTAssertFalse(slower.isEnabled, "the tempo didn't reach its slowest")
        let play = app.buttons["watch.play"]
        XCTAssertTrue(play.label.hasPrefix("Play from "), "the button doesn't say where it plays from: \(play.label)")
        let playFrom = play.label
        play.tap()
        XCTAssertTrue(waitForLabel("Stop", on: play, timeout: audioTimeout), "it never started: \(play.label)")
        XCTAssertTrue(waitForValue(of: neck, matching: "value CONTAINS %@", "string, fret", timeout: 90),
                      "the neck never lit the riff as it played: \(String(describing: neck.value))")
        attach(app, named: "watch-picks-playing")
        play.tap()
        XCTAssertTrue(waitForLabel(playFrom, on: play), "it didn't stop: \(play.label)")

        app.navigationBars[title].buttons["Done"].tap()
    }

    // MARK: - The way in

    /// Song library ▸ the seeded song ▸ hold its title for Song details.
    @MainActor
    private func openSongDetails(in app: XCUIApplication) {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()
        let heading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test,")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: playerTimeout), "the song player never opened")
        heading.press(forDuration: 1.0)
    }

    @MainActor
    private func openWatch(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = openEditLoop(file: file, line: line)
        let watch = app.buttons["loopEdit.watch"]
        XCTAssertTrue(reveal(watch, in: app), "no \(title) in Edit loop — did the seed place the notes?",
                      file: file, line: line)
        watch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: Self.uiTimeout),
                      "Watch it on the neck didn't open", file: file, line: line)
        return app
    }

    /// Song library ▸ the seeded song ▸ hold *Verse riff* ▸ Edit loop.
    @MainActor
    private func openEditLoop(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
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
        return app
    }

    /// Wait for `element`'s value to match: what the neck says changes with the loop's clock, so reading it
    /// outright asks what it said at an instant.
    @MainActor
    private func waitForValue(of element: XCUIElement, matching format: String, _ argument: String,
                              timeout: TimeInterval? = nil) -> Bool {
        let settled = expectation(for: NSPredicate(format: format, argument), evaluatedWith: element)
        return XCTWaiter().wait(for: [settled], timeout: timeout ?? audioTimeout) == .completed
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
