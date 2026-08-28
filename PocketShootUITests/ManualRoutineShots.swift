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

        // **`Add exercise, loop or song` is not asserted here, and the marker no longer promises it.**
        // That row sits at the *bottom* of the editor's `List`, after the blocks, the estimate and
        // the references section — and a `List` does not render below-fold rows into the
        // accessibility tree at all, so with three blocks added it is not merely out of frame, it is
        // absent. The screen dump settles what one frame can hold from the top: the Name field, the
        // Description, the numbered blocks and the estimated length. The editor grew a Description
        // (ADR 0177) and a references section (ADR 0167) after this figure was specified, and the
        // alt text was still describing the shorter screen.
        //
        // Corrected in the prose rather than answered with a `swipeUp`, which is the rule this shoot
        // already set for `reference/loop-edit` and `toolkit/tune-settings`: a figure scrolled to
        // satisfy its own caption is a figure of somewhere the reader never is.
        capture(app, slug: "routines/editor",
                assertingOnScreen: "Routine",
                alsoRequiring: ["Name", "Description", "Blocks"],
                orBeginningWith: ["Estimated length"])

        // A block tap opens the reps editor (ADR 0076). It is a detent sheet with no navigation bar,
        // so it takes the chromeless path; `Repeat this block` is the stepper's own label and exists
        // nowhere else.
        // **`Repeat, ×N`, not `1.`** In *edit* mode `blockRow` is a `Button` carrying
        // `.accessibilityLabel("Repeat, ×\(reps)")` — the number the eye sees is a separate element
        // reading `1`, with no dot, exactly as in the read-only list. `"1."` matches nothing on
        // either screen; it only ever looked right.
        // `CONTAINS`, not `BEGINSWITH`: the row's swipe action is folded into the front of the
        // button's label, so it reads `Remove, Repeat, ×1` — the third spelling of this one control
        // the shoot has now been through, after `1.` and `Repeat, ×`. Matching on the stable middle
        // survives another action being added beside Remove.
        let block = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Repeat, ×")).firstMatch
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

        // **Dismissed through its own `Done`, and checked.** This used to be a `swipeDown` followed
        // by `note("dismissed the reps editor")` — a gesture nothing verified and a log line written
        // whether or not it worked. It did not work: the screen dump taken two steps later still had
        // `Sheet Grabber`, `Repeat this block` and its stepper in frame, so every swipe meant for the
        // editor's list went to the sheet sitting on top of it, and `Insert rest` was reported as
        // "not in the tree" while being merely behind something.
        //
        // That is the third unconditional success note this one file carried — after the `Up next`
        // card that was not a button and the skip loop that counted skips it never made. The pattern
        // is always the same shape: an action with no gate, and a `note` that reads like a result.
        let repsDone = app.buttons["Done"]
        XCTAssertTrue(awaitHittable(repsDone),
                      "no Done on the reps editor.\n\(stepLog)")
        repsDone.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                  object: app.staticTexts["Repeat this block"])
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: Self.shootTimeout), .completed, """
            the reps editor is still up after Done, so everything below it is unreachable and the \
            next figure would be shot through a sheet.
            \(stepLog)
            """)
        note("dismissed the reps editor")

        // Rest-insert mode is entered by **holding** Insert rest, which turns the gaps between blocks
        // into targets under a header naming what to do.
        // Scrolled to first, for the same reason the Add row is not asserted above: `Insert rest` is
        // the row beneath it, at the very bottom of the list, and has to be brought into existence
        // before it can be held.
        let insertRest = element(in: app, labelStartingWith: "Insert rest")
        scrollIntoFrame(insertRest, called: "the Insert rest row", in: app)
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

        // **A block does not wait to be started, and this test used to say it did.** The comment
        // here claimed a run *setup* screen with a Start control on it, and drove `Start training
        // routine` accordingly. That gate is gone: `RoutineSessionPlayer.shouldAutoStart` returns
        // `AppSettings.routineAutoStart`, which is on by default — the app's own note on
        // `Routine.recordsTake` says so in as many words, because ADR 0179 depends on it ("a
        // run-time arm control would flash past before it could be tapped").
        //
        // The screen dump is what settled it: no `Start training routine` anywhere, and `Pause` and
        // `Stop and reset` both already in frame. The block was running before the test asked it to
        // start, and had been every time. Waiting on the running transport is now the whole step.
        let running = app.buttons["Stop and reset"]
        XCTAssertTrue(running.waitForExistence(timeout: Self.shootTimeout), """
            block one never reached its running transport, so auto-start is off on this device or \
            the block failed to begin. With `routineAutoStart` off every block waits for a \
            deliberate Start, and this step has to press one again.
            \(diagnosis(for: "Stop and reset", in: app))
            \(stepLog)
            """)
        note("block one is running")

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
        continuePastBlockDone(in: app, revealing: app.buttons["Skip to next block"],
                              called: "block two")
        captureChromeless(app, slug: "routines/player-block",
                          screen: "a routine block in play",
                          ownedBy: ["Skip to next block"],
                          orBeginningWith: ["Block 2 of"])

        // Then to the end, by skipping — no further Done screens are wanted, and rests advance on
        // their own. Bounded rather than `while true`: a run that never finishes should fail with a
        // step log, not hang the shoot.
        skipToRecap(in: app)

        // `Session complete` for the gate — `You practised` is uppercased by `.textCase` and does
        // not match as written (see `skipToRecap`). The recap list itself is asserted by prefix so
        // the figure still proves it is the *recap* and not an empty finish screen.
        captureChromeless(app, slug: "routines/session-complete",
                          screen: "the session recap",
                          ownedBy: ["Session complete"],
                          alsoRequiring: ["How did that go?", "Done"],
                          orBeginningWith: ["YOU PRACTISED"])
    }

    /// How long a block is given to finish on its own. Mirrors `ManualExerciseShots.rampTimeout`,
    /// and is a measured allowance rather than a guess: the same seeded drill's staircase already
    /// completes inside it when run standalone for `exercises/run-complete`.
    static let rampTimeout: TimeInterval = 900

    /// `routines/block-record` — the take switch on an exercise block's preview (ADR 0179).
    ///
    /// It shipped with a marker and nothing driving it, which is the exact consequence 0165 already
    /// records: a feature that ships a screen ships its seed, or the shoot photographs the default
    /// state and files it under a page describing something else. This is that debt paid.
    ///
    /// **The switch is turned back off before this returns, and that line is load-bearing.**
    /// `recordsTake` is not view state — the host binding writes `item.recordsTake` straight to the
    /// model (`RoutineDetailView+Record`), so leaving it on arms the first block of the very routine
    /// `testPlayThrough` plays. `routines/player-block` would come back with a recording dot and a
    /// running timer over it: a correct photograph of a state no marker asked for, taken because of
    /// the order XCTest happened to pick. Restoring it is what makes this test's place in the
    /// alphabet irrelevant, which is the property the two tests above are built for.
    ///
    /// The mic is granted in `stage_device`, before the app's first launch. Without that the first
    /// flip raises the system prompt (ADR 0179 D3), and on an erased device that is *every* run —
    /// the tap lands, the screen behind the alert still satisfies the gate, and what gets filed is a
    /// photograph of a permission dialog.
    @MainActor
    func testRecordSwitch() {
        let app = launchForShoot()
        openRoutines(in: app)

        tapRow(labelStartingWith: "Morning Routine", in: app,
               arrivingAt: app.navigationBars["Morning Routine"], called: "Morning Routine")

        // Read-only mode, so a unit block *pushes its preview* rather than opening the reps editor
        // (`RoutineDetailView+BlockPreview`) — the opposite of what the same tap does in
        // `testEditorStates`, and the reason this one never taps `Edit`. Morning Routine is
        // exercise-only by construction, so block 1 is always the `.ramped` kind whose copy the
        // marker quotes.
        let toggle = app.switches
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Record this block")).firstMatch

        // **Aimed at the drill's name, not the block number.** Two runs were spent on `"1."` before
        // the screen was dumped, and the dump settles it: the row's own accessibility label is the
        // whole line, `Spider Walk. Command 80 → 85 BPM · 16ths`, and the number beside it is a
        // *separate* element reading `1` — no dot. Nothing on this screen has ever begun with `1.`,
        // so the query resolved to nothing both times.
        //
        // The first *hittable* match, because `Spider Walk` on its own is also in the tree as the
        // row's inner label and is not tappable; `blockRow` puts the gesture on the enclosing
        // `HStack`. Taking `firstMatch` would find the inner one, which is how this reads as a race
        // when it is a query aimed one level too deep.
        let block = elements(in: app, labelStartingWith: "Spider Walk")
            .allElementsBoundByAccessibilityElement.first { $0.isHittable }
            ?? element(in: app, labelStartingWith: "Spider Walk")
        tap(block, labelled: "the first block", revealing: toggle, called: "the block preview")

        // Assembled the way `BlockRecordControl` assembles it. Written out here rather than shared
        // with the app: this is a shoot asserting what the screen says, and a constant imported from
        // the source would agree with itself no matter what either side later became.
        let commitment = "The take starts with the block and ends with it."
            + " It's saved against this exercise or loop, not the routine."

        scrollIntoFrame(toggle, called: "the Record this block switch", in: app)
        tap(toggle, labelled: "Record this block",
            revealing: app.staticTexts[commitment], called: "the take's commitment line")

        // `detail` role: the switch and the sentence under it. The sentence is `alsoRequiring` —
        // exact, because it is its own `Text` beside the toggle — and it is required rather than
        // assumed, because an off switch photographs perfectly well and the marker asks for an on
        // one; the copy is the only thing on this screen that tells the two apart.
        //
        // The switch itself goes in `orBeginningWith`, and that is not a stylistic choice. Its title
        // is inside the `Toggle`'s label, so SwiftUI folds it together with the subtitle into one
        // combined accessibility label — `Record this block, capture a take while it runs…`. An
        // exact match on the title alone finds nothing, and would fail this capture for a screen
        // that is in exactly the right state.
        capture(app, slug: "routines/block-record",
                assertingOnScreen: "Spider Walk",
                alsoRequiring: [commitment],
                orBeginningWith: ["Record this block"])

        // --- put it back, per the note above ---------------------------------------------------
        XCTAssertTrue(awaitHittable(toggle),
                      "the take switch went unreachable before it could be put back.\n\(stepLog)")
        toggle.tap()
        note("tapped Record this block off")

        // Waited on the **switch's own value**, not on the commitment line going away. A
        // `waitForExistence` on the disappearing text answers `true` the instant it is asked,
        // because the element is still in the tree on its way out — so the obvious assertion here
        // passes whether or not the tap landed, which is the only outcome it was written to tell
        // apart. A switch reports `"0"` / `"1"`, and that is the state this needs to be sure of.
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "0"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [restored], timeout: Self.shootTimeout), .completed, """
            the take switch is still on after being tapped back off, so this test has armed the \
            first block of Morning Routine for every figure shot after it on this device.
            \(stepLog)
            """)
    }

}
