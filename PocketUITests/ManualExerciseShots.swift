import XCTest

/// The manual's **exercise run** figures (ADR 0165, Phase 5) — the screen a drill opens on, its
/// settings panel, the staircase across the middle of it, and the run itself.
///
/// Rides in the `exercises` pass, on its own erased device, because most of what is here **writes**:
/// a run that finishes logs practice history, and the freeform figure needs a drill that does not
/// exist until this class makes one. On one shared device those writes would be retroactive — they
/// land in the store the read-only figures are shot from — which is the whole reason the shoot is
/// several passes rather than one long run.
///
/// **`exercises/library` is deliberately not here.** It is the same screen in the same state as
/// `reference/exercises-library`, which `ManualPracticeShots` shoots in the `base` pass, so it is
/// served from that frame. That also retires the ordering rule the hand-shoot list carried beside it:
/// authoring the freeform drill adds a seventh row, and the figure of the six-row library is now
/// taken on a device where the drill never existed.
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

    /// `exercises/template-picker` · `exercises/configure` — creating a drill, first step and second.
    ///
    /// **The rows are taken by identifier, and the app says why in so many words.**
    /// `ExerciseTemplatePicker` sets `accessibilityIdentifier("template.<raw>")` on each row with the
    /// comment *"the Exercises library sits behind this sheet and has its own Scales/Chords section
    /// rows, so a label query finds the covered one and taps nothing"*. A shoot that matched on
    /// `Warm-up` would tap the library's own collapsed section header underneath and photograph a
    /// picker that never moved.
    ///
    /// Two frames in one test because the second is reached through the first, and nothing is
    /// created: `Cancel` is never needed because the pass owns its device, but `Create` is never
    /// tapped either, so the six-drill library the `base` pass photographs stays six.
    @MainActor
    func testTemplatePickerAndConfigure() {
        let app = launchForShoot()
        openExercises(in: app)

        tap(app.buttons["New exercise"], labelled: "New exercise",
            revealing: app.buttons["template.warmup"], called: "the template picker")

        capture(app, slug: "exercises/template-picker",
                assertingOnScreen: "New exercise",
                alsoRequiring: ["Guitar", "Bass", "template.warmup", "template.picking"])

        // `New warm-up` — the title is `"New \(template.displayName.lowercased())"`, so it is the
        // template's own name and not a fixed string.
        tap(app.buttons["template.warmup"], labelled: "the Warm-up template",
            revealing: app.navigationBars["New warm-up"], called: "the configure step")

        capture(app, slug: "exercises/configure",
                assertingOnScreen: "New warm-up",
                alsoRequiring: ["Name", "Fretboard run", "Generate", "Draw your own"])
    }

    /// `exercises/run-complete` — the screen a run that finishes **on its own** lands on.
    ///
    /// **It cannot be reached by stopping.** `Stop and reset` ends a run without logging it, and the
    /// completion cover is raised from `onRampFinished` alone (ADR 0079) — so this test has to let
    /// the staircase climb the whole way, which is the one genuinely slow figure in the shoot.
    ///
    /// The screen is `RoutineBlockDoneView`, reused for a solo finish, so it has no navigation bar of
    /// its own and no `Up next` card — nothing follows a standalone run. Gated on `Nice work`, which
    /// is the completion line and is on no other screen.
    @MainActor
    func testRunComplete() {
        let app = launchForShoot()
        openAlternatePicking(in: app)

        tap(app.buttons["Start training routine"], labelled: "Start training",
            revealing: app.buttons["Stop and reset"], called: "the running transport")

        let doneLine = app.staticTexts["Nice work"]
        XCTAssertTrue(doneLine.waitForExistence(timeout: Self.rampTimeout), """
            the ramp never finished within \(Int(Self.rampTimeout))s, so there is no completion \
            screen to shoot. A run stopped by hand does not raise one, so this cannot be short-cut — \
            if the seeded drill's staircase has grown, this number has to grow with it.
            \(stepLog)
            """)
        note("the ramp finished on its own")

        // The mastery dots and the command-tempo offer are what the marker names beyond the heading;
        // both are what make this the *completion* screen rather than a generic well-done.
        captureChromeless(app, slug: "exercises/run-complete",
                          screen: "the run completion screen",
                          ownedBy: ["Nice work"],
                          alsoRequiring: ["Set mastery to 5"])
    }

    /// `exercises/freeform-run` — a *Your own practice* block running, showing the player's own words.
    ///
    /// **Authored here rather than seeded, and that is a deliberate reversal of the house rule.**
    /// "A feature that ships a screen ships its seed" would say `ScreenshotSeed` should write this
    /// drill — but a seventh drill in the library desynchronises `reference/exercises-library`, which
    /// is a figure of the six a fresh install has. Authoring it inside this pass keeps that figure
    /// honest, because the pass has its own device and the `base` pass never sees the drill.
    ///
    /// The name and instructions are pinned so a re-shoot months from now produces the same picture,
    /// and **both toggles are left off on purpose**: the page says a freeform block has no tempo and
    /// no meter, so the figure has to show the plain timer and the player's prose, not a click.
    @MainActor
    func testFreeformRun() {
        let app = launchForShoot()
        openExercises(in: app)

        // Gated on the picker's own navigation bar, not on the row this test wants. `template.freeform`
        // is the **last** template in `ExerciseTemplate`, so it renders below the fold and is absent
        // from the tree until the list is scrolled — which the old gate read as "the picker never
        // opened", on a picker that had opened perfectly well. `testTemplatePicker` passes against
        // the same screen only because `template.warmup` and `template.picking` sit near the top.
        tap(app.buttons["New exercise"], labelled: "New exercise",
            revealing: app.navigationBars["New exercise"], called: "the template picker")

        let freeform = app.buttons["template.freeform"]
        scrollIntoFrame(freeform, called: "the Your own practice template", in: app)
        tap(freeform, labelled: "the Your own practice template",
            revealing: app.navigationBars["New your own practice"], called: "the configure step")

        type(Self.freeformName, into: app.textFields.firstMatch, called: "the name field", in: app)
        type(Self.freeformInstructions,
             into: app.textFields["What are you practising?"], called: "the instructions", in: app)

        tap(app.buttons["Create"], labelled: "Create",
            revealing: app.buttons["Done with this block"], called: "the running freeform block")

        // **A freeform block has no Start control — it is already running.**
        // `FreeformRunView.onAppear` sets `startedAt` the moment the screen appears, and the only
        // control on it is `Done with this block` in a `safeAreaInset`. This test pressed
        // `Start training routine` for two rounds: once reported as *in the tree but never hittable*
        // (the button flickering through the Create transition), once as *not in the tree at all*
        // after ten fruitless swipes — by which point the block had been running for fifty seconds
        // and the dump said so. Create lands on a running block; nothing else is needed.

        // The elapsed time is the figure's other half, so this waits for the clock to have **visibly
        // moved** rather than shooting a timer reading 0:00. The old form waited for a label
        // beginning `0:0`, which 0:00 itself satisfies — it asserted the timer existed, not that it
        // had started. The label reads "<m:ss> elapsed on this block".
        let ticked = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ AND NOT (label BEGINSWITH %@)", "0:", "0:00"))
        XCTAssertTrue(ticked.firstMatch.waitForExistence(timeout: Self.shootTimeout),
                      "the freeform block's clock never moved off 0:00.\n\(stepLog)")

        // `Instructions: ` — the run screen prefixes the player's own words, so a prefix aimed at
        // the prose itself matches nothing. The dump on the failing run is where that came from.
        capture(app, slug: "exercises/freeform-run",
                assertingOnScreen: Self.freeformName,
                orBeginningWith: ["Instructions: One new piece from the book"])
    }

    // MARK: - Fixtures

    /// How long a full staircase is given to climb. Long, and deliberately not a guess dressed up as
    /// a constant: `exercises/run-complete` is the only figure in the manual that has to sit through
    /// the thing it photographs.
    static let rampTimeout: TimeInterval = 900

    /// Pinned so a re-shoot produces the same picture — the shoot list names both.
    static let freeformName = "Sight-reading"
    static let freeformInstructions =
        "One new piece from the book, slowly. Keep going to the end — no stopping to fix mistakes."

    /// Tap a field and type into it, checking the text landed.
    ///
    /// Typing is where a UI test quietly goes wrong — a field that never took focus swallows every
    /// keystroke and leaves a placeholder, which photographs as an empty form rather than a failure.
    @MainActor
    private func type(_ text: String,
                      into field: XCUIElement,
                      called name: String,
                      in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: Self.shootTimeout),
                      "no \(name) to type into.\n\(stepLog)")
        awaitHittable(field)
        field.tap()
        field.typeText(text)
        note("typed into \(name)")
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
