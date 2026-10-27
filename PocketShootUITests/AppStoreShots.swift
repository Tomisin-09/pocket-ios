import XCTest

/// The App Store frames no manual figure already shows (ADR 0279).
///
/// Most of the App Store set is the manual's own captures, re-run on the Pro Max simulator. Two frames
/// need a state the manual never photographs, so they live here and the manual's classes stay the
/// manual's:
///
/// - **Work it out**: *Binta*'s *Chords* loop playing at 0.75×. The manual shows the loop and the
///   slower speed as two separate figures.
/// - **Run it**: *Open mic, Friday*, the seeded routine built for something coming up
///   (`PracticeHistorySeed+Authored`).
///
/// Driven only by `POCKET_SHOOT_ONLY=AppStoreShots ./scripts/shoot-manual.sh`. No pass of the full
/// shoot names this class, so these never land in the manual's `filed/` set.
final class AppStoreShots: ManualShotCase {
    /// The loop is started **before** the speed is set, because starting a loop can apply the speed
    /// the loop was saved at.
    @MainActor
    func testWorkItOut() {
        let app = launchForShoot()
        openHeroSong(in: app)

        tap(app.buttons["Play Chords"], labelled: "Play Chords",
            revealing: app.buttons["Deactivate loop"], called: "the active loop transport")
        tap(app.buttons["0.75×"], labelled: "the 0.75× preset",
            revealing: app.buttons["Playback speed 0.75 times"], called: "the reduced speed readout")

        captureChromeless(app, slug: "appstore/work-it-out",
                          screen: "the song player, looping and slowed",
                          ownedBy: ["Looping Chords"],
                          alsoRequiring: ["Deactivate loop", "Playback speed 0.75 times", "Waveform"])
    }

    /// The routine's own screen, opened the way `ManualRoutineShots` opens *Morning Routine*. That
    /// class's `openRoutines` is its own extension's, so the two steps are spelled out here.
    @MainActor
    func testRunIt() {
        let app = launchForShoot()

        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])
        tapRow(labelStartingWith: "Routines,", in: app,
               arrivingAt: app.navigationBars["Routines"], called: "the Routines library")
        tapRow(labelStartingWith: "Open mic, Friday", in: app,
               arrivingAt: app.navigationBars["Open mic, Friday"], called: "Open mic, Friday")

        capture(app, slug: "appstore/run-it", assertingOnScreen: "Open mic, Friday",
                orBeginningWith: ["Pop Changes"])
    }
}
