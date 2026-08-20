import XCTest

/// The manual's **routine** figures (ADR 0165, Phase 5) — the editor a routine is built in, and the
/// three screens a routine shows while it is being played.
///
/// Its own pass, on its own erased device, because both halves write: saving a routine adds a fourth
/// to a library `routines/library` shows with three, and playing one to the end logs practice history
/// that changes the Journal, the Progress bars and the Practice hub's counts. On a shared device
/// those writes land in the store the read-only figures are shot from.
///
/// **Each half is one test, and that is load-bearing.** A routine editor with three blocks in it, a
/// repeat sheet over that editor, and the rest-insert mode over the same list are three states of one
/// thing built in sequence; so are the three screens of a play-through. XCTest picks the order of
/// test methods, so a state built in one and photographed in another is a figure whose correctness
/// depends on somebody else's alphabet.
final class ManualRoutineShots: ManualShotCase {

    /// `routines/editor` · `routines/repeat-block` · `routines/rest-insert` — building one.
    ///
    /// Three blocks are added in a **single visit** to the Add sheet. It tracks what has been picked
    /// (`addedPickIDs`) and stays open, so three rows can be tapped and the sheet dismissed once —
    /// which is three taps instead of nine, and nine taps through a sheet that opens and closes is
    /// three times the chance of losing one.
    ///
    /// Nothing is saved. The editor works in an editing sandbox and `Cancel` discards it, so this
    /// leaves the library with the three routines the seed wrote — which is what `routines/library`,
    /// shot in the `base` pass, is a picture of.
    @MainActor
    func testEditorStates() {
        let app = launchForShoot()
        openRoutines(in: app)

        tap(app.buttons["New routine"], labelled: "New routine",
            revealing: app.buttons["Add exercise, loop or song"], called: "the routine editor")

        addThreeBlocks(in: app)

        // The blocks are numbered and the estimate is derived from them, so both are asserted: an
        // editor that took the picks but did not re-flow would look almost right.
        capture(app, slug: "routines/editor",
                assertingOnScreen: "Routine",
                alsoRequiring: ["Name", "Blocks", "Add exercise, loop or song", "Insert rest"],
                orBeginningWith: ["Estimated length"])

        // A block tap opens the reps editor (ADR 0076). It is a detent sheet with no navigation bar,
        // so it takes the chromeless path; `Repeat this block` is the stepper's own label and exists
        // nowhere else.
        let block = element(in: app, labelStartingWith: "1.")
        tap(block, labelled: "the first block",
            revealing: app.staticTexts["Repeat this block"], called: "the reps editor")

        // Three, because the marker asks for ×3 in the frame. Read back after each tap rather than
        // tapping twice and trusting the count — a stepper is where the shoot lost a tap before and
        // landed on 95 BPM instead of 90, which photographs exactly as confidently.
        let increment = app.steppers.firstMatch.buttons.element(boundBy: 1)
        for target in ["×2", "×3"] {
            XCTAssertTrue(increment.waitForExistence(timeout: Self.shootTimeout),
                          "no increment on the reps stepper.\n\(stepLog)")
            increment.tap()
            note("tapped the reps stepper, expecting \(target)")
            XCTAssertTrue(app.staticTexts[target].waitForExistence(timeout: Self.shootTimeout), """
                the reps stepper did not reach \(target) — a lost tap here photographs as \
                confidently as the right number.
                \(stepLog)
                """)
        }

        captureChromeless(app, slug: "routines/repeat-block",
                          screen: "the reps editor",
                          ownedBy: ["Repeat this block"],
                          alsoRequiring: ["×3"])

        app.swipeDown(velocity: .fast)
        note("dismissed the reps editor")

        // Rest-insert mode is entered by **holding** Insert rest, which turns the gaps between blocks
        // into targets under a header naming what to do.
        let insertRest = element(in: app, labelStartingWith: "Insert rest")
        hold(insertRest, labelled: "Insert rest",
             revealing: app.staticTexts["Tap where a rest goes"], called: "rest-insert mode")

        capture(app, slug: "routines/rest-insert",
                assertingOnScreen: "Routine",
                alsoRequiring: ["Tap where a rest goes"])
    }

