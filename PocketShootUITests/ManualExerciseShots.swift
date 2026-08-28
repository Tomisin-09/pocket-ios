import XCTest

/// The manual's **exercise run** figures (ADR 0165, Phase 5) — the screen a drill opens on, its
/// settings panel, the staircase across the middle of it, and the run itself.
///
/// Rides in the `exercises` pass, on its own erased device, because a run that reaches its own end
/// logs practice history. On one shared device that write would be retroactive — it lands in the
/// store the read-only figures are shot from — which is the whole reason the shoot is several
/// passes rather than one long run.
///
/// **Three figures this class used to shoot are gone**, their markers cut in Phase 5:
/// `exercises/template-picker`, `exercises/run-complete` and `exercises/freeform-run`. The last two
/// took the expensive parts of the class with them — a 900-second wait for a staircase to climb
/// itself, and the authoring of a seventh drill that every other library figure then had to be
/// protected from. Neither cost is now paid, and neither is a loss: the completion screen and the
/// freeform block are both described in prose beside where their pictures used to sit.
///
/// **`exercises/library` is deliberately not here either.** It is the same screen in the same state
/// as `reference/exercises-library`, which `ManualPracticeShots` shoots in the `base` pass, so it is
/// served from that frame.
final class ManualExerciseShots: ManualShotCase {

    /// `exercises/run-setup` · `exercises/staircase` — the screen a drill opens on, stopped.
    ///
    /// One frame, two markers: the staircase is a `role: band` crop out of the middle of the run
    /// screen, and everything its alt text names is inside the full frame already.
    ///
    /// Both ends of the picture are asserted, which is what makes sharing a frame legitimate rather
    /// than convenient. `Practice settings, …` is the collapsed summary at the top; `Start training`
    /// is the control at the bottom; the staircase's own phase labels sit between them. A screen that
    /// had grown enough to push either end out of shot fails here instead of producing a figure whose
    /// caption promises something outside the crop.
    ///
    /// The summary is matched by prefix. Its full label carries the drill's tempos — `Practice
    /// settings, 76→90 · reach 95 BPM` — and pinning those would make this fail on a seed change
    /// rather than on the thing the figure is about. `90 BPM` **is** pinned, because that is the
    /// command plateau the marker names in so many words.
    /// It also serves the manual's two run-screen **glyphs**. `journal/quick-note-button` and
    /// `journal/record-arm` ask only for a frame with the run screen's toolbar in it, and this is the
    /// one frame that has both: the record control is on the *setup* screen and gone once a run
    /// starts, so `exercises/run-live` could serve the pencil and never the record arm. Both are
    /// required in frame rather than assumed, because a crop that falls outside its master is a
    /// figure that cannot be cut.
    @MainActor
    func testRunSetup() {
        let app = launchForShoot()
        openAlternatePicking(in: app)
        capture(app, slug: "exercises/run-setup",
                assertingOnScreen: "Alternate Picking",
                alsoRequiring: ["90 BPM", "warm-up", "command", "reach", "back off",
                                "Write a quick journal note", "Record this session"],
                orBeginningWith: ["Practice settings,", "Start training"],
                alsoServing: ["exercises/staircase", "journal/quick-note-button",
                              "journal/record-arm"])
    }

    /// `exercises/run-live` — a run going, past the count-in.
    ///
    /// **Waiting for the count-in is the whole of this test.** Start, and the screen reads `3` over
    /// `Counting in`; the marker asks for the live BPM and the phase caption, which only replace it
    /// when the count finishes. A capture taken on arrival is a clean photograph of a screen counting
    /// down — right screen, wrong state, and nothing about it looks wrong afterwards.
    ///
    /// The wait is for `Counting in` to **go away** rather than for a BPM to appear. The tempo is a
    /// bare number in the tree (`76`) with its units in a separate caption, so waiting on it would
    /// mean matching a digit; the count-in's own words are unambiguous and are what the state is not.
    ///
    /// The fretboard the marker names has **no accessibility elements at all** — it is drawn, and
    /// nothing in the tree stands for it. It cannot be asserted, only looked at, which is what the
    /// audit of the filed image is for.
    @MainActor
    func testRunLive() {
        let app = launchForShoot()
        openAlternatePicking(in: app)

        let start = app.buttons["Start training routine"]
        tap(start, labelled: "Start training",
            revealing: app.buttons["Stop and reset"], called: "the running transport")

        let countingIn = app.staticTexts["Counting in"]
        if countingIn.exists {
            note("counting in — waiting for it to finish")
            XCTAssertTrue(waitForDisappearance(of: countingIn, timeout: Self.shootTimeout), """
                the count-in never finished, so this would have been shot mid-count.
                \(stepLog)
                """)
        }

        capture(app, slug: "exercises/run-live",
                assertingOnScreen: "Alternate Picking",
                alsoRequiring: ["Stop and reset", "Pause"],
                orBeginningWith: ["BPM ·"])
    }

