import XCTest

/// The first-song walkthrough on the starter track (ADR 0149, ADR 0220 D3), driven for real: tap
/// Start here, press play, and let the song pause itself on both markers while the Loop taps land. And
/// on any other song, the pointer at the kept loop that follows the ceremony (ADR 0249 D3).
///
/// The rules are unit-tested (`StarterTrackScriptTests`, `SongWalkthroughTests`). What only a driven
/// run shows is the wiring: that the engine's per-frame tick reaches the model, that the pause
/// actually stops playback and puts the playhead on the marker, that the card follows along, and
/// that the click hint (ADR 0220 D4) arrives with the loop and goes when the click is switched on.
///
/// **They leave nothing behind**, because this simulator's store is shared with the rest of the suite
/// and `StarterTrackUITests` asserts Binta has no loops and opens at 83 BPM. So the starter test stops
/// short of *Save as loop* — beat 3 and the ceremony are pinned in the unit tests — and puts the speed back
/// to 1× before it ends, since leaving the screen writes the speed onto the song.
///
/// **Real time:** about eighteen seconds of playback (bar 7 to bar 13 at 83 BPM), which is why the
/// waits below are long. They are waits on the song, not on the app.
final class SongWalkthroughUITests: UITestCase {

    /// Bar 7 to bar 9 is ~5.8 s of song, bar 9 to bar 13 ~11.6 s; both with room for a slow runner.
    private let songTimeout: TimeInterval = 30

    @MainActor
    func testTheStarterTracksFirstLoopClosesOnItsTwoMarkers() {
        let app = launchApp(extraArguments: [UITestHooks.walkthroughArgument])

        let card = app.buttons["Binta by Jack Trader, a song to start on"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout),
                      "No Start here card on Home — does this simulator's store already hold songs?")
        let leadIn = app.staticTexts["Press play. It stops where the chords come in."]
        XCTAssertTrue(tap(card, until: leadIn, in: app) || leadIn.waitForExistence(timeout: Self.uiTimeout),
                      "The walkthrough did not start on the starter track")

        // Full speed, whatever an earlier run left: the pauses are waits on the song itself.
        app.buttons["Reset"].tap()
        app.buttons["Play"].tap()

        // D3 step 2: playback pauses on *Chords start* and the card asks for the tap.
        let atStart = app.staticTexts["Tap Loop. Your loop starts here, right on the beat."]
        XCTAssertTrue(atStart.waitForExistence(timeout: songTimeout), "Playback never paused on Chords start")
        XCTAssertTrue(app.buttons["Play"].exists, "The script said to tap Loop but the song is still playing")
        app.buttons["Loop"].tap()

        // D3 step 4: and again on *Solo start*.
        let atEnd = app.staticTexts["Tap Loop again to close it."]
        XCTAssertTrue(atEnd.waitForExistence(timeout: songTimeout), "Playback never paused on Solo start")
        app.buttons["Loop"].tap()