    /// `routines/player-block` · `routines/block-done` · `routines/session-complete` — playing one.
    ///
    /// **`Done with this block` does not exist in a routine, and this test used to be built on it.**
    /// That label lives only in `FreeformRunView`; `Morning Routine` is exercise-only by
    /// construction (`PracticeHistorySeed`), so no block it plays has ever carried it. The control
    /// the routine chrome actually offers is `Skip to next block` (`RoutineRunContext`), beside a
    /// progress strip whose accessibility container reads `Block N of M`.
    ///
    /// **And skipping cannot produce `routines/block-done`.** Skip bypasses the Done gate outright
    /// (`RoutinePlayerView`), so the between-blocks screen — the one the figure is *of* — is only
    /// ever raised by a block finishing on its own. So one block is run to its natural end here, and
    /// the rest are skipped: the shortcut is taken where it changes nothing and refused where it
    /// would change the subject.
    ///
    /// Waiting is affordable, which is the other half of why this is safe. `exercises/run-complete`
    /// already sits through a full staircase on the same seeded drill and finishes well inside
    /// `rampTimeout`.
    ///
    /// The order is the sequence itself: block one runs and finishes, raising the between-blocks
    /// screen; continuing lands on block two, which is what `routines/player-block` is of; skipping
    /// the remainder reaches the recap.
    @MainActor
    func testPlayThrough() {
        let app = launchForShoot()
        openRoutines(in: app)

        // Gated on the chrome's own Skip control — the one thing a block inside a routine has that
        // the same drill run standalone does not.
        tap(app.buttons["Play Morning Routine"], labelled: "Play Morning Routine",
            revealing: app.buttons["Skip to next block"], called: "the first block")

        // A block opens on its run *setup* screen and waits to be started; it does not auto-run.
        // Scrolled into frame first: the routine chrome takes a strip off the top, so the Start
        // control sits lower here than on the same drill run standalone, and an element below the
        // fold is in the tree and cannot take a touch.
        let start = app.buttons["Start training routine"]
        scrollIntoFrame(start, called: "the Start training control", in: app)
        tap(start, labelled: "Start training",
            revealing: app.buttons["Stop and reset"], called: "the running transport")

        // Block one → the between-blocks screen. `RoutineBlockDoneView` is a plain view inside the
        // player with no `navigationTitle` of its own, so this and the two below take the chromeless
        // path. `Nice work` is the completion line and exists on no other screen in this pass.
        let doneLine = app.staticTexts["Nice work"]
        XCTAssertTrue(doneLine.waitForExistence(timeout: Self.rampTimeout), """
            the first block never finished within \(Int(Self.rampTimeout))s. It cannot be short-cut: \
            `Skip to next block` bypasses the Done gate, so a skipped block raises no between-blocks \
            screen at all. If the seeded drill's staircase has grown, this number has to grow too.
            \(stepLog)
            """)
        note("the first block finished on its own")

        captureChromeless(app, slug: "routines/block-done",
                          screen: "the between-blocks screen",
                          ownedBy: ["Nice work"],
                          alsoRequiring: ["Set mastery to 5"],
                          orBeginningWith: ["Up next"])

        // …and on into block two, which is the block the marker names. The strip's container label
        // is the gate: a block in play shows the *drill's* title, not the routine's, so `Block 2 of`
        // is the only thing on screen that says which block this is.
        continuePastBlockDone(in: app)
        captureChromeless(app, slug: "routines/player-block",
                          screen: "a routine block in play",
                          ownedBy: ["Skip to next block"],
                          orBeginningWith: ["Block 2 of"])

        // Then to the end, by skipping — no further Done screens are wanted, and rests advance on
        // their own. Bounded rather than `while true`: a run that never finishes should fail with a
        // step log, not hang the shoot.
        let recap = app.staticTexts["You practised"]
        for pass in 1...12 where !recap.exists {
            skipBlock(in: app)
            note("skipped a block, pass \(pass)")
        }
        XCTAssertTrue(recap.waitForExistence(timeout: Self.shootTimeout), """
            the routine never reached its recap after twelve skips.
            \(stepLog)
            """)

        captureChromeless(app, slug: "routines/session-complete",
                          screen: "the session recap",
                          ownedBy: ["You practised"],
                          alsoRequiring: ["How did that go?", "Done"])
    }