    /// `journal/quick-note` · `reference/quick-note` — the mid-run capture sheet (ADR 0142).
    ///
    /// Shot from a **running** exercise, which is the state its marker names, and the reason the run
    /// is started first rather than opening the sheet off the setup screen: the line at the foot of
    /// the sheet says where the note will be saved, and that sentence is about the run in progress.
    ///
    /// Gated on the sheet's `Quick note` navigation bar. The field's placeholder would be the more
    /// obvious gate and is the weaker one — a `TextField` placeholder is not a label, so it does not
    /// answer a label query, which is the kind of near-miss that turns into a thirty-second wait and
    /// a message about the wrong thing.
    @MainActor
    func testQuickNote() {
        let app = launchForShoot()
        openAlternatePicking(in: app)

        let start = app.buttons["Start training routine"]
        tap(start, labelled: "Start training",
            revealing: app.buttons["Stop and reset"], called: "the running transport")

        let pencil = app.buttons["Write a quick journal note"]
        tap(pencil, labelled: "the quick-note button",
            revealing: app.navigationBars["Quick note"], called: "the Quick note sheet")

        capture(app, slug: "journal/quick-note",
                assertingOnScreen: "Quick note",
                alsoRequiring: ["Tag this", "Goal", "Breakthrough", "Struggle", "Cancel", "Save"],
                alsoServing: ["reference/quick-note"])
    }

    /// `exercises/practice-settings` — the panel expanded.
    ///
    /// Gated on `Working`, which the collapsed screen does not have: the summary line above it reads
    /// `76→90 · reach 95 BPM` and names none of the three fields. That distinction is the whole gate.
    /// The first walk of this screen tapped the summary, waited on nothing, and dumped a tree
    /// **byte-identical** to the one before it — a tap that changed nothing, reported as a step that
    /// worked. Nothing but the comparison caught it, and a capture in its place would have been the
    /// collapsed screen filed under the expanded figure's name.
    @MainActor
    func testPracticeSettings() {
        let app = launchForShoot()
        openAlternatePicking(in: app)

        // Gated on `Raise Working` — a `StepperButton` inside the Working row, which exists only
        // once the panel is open. The row's own `Working` text was the first gate and is the weaker
        // one: it is a plain `Text` in an `HStack` that may or may not surface as its own element
        // depending on how the row combines, and a gate that *might* not exist when the thing did
        // happen is indistinguishable from one that correctly says nothing happened.
        // **Tapped once, by hand, and deliberately not through `tap(_:revealing:)`.**
        //
        // That helper retries when the control it tapped is still hittable, on the reasoning that a
        // control which is still there did not do anything. For a *disclosure header* that reasoning
        // is inverted: the header stays exactly where it is when it works, so the retry fires every
        // time — and each retry toggles the panel back. Three attempts is expand, collapse, expand,
        // reported as "tapped 3× and the expanded panel never appeared".
        //
        // `showSettings` defaults to `false`, so one tap is all this needs.
        let summary = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice settings,")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice Settings header on the run screen.\n\(stepLog)")
        awaitHittable(summary)
        summary.tap()
        note("expanded the Practice Settings panel")

        // The panel opens *below the fold*, and an element off the bottom of a scroll view is not in
        // the tree at all — so waiting on `Raise Working` where it stood would have waited forever
        // however many times the header was tapped. `scrollIntoFrame` handles the absent case
        // (`element.exists ? element.frame : .zero`, then swipe) and is the only thing that can
        // distinguish "not scrolled to" from "not there", which its failure message then says.
        scrollIntoFrame(app.buttons["Raise Working"], called: "the Working row", in: app)

        capture(app, slug: "exercises/practice-settings",
                assertingOnScreen: "Alternate Picking",
                alsoRequiring: ["Working", "Command", "Reach", "Back off"])
    }

    /// `exercises/configure` — the second step of creating a drill.
    ///
    /// **The template row is taken by identifier, and the app says why in so many words.**
    /// `ExerciseTemplatePicker` sets `accessibilityIdentifier("template.<raw>")` on each row with the
    /// comment *"the Exercises library sits behind this sheet and has its own Scales/Chords section
    /// rows, so a label query finds the covered one and taps nothing"*. A shoot that matched on
    /// `Warm-up` would tap the library's own collapsed section header underneath and photograph a
    /// picker that never moved.
    ///
    /// The picker step used to be a figure of its own here, `exercises/template-picker`. Its marker
    /// was cut in Phase 5 — the page beside it already listed every template in prose — so the
    /// picker is now only walked through, not photographed. Nothing is created either way: `Create`
    /// is never tapped, so the six-drill library the `base` pass photographs stays six.
    @MainActor
    func testConfigure() {
        let app = launchForShoot()
        openExercises(in: app)

        tap(app.buttons["New exercise"], labelled: "New exercise",
            revealing: app.buttons["template.warmup"], called: "the template picker")

        // `New warm-up` — the title is `"New \(template.displayName.lowercased())"`, so it is the
        // template's own name and not a fixed string.
        tap(app.buttons["template.warmup"], labelled: "the Warm-up template",
            revealing: app.navigationBars["New warm-up"], called: "the configure step")

        capture(app, slug: "exercises/configure",
                assertingOnScreen: "New warm-up",
                alsoRequiring: ["Name", "Fretboard run", "Generate", "Draw your own"])
    }

    // MARK: - Navigation

    /// Home ▸ Practice ▸ Exercises ▸ **Alternate Picking**.
    ///
    /// Each hop gates on something the destination owns and the screen being left does not. "Practice"
    /// is a word Home's own card says, so that arrival is the hub's navigation bar; the run screen's
    /// is its ⓘ, which no library row carries.
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

    /// …then into the seeded picking drill.
    @MainActor
    private func openAlternatePicking(in app: XCUIApplication) {
        openExercises(in: app)
        // Prefix, because the row carries its command tempo and subdivision after the name.
        tapRow(labelStartingWith: "Alternate Picking", in: app,
               arrivingAt: app.buttons["Exercise details"], called: "the run screen")
    }
}
