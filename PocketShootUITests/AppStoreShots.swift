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
/// - **Keep it (the log)**: the Practice log stepped back one week. The seed is dated back from the
///   real day, so the current week holds only the days gone by, and a shoot on a Monday drew one bar
///   (2026-11-16). Last week is always whole, whatever day the shoot runs.
///
/// Driven only by `POCKET_SHOOT_ONLY=AppStoreShots ./scripts/shoot-manual.sh`. No pass of the full
/// shoot names this class, so these never land in the manual's `filed/` set.
final class AppStoreShots: ManualShotCase {
    /// The loop is started **before** the speed is set, because starting a loop can apply the speed
    /// the loop was saved at. The gridlines are switched off last: at App Store size the waveform reads
    /// clearer without them (Tomisin, 2026-10-27), and requiring *Show gridlines* keeps a frame with
    /// the grid still on from passing.
    @MainActor
    func testWorkItOut() {
        let app = launchForShoot()
        openHeroSong(in: app)

        tap(app.buttons["Play Chords"], labelled: "Play Chords",
            revealing: app.buttons["Deactivate loop"], called: "the active loop transport")
        tap(app.buttons["0.75×"], labelled: "the 0.75× preset",
            revealing: app.buttons["Playback speed 0.75 times"], called: "the reduced speed readout")
        // The grid is a stored setting, so a moon run's later passes on the same device find it off
        // already, with no *Hide gridlines* to tap (`ManualShotCase+Moon`, 2026-11-25).
        let gridOff = app.buttons["Show gridlines"]
        if gridOff.exists {
            note("the gridlines are already off, as an earlier pass left them")
        } else {
            tap(app.buttons["Hide gridlines"], labelled: "the Grid chip",
                revealing: gridOff, called: "the gridlines switched off")
        }

        captureChromeless(app, slug: "appstore/work-it-out",
                          screen: "the song player, looping and slowed",
                          ownedBy: ["Looping Chords"],
                          alsoRequiring: ["Deactivate loop", "Playback speed 0.75 times", "Waveform",
                                          "Show gridlines"])
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

    /// Reached the way `ManualShotsUITests.testPracticeLog` reaches it, from Home's *This week* strip,
    /// then one tap on *Earlier week*. The gate is the **This week** button the header shows once it
    /// has left the current week: it isn't there on the week the log opens on, so a swallowed tap
    /// can't pass as last week.
    @MainActor
    func testKeepItLog() {
        let app = launchForShoot()

        let door = app.buttons[UITestHooks.practiceLogDoor]
        XCTAssertTrue(door.waitForExistence(timeout: Self.shootTimeout),
                      "the This week strip never appeared on Home. \(stepLog)")
        tap(door, labelled: "This week",
            revealing: app.navigationBars["Practice log"], called: "the Practice log screen")
        tap(app.buttons["Earlier week"], labelled: "Earlier week",
            revealing: app.buttons["This week"], called: "last week, with the way back to this one")

        capture(app, slug: "appstore/keep-it-log", assertingOnScreen: "Practice log",
                alsoRequiring: ["This week", "What you played"])
    }

    /// **Build it up**, on a drill that draws the neck: an A minor 7 arpeggio running, past the count-in.
    ///
    /// The manual's `exercises/run-live` is *Alternate Picking*, a tempo drill with no board, so the
    /// frame was the tempo and the staircase over half a phone of black. Running, an arpeggio draws its
    /// walking board between the two, so the frame shows the neck *and* the click climbing.
    ///
    /// The drill is **made here, through New exercise**, the way a player makes one: a fresh install
    /// seeds seven exercises and no arpeggio (`PracticePresets.firstRunSlugs`), so the catalog's
    /// *A Minor 7 Arpeggio* is in no library a new player has. The form opens on A minor 7 for guitar
    /// (`ConfigureExerciseForm.seededArpeggio`), so the name says what is drawn. Create opens the new
    /// drill's run screen (`NewExerciseFlow`). Waiting for `Counting in` to go is the same gate
    /// `ManualExerciseShots.testRunLive` uses, for its reason: a capture on arrival is a clean
    /// photograph of a screen counting down.
    @MainActor
    func testBuildItUpArpeggio() {
        let app = launchForShoot()
        openExercises(in: app)

        // Gated on the picker's own bar, not on its Arpeggios row: that row is eighth of ten, below the
        // sheet's fold, where a List row isn't built and so doesn't exist to XCUI. Gating on it re-tapped
        // the toolbar's +, which a sheet leaves in the tree, three times behind the open picker.
        tap(app.buttons["New exercise"], labelled: "New exercise",
            revealing: app.navigationBars["New exercise"], called: "the template picker")
        let arpeggios = app.buttons["template.arpeggios"]
        scrollIntoFrame(arpeggios, called: "the Arpeggios template", in: app)
        tap(arpeggios, labelled: "the Arpeggios template",
            revealing: app.navigationBars["New arpeggios"], called: "the New arpeggios form")
        let name = app.textFields["e.g. A minor 7 arpeggio"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.shootTimeout),
                      "the New arpeggios form has no name field.\n\(stepLog)")
        // A tap doesn't always give the field focus, and typing without it fails outright ("Neither
        // element nor any descendant has keyboard focus"): two runs in eight on 2026-11-25. So tap
        // until it has focus, as `tap` retries a swallowed tap, then type.
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for attempt in 1...3 {
            name.tap()
            let wait = expectation(for: focused, evaluatedWith: name)
            if XCTWaiter().wait(for: [wait], timeout: Self.tapProbeTimeout) == .completed { break }
            note("tap \(attempt) on the name field didn't give it focus")
        }
        name.typeText("A Minor 7 Arpeggio")
        note("named the drill 'A Minor 7 Arpeggio'")
        tap(app.navigationBars["New arpeggios"].buttons["Create"], labelled: "Create",
            revealing: app.buttons["Exercise details"], called: "the new drill's run screen")

        tap(app.buttons["Start training routine"], labelled: "Start training",
            revealing: app.buttons["Stop and reset"], called: "the running transport")
        let countingIn = app.staticTexts["Counting in"]
        if countingIn.exists {
            note("counting in — waiting for it to finish")
            XCTAssertTrue(waitForDisappearance(of: countingIn, timeout: Self.shootTimeout), """
                the count-in never finished, so this would have been shot mid-count.
                \(stepLog)
                """)
        }

        capture(app, slug: "appstore/build-it-up-arpeggio",
                assertingOnScreen: "A Minor 7 Arpeggio",
                alsoRequiring: ["Stop and reset", "Pause"],
                orBeginningWith: ["BPM ·"])
    }