    /// How long a block is given to finish on its own. Mirrors `ManualExerciseShots.rampTimeout`,
    /// and is a measured allowance rather than a guess: the same seeded drill's staircase already
    /// completes inside it when run standalone for `exercises/run-complete`.
    static let rampTimeout: TimeInterval = 900

    // MARK: - Steps

    /// Add three units in one visit to the Add sheet.
    @MainActor
    private func addThreeBlocks(in app: XCUIApplication) {
        tap(app.buttons["Add exercise, loop or song"], labelled: "Add exercise, loop or song",
            revealing: app.navigationBars["Add to routine"], called: "the Add sheet")

        tapRow(labelStartingWith: "Exercises,", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the exercise bucket")

        // **The bucket is not the list.** `GroupPickList` shows the drills grouped by template — one
        // row per group, plus an `All exercises` row that is "the way past them" in its own words.
        // So the individual drills are a level further down, and looking for them here swiped ten
        // times against a list that never held them and then reported the wrong screen.
        tapRow(labelStartingWith: "All exercises,", in: app,
               arrivingAt: app.navigationBars["All exercises"], called: "the flat exercise list")

        // Three drills the first-run seed always writes, named rather than taken by position: a
        // positional pick is a different block every time the seed's ordering moves.
        for drill in ["Alternate Picking", "Chromatic Warm-up", "Spider Walk"] {
            let row = revealRow(labelStartingWith: drill, in: app)
            row.tap()
            note("added '\(drill)'")
        }

        // **Back out to the sheet's root before reaching for `Done`.**
        //
        // `Done` is one item in `AddRoutineUnitSheet`'s own toolbar — the `Add to routine` level —
        // and the drills were picked two pushes deeper, on `All exercises`. The stack keeps the root
        // alive, so from down there `Done` is in the tree and not on the screen: *in the tree but
        // never hittable*, which `awaitHittable` reported precisely and which no amount of retrying
        // could have fixed.
        //
        // The leading navigation-bar item is used rather than the back button's label, which carries
        // the *previous* screen's title and would collide with the rows on these very screens.
        for level in ["Exercises", "Add to routine"] {
            let back = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: Self.shootTimeout),
                          "no back button while returning to '\(level)'.\n\(stepLog)")
            awaitHittable(back)
            back.tap()
            XCTAssertTrue(app.navigationBars[level].waitForExistence(timeout: Self.shootTimeout),
                          "went back but never arrived at '\(level)'.\n\(stepLog)")
            note("back to '\(level)'")
        }

        tap(app.buttons["Done"], labelled: "Done",
            revealing: app.buttons["Add exercise, loop or song"], called: "the routine editor")
    }

    /// Move past whichever unit is showing, without finishing it.
    ///
    /// Deliberately *not* routed through `tap(_:revealing:)`: what a skip reveals depends on what
    /// comes next — another block, a rest countdown, or the recap — so there is no single element to
    /// gate on, and the caller checks for the recap between skips instead.
    @MainActor
    private func skipBlock(in app: XCUIApplication) {
        let skip = app.buttons["Skip to next block"]
        guard skip.waitForExistence(timeout: Self.shootTimeout) else {
            note("no 'Skip to next block' — not on a running unit")
            return
        }
        guard awaitHittable(skip) else {
            note("'Skip to next block' never became hittable")
            return
        }
        skip.tap()
    }

    /// Leave the between-blocks screen for whatever is next.
    @MainActor
    private func continuePastBlockDone(in app: XCUIApplication) {
        let next = element(in: app, labelStartingWith: "Up next:")
        guard next.exists else {
            note("no 'Up next' card — this was the last block")
            return
        }
        next.tap()
        note("continued past the between-blocks screen")
    }

    // MARK: - Navigation

    @MainActor
    private func openRoutines(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])

        tapRow(labelStartingWith: "Routines,", in: app,
               arrivingAt: app.navigationBars["Routines"], called: "the Routines library")
    }
}
