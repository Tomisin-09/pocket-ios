import XCTest

/// The steps `ManualRoutineShots` walks, split out of it (ADR 0165, Phase 5).
///
/// Here for the 400-line cap, and the seam is the useful one: the file next door is *what each
/// figure is of*, and this is *how the app is driven to it*. Every one of these has been rewritten
/// at least once after a run disagreed with it — the sheet walked back by name instead of by
/// `firstMatch`, the block reached by the drill's title instead of a number that was never on
/// screen, the between-blocks screen left through `Continue` instead of a card that only looked
/// like a button. They are grouped so the next such correction has one place to land.
///
/// These are **internal, not `private`**, and the compiler is what says so: `private` in Swift is
/// *file* scope, so a helper moved into this extension stops being visible to the class it was cut
/// from. That is the one thing that has to change when a helper crosses a file boundary, and it
/// fails the build rather than the run, which is the good direction.
extension ManualRoutineShots {

    // MARK: - Steps

    /// Add three units in one visit to the Add sheet.
    @MainActor
    func addThreeBlocks(in app: XCUIApplication) {
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
        // **The bar is named, because `firstMatch` is not a screen.** This walk used to take
        // `app.navigationBars.firstMatch` and tap its leading item. The Add sheet is presented over
        // the routine editor, which has a navigation bar of its own, so at this moment the tree holds
        // more than one and `firstMatch` picks whichever the query orders first — not whichever is on
        // top. That is why this failed at a *different* level on each of three runs: run one never
        // reached `Exercises`, run two got past `Done`, run three stopped at `Add to routine`. An
        // ambiguous query does not fail consistently, and a flake that moves is usually a query that
        // never named one thing.
        //
        // Naming the screen being *left* resolves the bar unambiguously, and the leading item is
        // still taken by position — its label carries the previous screen's title, which on these
        // screens collides with the rows themselves.
        for (leaving, arriving) in [("All exercises", "Exercises"), ("Exercises", "Add to routine")] {
            let bar = app.navigationBars[leaving]
            XCTAssertTrue(bar.waitForExistence(timeout: Self.shootTimeout), """
                expected to be on '\(leaving)' before going back to '\(arriving)', and that \
                navigation bar is not there — so the walk is somewhere else entirely.
                \(diagnosis(for: leaving, in: app))
                \(stepLog)
                """)
            let back = bar.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: Self.shootTimeout),
                          "no back button on '\(leaving)'.\n\(stepLog)")
            awaitHittable(back)
            back.tap()
            XCTAssertTrue(app.navigationBars[arriving].waitForExistence(timeout: Self.shootTimeout), """
                left '\(leaving)' but never arrived at '\(arriving)'.
                \(diagnosis(for: arriving, in: app))
                \(stepLog)
                """)
            note("back to '\(arriving)'")
        }

        // **Gated on `Save`, not on the Add row.** `Done` dismisses the Add sheet back onto the
        // editor, and the obvious thing to wait for is the control the editor opened with — except
        // that with three blocks now in the list, `Add exercise, loop or song` has moved below the
        // fold, and a `List` does not render below-fold rows into the tree. So the gate went looking
        // for something genuinely absent and reported "something opened and it is not what this shot
        // needs", when what had opened was precisely the right screen. It read as a failed tap for
        // three runs and was a failed *assumption*: that the editor looks the same full as empty.
        //
        // `Save` is in the editor's toolbar, always drawn, and the Add sheet's own toolbar carries
        // `Done` and `Cancel` but no `Save` — so it cannot be satisfied from the sheet being left.
        tap(app.buttons["Done"], labelled: "Done",
            revealing: app.buttons["Save"], called: "the routine editor")
    }

    /// Move past whichever unit is showing, without finishing it.
    ///
    /// Deliberately *not* routed through `tap(_:revealing:)`: what a skip reveals depends on what
    /// comes next — another block, a rest countdown, or the recap — so there is no single element to
    /// gate on, and the caller checks for the recap between skips instead.
    @MainActor
    /// - Returns: whether a block was actually skipped.
    ///
    /// **It returns a verdict because the caller was writing one either way.** The skip loop noted
    /// *"skipped a block, pass N"* after every call, including the calls that found no control and
    /// returned having done nothing — so a run that was stuck on one screen produced a step log of
    /// twelve confident skips. That is the same defect `continuePastBlockDone` had, and it hides the
    /// same thing: the moment the walk stopped moving.
    @discardableResult
    func skipBlock(in app: XCUIApplication) -> Bool {
        let skip = app.buttons["Skip to next block"]
        guard skip.waitForExistence(timeout: Self.tapProbeTimeout) else {
            note("no 'Skip to next block' — not on a running unit")
            return false
        }
        guard awaitHittable(skip) else {
            note("'Skip to next block' never became hittable")
            return false
        }
        skip.tap()
        return true
    }

    /// Leave the between-blocks screen for whatever is next.
    @MainActor
    func continuePastBlockDone(in app: XCUIApplication,
                               revealing revealed: XCUIElement,
                               called revealedName: String) {
        // **`Continue` is the control; the `Up next` card is a picture of one.** This used to tap the
        // card — `upNextCard` in `RoutineBlockDoneView` is a `VStack` with
        // `.accessibilityElement(children: .combine)` and no button and no gesture on it, so the tap
        // went nowhere. It then wrote *"continued past the between-blocks screen"* into the step log
        // regardless, because nothing checked. Two runs read that line and believed it, and the
        // failure surfaced one step later as `routines/player-block` being "the wrong screen" — which
        // it was, in the sense that it was still the between-blocks screen nobody had left.
        //
        // Guarded through `tap(_:revealing:)` now, so a tap that does nothing fails here, where the
        // cause is, rather than at the next capture. `Finish` replaces `Continue` on the last block
        // (`isLast`), and this is only ever called mid-routine.
        let advance = app.buttons["Continue"]
        guard advance.exists else {
            note("no 'Continue' — this was the last block")
            return
        }
        tap(advance, labelled: "Continue", revealing: revealed, called: revealedName)
    }
    // MARK: - Navigation

    @MainActor
    func openRoutines(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])

        tapRow(labelStartingWith: "Routines,", in: app,
               arrivingAt: app.navigationBars["Routines"], called: "the Routines library")
    }

    /// Skip whatever remains until the routine's recap, or fail saying where it stalled.

    @MainActor
    func skipToRecap(in app: XCUIApplication) {
// **The loop stops when it stops moving.** It used to call `skipBlock` twelve times and note
        // a skip after each one whether or not anything was skipped, so a walk stuck on one screen
        // logged twelve successful passes and then failed at the end with no clue where it stalled.
        //
        // A rest advances on its own and carries no skip control, so a pass finding nothing is
        // ordinary and worth one short retry — but two in a row means the routine is sitting on
        // something this does not know how to leave, and that is the moment to say so.
        // **`Session complete`, not `You practised`.** The recap heading is
        // `Text("You practised").textCase(.uppercase)`, so the source says one thing and the
        // accessibility label says `YOU PRACTISED`. The routine had been reaching its recap for two
        // runs and this gate could not see it.
        //
        // Worth naming because it is the exact *inverse* of the manual's own C9 rule: prose quotes a
        // control as the app **writes** it, since capitals are typography and a screen may shout. A
        // UI test has to match what the screen **renders**. The same string is spelled two different
        // correct ways on the two sides, and copying the prose convention into a test matches
        // nothing. `Session complete` carries no `textCase` and is the screen's own heading.
        let recap = app.staticTexts["Session complete"]
        var idle = 0
        for pass in 1...12 where !recap.exists {
            if skipBlock(in: app) {
                idle = 0
                note("skipped a block, pass \(pass)")
            } else {
                idle += 1
                note("nothing to skip on pass \(pass)")
                if idle == 2 { break }
            }
        }
        XCTAssertTrue(recap.waitForExistence(timeout: Self.shootTimeout), """
            the routine never reached its recap. The last block may end on a Done screen rather than \
            skipping straight out — `RoutineBlockDoneView` shows `Finish` instead of `Continue` when \
            `isLast`, and that is a tap this loop does not make.
            \(diagnosis(for: "You practised", in: app))
            \(stepLog)
            """)
    }
}
