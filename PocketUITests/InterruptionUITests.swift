import XCTest

/// **A call pauses the transport**, on screen (ADR 0323). Before it, a call or another app's audio left
/// every transport reading as playing over the silence it had made: ■ up on the song player, *Stop the
/// loop* on Active listening, *Pause* on the Metronome.
///
/// A simulator can't ring, so the test stands in for the call: it posts a Darwin notification, and the
/// app (Debug, `-uiTesting`) answers with the interruption the system posts (`UITestInterruptionDrill`).
/// Everything from there to the screen is the real code. One test per engine owner a player sees most:
/// the song player (`PracticeAudioEngine` itself), Active listening (through `LoopRunModel` and
/// `ContinuousLoopPlayer`), and the Metronome (`StandaloneMetronomeEngine`). The engines' own rules are
/// unit-tested (`InterruptionPausesTheTransportTests`).
final class InterruptionUITests: UITestCase {

    /// The player loads the song's audio before it shows; generous, as the shoot's is.
    private let playerTimeout: TimeInterval = 90

    /// The stand-in for a call.
    private func ring() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(UITestHooks.interruptAudioNotification as CFString),
                                             nil, nil, true)
    }

    @MainActor
    func testACallPausesTheSongPlayer() {
        let app = openSongPlayer()

        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: Self.uiTimeout), "Play didn't play")
        ring()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: Self.uiTimeout),
                      "the song player's ■ stayed up after the call")
        attach(app, named: "interruption-song-player")
    }

    @MainActor
    func testACallStopsActiveListeningsLoop() {
        let app = openSongPlayer()
        let loop = app.buttons["Play Verse riff"]
        XCTAssertTrue(loop.waitForExistence(timeout: Self.uiTimeout), "no Verse riff row")
        loop.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Edit loop"].waitForExistence(timeout: Self.uiTimeout),
                      "holding the loop didn't open Edit loop")
        let listen = app.buttons["Active listening on this loop"]
        XCTAssertTrue(dragUntilInReach(listen, in: app), "no Active listening in Edit loop")
        listen.tap()
        XCTAssertTrue(app.navigationBars["Active listening"].waitForExistence(timeout: Self.uiTimeout),
                      "Active listening didn't open")

        let play = app.buttons["Play the loop"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: Self.uiTimeout), "no Play the loop")
        play.tap()
        let stop = app.buttons["Stop the loop"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: playerTimeout), "the loop didn't start")
        ring()
        XCTAssertTrue(app.buttons["Play the loop"].firstMatch.waitForExistence(timeout: Self.uiTimeout),
                      "Active listening still offered Stop the loop after the call")
        attach(app, named: "interruption-active-listening")
    }

    /// A pause, not a stop: the sitting's time and a ramp's plateau are kept, so Resume carries on.
    @MainActor
    func testACallPausesTheMetronomeAndResumeCarriesOn() {
        let app = launchApp()
        let card = app.buttons["Metronome, standalone click and tempo trainer"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout), "no Metronome tile on Home")
        XCTAssertTrue(scrollIntoView(card, in: app), "Metronome tile not reachable by scrolling")
        card.tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: Self.uiTimeout), "the metronome did not open")

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: Self.uiTimeout), "Start did not start")
        ring()
        let resume = app.buttons["Resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: Self.uiTimeout), "the Metronome still read Pause after the call")
        attach(app, named: "interruption-metronome")

        resume.tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: Self.uiTimeout), "Resume didn't resume")
        app.buttons["Stop and reset"].tap()
    }

    // MARK: - Helpers

    /// The seeded *Naming test* song, whose *Verse riff* is a real loop of real audio (`-seedNamingPiece`).
    @MainActor
    private func openSongPlayer() -> XCUIApplication {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument])
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()
        XCTAssertTrue(app.buttons["Back to library"].waitForExistence(timeout: playerTimeout),
                      "the song player never opened")
        return app
    }

    /// Drag a half-height sheet's Form up until `element` is whole on screen and clear of the home
    /// indicator, where iOS 18 calls a sliver of a button hittable and gives the tap to the system.
    /// `NameTheNotesUITests.reveal`'s rule, for the one row this class needs.
    @MainActor
    private func dragUntilInReach(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        func inReach() -> Bool {
            guard element.exists, element.isHittable else { return false }
            return element.frame.maxY <= app.windows.firstMatch.frame.maxY - 40
        }
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<12 where !inReach() {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
        }
        return inReach()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