    /// Home in each of the eight moons (ADRs 0311, 0312), for the site's theme picker and the
    /// listing's themes frame.
    ///
    /// The moon rides in on the **launch arguments** (`-moonTheme jade`), which `UserDefaults` reads
    /// ahead of anything the app stored. A `-uiTesting` launch's `AppSettings.resetMoonTheme()` removes
    /// only the stored value, so the argument still wins on this launch and nothing is left behind: the
    /// next launch, this test's or any other, is Blood Moon again (a theme left on the simulator has
    /// hung the unit-test host before). `moonTheme` is `AppSettings.Key.moonTheme`; the raw values are
    /// `MoonTheme`'s cases, which this target can't see. A wrong key or name shoots Blood Moon under
    /// that moon's name, which is why the eight are looked at before they're used.
    @MainActor
    func testHomeInEachMoon() {
        for moon in ["blood", "blue", "jade", "corn", "silver", "pink", "harvest", "cold"] {
            let app = launchForShoot(seeding: ["-moonTheme", moon])
            capture(app, slug: "appstore/home-\(moon)",
                    assertingOnScreen: "Red Moon",
                    alsoRequiring: ["JUMP BACK IN", "Good morning"])
            app.terminate()
        }
    }

    /// Home ▸ Practice ▸ Exercises, gated the way `ManualExerciseShots` gates it: the hub's navigation
    /// bar, then the library's.
    @MainActor
    private func openExercises(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])
        tapRow(labelStartingWith: "Exercises,", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the exercise library")
    }
}