        // D3 step 5: the four bars loop straight away — bar 9 to bar 13 — and beat 1 is ticked.
        let slowIt = app.staticTexts[
            "Bring the speed down to about half. The pitch holds, so it plays slower, not lower."]
        XCTAssertTrue(slowIt.waitForExistence(timeout: Self.uiTimeout), "Closing the span did not tick Loop it")
        // Reached by content rather than as `staticTexts[…]`: whether the strip's caption surfaces as
        // its own element beside the strip's buttons is SwiftUI's call (see `testABForming`). The
        // strip's `timecode` **rounds**, so Solo start (34.726 s) reads 0:35 — the display cannot
        // tell a landing on the bar line from one 200 ms late; `StarterTrackScriptTests` can.
        let span = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "0:23 – 0:35")).firstMatch
        XCTAssertTrue(span.exists, "The loop did not close on the two markers (bar 9 to bar 13)")

        // ADR 0220 D4: the click hint arrives with the loop, and switching the click on takes it.
        // Matched on content: the hint's row reads as one element, title and body together.
        let clickHint = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Tap the metronome for a click")).firstMatch
        XCTAssertTrue(clickHint.waitForExistence(timeout: Self.uiTimeout), "The click hint did not arrive")
        let metronome = app.buttons["Metronome click"]
        metronome.tap()
        XCTAssertTrue(waitForDisappearance(of: clickHint), "Turning the click on did not take the hint")
        metronome.tap()     // and off again

        // Beat 2 is the player's hand on the speed.
        app.buttons["0.50×"].tap()
        XCTAssertTrue(app.staticTexts["Tap Save as loop, so it's here when you come back."]
                        .waitForExistence(timeout: Self.uiTimeout), "Slowing down did not tick Slow it down")

        // Leave nothing behind (see the class comment): full speed, no span, and the ✕ is permanent.
        app.buttons["Reset"].tap()
        app.buttons["Clear loop"].tap()
        app.buttons["Close the guide"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.buttons["Close the guide"]), "✕ did not close the guide")
    }

    // MARK: - Any song (ADR 0249)

    /// On the player's own song, once the loop is kept and the ceremony closed, the card points at the new
    /// row and says it is held to edit — and finding the hold puts the pointer away. The way in is the
    /// naming seed's song (`-seedNamingPiece`), which is not the starter track.
    ///
    /// It saves a loop, so it deletes it again before it ends, and leaves the screen so the delete's undo
    /// window closes. The ring on Loop during beat 1 is drawn, not announced, so it is checked by eye and
    /// in `StarterTrackHintsTests`, not here.
    @MainActor
    func testOnAnySongTheKeptLoopIsPointedAtAfterTheCeremony() throws {
        let app = launchApp(extraArguments: [UITestHooks.walkthroughArgument, UITestHooks.namingPieceArgument])
        openNamingSong(in: app)

        let loopIt = app.staticTexts["Play the song. Tap Loop where a part you want to learn begins, "
                                     + "and tap it again where it ends."]
        XCTAssertTrue(loopIt.waitForExistence(timeout: songTimeout), "The walkthrough did not start on this song")
        app.buttons["Reset"].tap()
        app.buttons["Play"].tap()
        app.buttons["Loop"].tap()
        XCTAssertTrue(app.staticTexts["Tap Loop again to set the end"].waitForExistence(timeout: Self.uiTimeout))
        Thread.sleep(forTimeInterval: 2)    // a loop wider than the half-second floor (ADR 0199)
        app.buttons["Loop"].tap()

        app.buttons["0.50×"].tap()
        // Its words read *Save as loop*; its label, the one VoiceOver and this query hear, is *Save loop*.
        let save = app.buttons["Save loop"]
        XCTAssertTrue(save.waitForExistence(timeout: Self.uiTimeout), "No Save as loop after slowing down")
        save.tap()
        XCTAssertTrue(app.staticTexts["That's your first loop."].waitForExistence(timeout: Self.uiTimeout),
                      "Saving did not bring the ceremony")
        let hint = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@", "to change its name, its range or how you practise it")).firstMatch
        XCTAssertFalse(hint.exists, "The hint talked over the ceremony (0220)")
        app.buttons["Close the guide"].tap()

        XCTAssertTrue(hint.waitForExistence(timeout: Self.uiTimeout), "No pointer at the kept loop")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "walkthrough-edit-loop-hint"
        shot.lifetime = .keepAlways
        add(shot)
        let name = try XCTUnwrap(hint.label.range(of: #"Hold (.+?) to change"#, options: .regularExpression)
            .map { String(hint.label[$0].dropFirst(5).dropLast(10)) }, hint.label)

        // The hold it names opens the sheet, and that is the hint taken. A loop just saved is playing, so
        // its row reads *Pause*, and *Play* once it stops.
        let row = app.buttons.matching(NSPredicate(format: "label IN %@", ["Play \(name)", "Pause \(name)"]))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "No row for \(name)")
        let sheet = app.navigationBars["Edit loop"]
        XCTAssertTrue(hold(row, opening: sheet), "Holding \(name) didn't open Edit loop")
        sheet.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
        XCTAssertTrue(waitForDisappearance(of: hint), "Finding the hold didn't put the pointer away")

        // Leave nothing behind: the loop goes, the speed comes back, and leaving ends the undo window.
        XCTAssertTrue(hold(row, opening: sheet), "Holding \(name) didn't open Edit loop again")
        // Delete loop is the sheet's last row, under the medium detent's fold. A drag inside the rows
        // raises the sheet; one on its bar doesn't (GestureHintUITests found the same).
        let delete = app.buttons["Delete loop"]
        for _ in 0..<4 where !(delete.exists && delete.isHittable) {
            app.collectionViews.firstMatch.swipeUp()
        }
        delete.tap()
        XCTAssertTrue(waitForDisappearance(of: row), "\(name) wasn't deleted")
        app.buttons["Reset"].tap()
        app.buttons["Back to library"].tap()
    }

    /// Hold `row` until `sheet` opens: once more if the first press opened nothing and the row is still
    /// there to press. Seen 2026-10-03 on the loop just saved, playing: one 1.5 s press opened nothing,
    /// and the same press on the next run did. A press that opened something else covers the row, and
    /// then this stops rather than pressing blind.
    @MainActor
    private func hold(_ row: XCUIElement, opening sheet: XCUIElement) -> Bool {
        for _ in 0..<2 {
            row.press(forDuration: 1.5)
            if sheet.waitForExistence(timeout: 8) { return true }
            guard row.exists, row.isHittable else { return false }
        }
        return false
    }

    /// Home ▸ Song library ▸ the naming seed's song, swiped into view on a used simulator.
    @MainActor
    private func openNamingSong(in app: XCUIApplication) {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        var swipes = 0
        while !song.waitForExistence(timeout: 2), swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        _ = tap(song, until: app.buttons["Back to library"], in: app)
    }
}
