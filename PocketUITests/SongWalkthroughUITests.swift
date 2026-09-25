import XCTest

/// The first-song walkthrough on the starter track (ADR 0149, ADR 0220 D3), driven for real: tap
/// Start here, press play, and let the song pause itself on both markers while the Loop taps land.
///
/// The rules are unit-tested (`StarterTrackScriptTests`, `SongWalkthroughTests`). What only a driven
/// run shows is the wiring: that the engine's per-frame tick reaches the model, that the pause
/// actually stops playback and puts the playhead on the marker, that the card follows along, and
/// that the click hint (ADR 0220 D4) arrives with the loop and goes when the click is switched on.
///
/// **It leaves nothing behind**, because this simulator's store is shared with the rest of the suite
/// and `StarterTrackUITests` asserts Binta has no loops and opens at 83 BPM. So it stops short of
/// *Save as loop* — beat 3 and the ceremony are pinned in the unit tests — and puts the speed back
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
}
