import XCTest

/// **An audio file shared from another app opens as a song** (ADR 0273). No UI test can drive another
/// app's share sheet (ADR 0264 D10.6), so `-receiveSharedAudio` hands the app a short tone the way the
/// system hands it a shared file. Everything from there is the real path: the receive door, the copy,
/// the decode, the song, and Home pushing its waveform.
final class SharedAudioUITests: UITestCase {

    /// Home is on top at launch, so the song opens straight onto its waveform, titled by its file name,
    /// the way **+** opens a single import (D3). No alert: the screen appearing is the confirmation.
    @MainActor
    func testASharedAudioFileOpensAsASong() throws {
        // Not `launchApp`: it waits for Home's seeding marker, and the song opens over Home, taking the
        // marker out of the tree with it. That is the behaviour under test, not a failure to wait for.
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [UITestHooks.launchArgument, UITestHooks.receiveSharedAudioArgument]
        app.launch()

        let title = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shared tone")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), "the shared file didn't open as a song")
        XCTAssertFalse(app.alerts["Added"].exists, "the song opened, so nothing needs saying")
        XCTAssertFalse(app.alerts["Couldn’t open that file"].exists, "the tone was read as something else")
        // Not walked back to the library: a first import arms the song walkthrough (ADR 0149) over this
        // screen. The waveform is of a stored song, so its opening is the evidence it was kept.
    }

    /// Away from Home the song isn't pushed. The alert names it and offers **Open**, which shows the song
    /// player over the screen the player was on. It rotates there as it does pushed, the one screen
    /// that does (ADR 0042), and its back chevron closes it onto the same screen (D3).
    @MainActor
    func testASharedFileOverAnotherScreenOpensFromTheAlert() throws {
        let app = launchApp(extraArguments: [UITestHooks.receiveSharedAudioOnReturnArgument])
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }

        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")

        // Away to another app and back, as a share from one is.
        XCUIDevice.shared.press(.home)
        app.activate()

        let added = app.alerts["Added"]
        XCTAssertTrue(added.waitForExistence(timeout: 30), "a song shared over the library said nothing")
        let said = added.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "“Shared tone")).firstMatch
        XCTAssertTrue(said.exists, "the alert doesn't name the song")

        // The player's own back chevron, which nothing behind the cover has: the library's row for the
        // song stays in the tree under it, so the title isn't proof of anything.
        let back = app.buttons["Back to library"]
        XCTAssertTrue(tap(added.buttons["Open"], until: back, in: app), "Open didn't show the song player")
        XCTAssertTrue(app.buttons["Play"].exists, "the song player has no transport")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Loops and markers"].waitForExistence(timeout: Self.uiTimeout),
                      "the song player didn't turn to landscape inside its cover")
        XCUIDevice.shared.orientation = .portrait

        // Tapped until it goes: a first import can arm the walkthrough over the player (ADR 0149).
        for _ in 0..<3 where back.exists {
            back.tap()
            if waitForDisappearance(of: back, timeout: 3) { break }
        }
        XCTAssertFalse(back.exists, "Back didn't close the song player")
        XCTAssertTrue(app.navigationBars["Library"].exists, "closing it didn't leave the player where they were")
    }
}
