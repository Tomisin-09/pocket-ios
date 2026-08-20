import XCTest

/// The manual's **song player** figures (ADR 0165, Phase 5) — the screen itself, its speed bar, the
/// loop controls popover, and the states the transport takes.
///
/// The sheets that open *from* here — Edit loop, Automator, Set tempo — are `ManualLoopSheetShots`.
/// Both ride in the `player` pass, on Slow Bend, which is the song every player figure in the manual
/// is shot on.
///
/// ## Two things about this screen shape every test below
///
/// **It has no navigation bar.** There is a `Back to library` chevron and a title strip, and no
/// `navigationTitle` anywhere — so `capture`'s usual gate has nothing to resolve a title inside, and
/// every figure of the player itself goes through `captureChromeless`. The sheets over it do have
/// bars, and use the ordinary path.
///
/// **The Loops panel is expanded on arrival.** That is not something these tests do; it is the
/// screen's default, which is why `song-player/portrait-idle`, `reference/player` and
/// `reference/loops-panel` are one frame rather than three. The first two describe the same picture
/// at different lengths and the third is a crop of it.
final class ManualPlayerShots: ManualShotCase {

    /// `song-player/portrait-idle` · `reference/player` · `reference/loops-panel` ·
    /// `gestures/speed-bar` — the player as it opens, idle, nothing looping.
    ///
    /// Four markers, one frame, and every one of their subjects is asserted in it rather than assumed
    /// — which is the condition for sharing a frame at all. The speed bar band, the waveform and its
    /// ruler, the transport, and both loop rows: if the screen ever grows enough that the panel falls
    /// off the bottom, this fails instead of filing a `role: panel` crop that lies outside its master.
    ///
    /// `Playback speed 1.00 times` is the state, not decoration. `gestures/speed-bar` asks for the
    /// bar at 100%, and the same bar at any other speed photographs identically apart from two
    /// numbers.
    @MainActor
    func testPlayerIdle() {
        let app = launchForShoot()
        openSlowBend(in: app)

        captureChromeless(app, slug: "song-player/portrait-idle",
                          screen: "the song player",
                          ownedBy: ["Back to library"],
                          alsoRequiring: ["Playback speed 1.00 times", "76 beats per minute",
                                          "Set tempo", "Loop controls", "Waveform", "Song position",
                                          "Loops, expanded", "Play Verse riff", "Play Chorus bend"],
                          orBeginningWith: ["Slow Bend, Jack Trader"],
                          alsoServing: ["reference/player", "reference/loops-panel",
                                        "gestures/speed-bar"])
    }

    /// `looping/speed-bar` — the same bar with the speed pulled below 100%.
    ///
    /// `0.75×` is a preset rather than a drag of the slider: a slider drag lands where the gesture
    /// happens to end, so the readout it produces is not reproducible and the figure would show a
    /// different number every shoot.
    ///
    /// The effective BPM is asserted as `57`, which is 76 × 0.75 — the whole point of the figure is
    /// that the readout follows the speed, so a bar that showed the original tempo at three-quarter
    /// speed would be exactly the wrong picture and would still be a picture of the speed bar.
    @MainActor
    func testSpeedReduced() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let threeQuarters = app.buttons["0.75×"]
        tap(threeQuarters, labelled: "the 0.75× preset",
            revealing: app.buttons["Playback speed 0.75 times"], called: "the reduced speed readout")

