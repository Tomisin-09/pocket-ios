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
    /// **Blocks are finished by hand, not waited out.** A seeded routine's blocks are minutes long
    /// each, and a test that played `Morning Routine` honestly would sit for the better part of half
    /// an hour. `Done with this block` is the control a player uses to move on early, so the states
    /// reached through it are the states the manual describes — this is a shortcut through the
    /// clock, not around the flow.
    ///
    /// The order is the sequence itself: block one runs, is finished, and the between-blocks screen
    /// appears; continuing lands on block two, which is what `routines/player-block` is of; finishing
    /// the rest of them reaches the recap.
    @MainActor
    func testPlayThrough() {
        let app = launchForShoot()
        openRoutines(in: app)

        let play = app.buttons["Play Morning Routine"]
        tap(play, labelled: "Play Morning Routine",
            revealing: app.buttons["Done with this block"], called: "the first block")

        // Block one → the between-blocks screen.
        // `RoutineBlockDoneView` is a plain view inside the player, with no `navigationTitle` of its
        // own — so this and the two below take the chromeless path. `Nice work` is the completion
        // line and exists on no other screen.
        finishBlock(in: app)
        captureChromeless(app, slug: "routines/block-done",
                          screen: "the between-blocks screen",
                          ownedBy: ["Nice work"],
                          alsoRequiring: ["Up next"])

        // …and on into block two, which is the block the marker names.
        // A block in play shows the *drill's* navigation title, not the routine's, so the gate is
        // `Exit routine` — the one control the routine player adds and a standalone run does not.
        continuePastBlockDone(in: app)
        captureChromeless(app, slug: "routines/player-block",
                          screen: "a routine block in play",
                          ownedBy: ["Exit routine"],
                          orBeginningWith: ["Block 2 of"])

        // Then to the end. The routine is four blocks and two rests; rests advance on their own, so
        // the loop only has to keep finishing units until the recap appears. Bounded rather than
        // `while true`: a run that never finishes should fail with a step log, not hang the shoot.
        let recap = app.staticTexts["You practised"]
        for pass in 1...8 where !recap.exists {
            finishBlock(in: app)
            continuePastBlockDone(in: app)
            note("finished block, pass \(pass)")
        }
        XCTAssertTrue(recap.waitForExistence(timeout: Self.shootTimeout), """
            the routine never reached its recap after eight blocks.
            \(stepLog)
            """)

        captureChromeless(app, slug: "routines/session-complete",
                          screen: "the session recap",
                          ownedBy: ["You practised"],
                          alsoRequiring: ["How did that go?", "Done"])
    }

    // MARK: - Steps

    /// Add three units in one visit to the Add sheet.
    @MainActor
    private func addThreeBlocks(in app: XCUIApplication) {
        tap(app.buttons["Add exercise, loop or song"], labelled: "Add exercise, loop or song",
            revealing: app.navigationBars["Add to routine"], called: "the Add sheet")

        tapRow(labelStartingWith: "Exercises,", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the exercise bucket")

        // Three drills the first-run seed always writes, named rather than taken by position: a
        // positional pick is a different block every time the seed's ordering moves.
        for drill in ["Alternate Picking", "Chromatic Warm-up", "Spider Walk"] {
            let row = revealRow(labelStartingWith: drill, in: app)
            row.tap()
            note("added '\(drill)'")
        }

        tap(app.buttons["Done"], labelled: "Done",
            revealing: app.buttons["Add exercise, loop or song"], called: "the routine editor")
    }

    /// Finish whichever unit is running.
    @MainActor
    private func finishBlock(in app: XCUIApplication) {
        let done = app.buttons["Done with this block"]
        guard done.waitForExistence(timeout: Self.shootTimeout) else {
            note("no 'Done with this block' — not on a running unit")
            return
        }
        tap(done, labelled: "Done with this block",
            revealing: app.staticTexts["Nice work"], called: "the between-blocks screen")
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