        captureChromeless(app, slug: "looping/speed-bar",
                          screen: "the song player, slowed",
                          ownedBy: ["Back to library"],
                          alsoRequiring: ["Playback speed 0.75 times", "57 beats per minute"])
    }

    /// `gestures/loop-controls-popover` — the nine-row popover.
    ///
    /// All nine rows are required in frame. The manual carries a count tripwire for this popover
    /// (`loop-controls-rows = 9` in `gestures.md`, checked by C8 against the source), so the figure
    /// and the prose are already pinned to each other; asserting every row here means the *image*
    /// cannot drift from the count either.
    @MainActor
    func testLoopControlsPopover() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let controls = app.buttons["Loop controls"]
        tap(controls, labelled: "Loop controls",
            revealing: app.staticTexts["Make a loop"], called: "the loop controls popover")

        captureChromeless(app, slug: "gestures/loop-controls-popover",
                          screen: "the loop controls popover",
                          ownedBy: ["Make a loop"],
                          alsoRequiring: ["…or draw it", "Fine-tune", "Re-edit later", "Move around",
                                          "Change the skip", "Set the tempo", "Carry the tempo",
                                          "Follow"])
    }

    /// `gestures/carry-tempo` — the sheet a held BPM readout opens (ADR 0170).
    ///
    /// **The readout is not a button.** It is an `Other` labelled `76 beats per minute`, so
    /// `app.buttons[…]` finds nothing — which is exactly how the first walk of this screen reported
    /// the readout missing from a player it was standing on. Resolved through `descendants` instead.
    ///
    /// The sheet has a navigation bar of its own, so this one takes the ordinary capture path even
    /// though the screen underneath it does not have one.
    @MainActor
    func testCarryTempo() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let readout = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "beats per minute")).firstMatch
        hold(readout, labelled: "the BPM readout",
             revealing: app.navigationBars["Carry this tempo"], called: "the carry-tempo sheet")

        // Both destinations, by the labels the buttons actually carry — they name the tempo being
        // carried, which is the sheet's whole claim, so a prefix would let a sheet that had lost the
        // number pass.
        capture(app, slug: "gestures/carry-tempo",
                assertingOnScreen: "Carry this tempo",
                alsoRequiring: ["Take 76 beats per minute to the metronome",
                                "Start a new exercise at 76 beats per minute"])
    }

    /// `looping/loop-active` · `getting-started/loop-active` — the transport in its looping form.
    ///
    /// Gated on `Looping Verse riff`, which is the transport's own label once a loop is active and
    /// does not exist before. `Deactivate loop` and `Restart` are the two controls the active form
    /// adds, and requiring them is what separates this from a player that is merely playing.
    ///
    /// `getting-started/loop-active` additionally asks for the loop's span drawn across the waveform.
    /// That is drawn, not labelled — there is no accessibility element for it — so it is the one part
    /// of this figure that can only be checked by opening the image.
    @MainActor
    func testLoopActive() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let play = app.buttons["Play Verse riff"]
        tap(play, labelled: "Play Verse riff",
            revealing: app.buttons["Deactivate loop"], called: "the active loop transport")

        captureChromeless(app, slug: "looping/loop-active",
                          screen: "the song player, looping",
                          ownedBy: ["Looping Verse riff"],
                          alsoRequiring: ["Deactivate loop", "Restart", "Waveform"],
                          alsoServing: ["getting-started/loop-active"])
    }

    /// `looping/multi-select` — the Loops panel in selection mode with two loops selected.
    ///
    /// Selection begins on a **long press of the panel header**, not on a row and not from a menu
    /// (`CollapsiblePanelHeader.onBeginSelection`, a 0.4s press). Once it is on, a tap on a row
    /// toggles rather than activates — which is why both loops are selected by tapping them here and
    /// the play controls are not touched.
    @MainActor
    func testMultiSelect() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let header = app.buttons["Loops, expanded"]
        hold(header, labelled: "the Loops panel header",
             revealing: app.buttons["Done selecting"], called: "selection mode")

        for loop in ["Verse riff", "Chorus bend"] {
            let row = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", loop)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout),
                          "no '\(loop)' row to select.\n\(stepLog)")
            row.tap()
            note("selected '\(loop)'")
        }

        captureChromeless(app, slug: "looping/multi-select",
                          screen: "the Loops panel selecting",
                          ownedBy: ["Done selecting"],
                          orBeginningWith: ["Verse riff", "Chorus bend"])
    }

    // MARK: - Navigation

}
