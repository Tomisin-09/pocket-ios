import XCTest

/// **A practice run started outside a routine reaches the practice log** (ADR 0117).
///
/// This is a unit test's blind spot by construction. Ear training and improvising are one shared
/// core view inside several hosts, and the `PracticeLogWriter` call lived in the routine host alone —
/// so every aggregate stayed correct, every writer test passed, and the four standalone hosts
/// recorded nothing at all. Nothing that stops at the model layer can see that: the defect was an
/// **absence** in a view, and only driving the app finds it.
///
/// **It asserts a delta, not a state.** The obvious version — run once, then assert Progress no
/// longer says "Nothing here yet" — passes with the fix reverted, because a simulator keeps its
/// store between test runs and the *previous* execution's row is still there. It was written that
/// way first and duly went green against deliberately broken code. Reading the minute total either
/// side of one run is immune to whatever the store already held.
///
/// **Which is why the run is over a minute long.** Progress' finest displayed grain is a rounded
/// minute, so a dwell shorter than one cannot be told apart from no run at all. Adding 65 seconds
/// raises the rounded total by at least one whatever it started at; adding 3 seconds usually raises
/// it by nothing. The alternative — asserting on days or sessions — moves only on a store that was
/// already empty, which is the assumption that made the first version worthless.
final class StandaloneRunLoggingUITests: UITestCase {

    /// `-seedScreenshots` is the only seeder that writes a song, and a loop needs one to qualify for
    /// ear training at all (`LoopModeAccess`: no song, no audio, no mode). First-run seeding
    /// deliberately ships no song (ADR 0148), so without this there is nothing to practise.
    private static let seedLibrary = "-seedScreenshots"

    /// Long enough to move a rounded minute total; see the type comment.
    private static let runSeconds: TimeInterval = 65

    @MainActor
    func testEarTrainingOutsideARoutineCountsTowardProgress() throws {
        let app = launchApp(extraArguments: [Self.seedLibrary])

        let before = minutesOnProgress(in: app)
        practiseEarTrainingStandalone(in: app)
        let after = minutesOnProgress(in: app)

        XCTAssertGreaterThan(
            after, before,
            """
            Progress logged no minutes for a \(Int(Self.runSeconds))s ear-training run started \
            outside a routine (\(before) → \(after)). The run screen never wrote a row — which is \
            the bug: the writer call belongs on the shared core (`RampLessRunLog`), not on the \
            routine host, or every standalone route logs nothing.
            """)
    }

    // MARK: - The run

    @MainActor
    private func practiseEarTrainingStandalone(in app: XCUIApplication) {
        openLoopLibrary(in: app)

        let ear = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Train your ear — ")).firstMatch
        XCTAssertTrue(ear.waitForExistence(timeout: Self.uiTimeout),
                      "no loop in the library offers ear training — check `-seedScreenshots` "
                      + "actually seeded a song, since a loop with no song qualifies for no mode")
        XCTAssertTrue(waitUntilHittable(ear), "the ear-training button never became tappable")
        ear.tap()

        // A phrase only the ear-training screen says. Its nav title is "Train your ear", which the
        // button we just tapped also reads — a gate the previous screen can satisfy is not a gate.
        let intro = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Listen it into your ear")).firstMatch
        XCTAssertTrue(intro.waitForExistence(timeout: Self.uiTimeout),
                      "tapping Train your ear did not open the ear-training screen")

        dwell(Self.runSeconds)

        // Leaving *is* the completion for a mode with no ramp — there is no Done to press.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Loops"].waitForExistence(timeout: Self.uiTimeout),
                      "leaving the ear-training screen did not return to the Loops library")
        returnHome(in: app)
    }

    /// Sit on the run screen. A **real dwell**, not a wait for the app to settle — see the type
    /// comment for why it is this long, and note that runs under
    /// `PracticeLogWriter.minimumSeconds` are dropped as noise by design.
    @MainActor
    private func dwell(_ seconds: TimeInterval) {
        let waiting = expectation(description: "practising for \(seconds)s")
        waiting.isInverted = true
        wait(for: [waiting], timeout: seconds)
    }

    // MARK: - Reading Progress

    /// The minutes Progress claims for this week, having walked to it and back to Home.
    ///
    /// A fresh store shows "Nothing here yet" instead of any figure, which is **zero minutes**, not a
    /// failure — the test has to work from an empty store and from one an earlier execution left
    /// behind.
    @MainActor
    private func minutesOnProgress(in app: XCUIApplication) -> Int {
        openProgress(in: app)
        defer { returnHome(in: app) }

        if app.staticTexts["Nothing here yet"].exists { return 0 }

        // `figure` is an `.accessibilityElement(children: .ignore)` on an `HStack`, so it surfaces as
        // an `otherElement` carrying the whole label — "12 minutes" — not as two static texts.
        let matching = NSPredicate(format: "label MATCHES %@", "^[0-9]+ minutes?$")
        let figure = app.otherElements.matching(matching).firstMatch
        guard figure.waitForExistence(timeout: Self.uiTimeout),
              let minutes = Int(figure.label.split(separator: " ")[0])
        else {
            XCTFail("""
                Progress showed neither its empty state nor a minutes figure.
                \(app.debugDescription)
                """)
            return 0
        }
        return minutes
    }

    // MARK: - The walk

    @MainActor
    private func openLoopLibrary(in app: XCUIApplication) {
        let practice = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(waitUntilHittable(practice), "the Practice card never became tappable")
        practice.tap()

        // "Loops" alone is a word Home says too; the subtitle belongs to this row only.
        let loops = app.staticTexts["Measured song loops"]
        XCTAssertTrue(loops.waitForExistence(timeout: Self.uiTimeout), "Practice never opened")
        XCTAssertTrue(waitUntilHittable(loops), "the Loops row never became tappable")
        loops.tap()

        XCTAssertTrue(app.navigationBars["Loops"].waitForExistence(timeout: Self.uiTimeout),
                      "the Loops library never opened")
        showEveryLoop(in: app)
    }

    /// Widen the list past the **trainer** gate (ADR 0138 G4).
    ///
    /// The default listing is the measured one — `commandTempo != nil` — and a command tempo can only
    /// be set by playing the passage. The seeded loops have none, so the default list is empty and
    /// "Show all loops" is the app's own answer for exactly this: reaching an unmeasured loop to
    /// train your ear with it, no tempo needed. Widening here is the documented route, not a
    /// convenience for the test.
    @MainActor
    private func showEveryLoop(in app: XCUIApplication) {
        let options = app.buttons["List options"]
        XCTAssertTrue(options.waitForExistence(timeout: Self.uiTimeout),
                      "no options menu in the Loops library — it hides when there are no loops at "
                      + "all, so suspect the seed before the menu")

        let widen = app.buttons["Show all loops"]
        openMenu(options, revealing: widen, called: "the Loops library's options menu")
        widen.tap()
    }

    @MainActor
    private func openProgress(in app: XCUIApplication) {
        let journal = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journal.waitForExistence(timeout: Self.uiTimeout), "no Journal card on Home")
        XCTAssertTrue(waitUntilHittable(journal), "the Journal card never became tappable")
        journal.tap()

        // Progress shares the Journal's ⋯ door (ADR 0117) — there is no Home card for it.
        let options = app.buttons["Journal options"]
        XCTAssertTrue(options.waitForExistence(timeout: Self.uiTimeout), "no ⋯ menu on the Journal")

        let progress = app.buttons["Progress"]
        openMenu(options, revealing: progress, called: "the Journal's ⋯ menu")
        progress.tap()

        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: Self.uiTimeout),
                      "Progress never opened")
    }

    /// Tap a menu control until it opens.
    ///
    /// The first version of this abandoned as soon as the control stopped being hittable, reasoning
    /// that a menu's scrim covers it and so a re-tap would only ever fire from a screen that visibly
    /// did not change. That reasoning has a hole, and CI found it: a control is *also* un-hittable
    /// while the push that revealed it is still animating, and `waitForExistence` returns the moment
    /// it enters the tree — well before it settles. So one tap got swallowed mid-transition, the
    /// guard read the un-hittable control as "the menu is open", and the run failed from a screen
    /// where one more tap would have worked. (The menu-item query itself is sound: `RowUndoUITests`
    /// finds hold-menu buttons the same way and passes on CI.)
    ///
    /// Waiting for hittability before each tap covers both causes, and checking `item` first means
    /// an already-open menu is never tapped shut again.
    @MainActor
    private func openMenu(_ control: XCUIElement, revealing item: XCUIElement, called name: String) {
        for _ in 0..<3 {
            if item.exists { return }
            guard waitUntilHittable(control) else { continue }
            control.tap()
            if item.waitForExistence(timeout: Self.uiTimeout) { return }
        }
        XCTFail("\(name) never opened")
    }

    /// Wait for `element` to become tappable, not merely present — the distinction the failure above
    /// turned on. XCTest ships `waitForExistence` and nothing for this.
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement,
                                   timeout: TimeInterval = UITestCase.uiTimeout) -> Bool {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"),
                                   evaluatedWith: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    /// Pop back to Home, which is where both destinations are reached from.
    @MainActor
    private func returnHome(in app: XCUIApplication) {
        let home = app.buttons["Practice, your exercises and training runs"]
        while !home.exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.exists, back.isHittable else { break }
            back.tap()
        }
        XCTAssertTrue(home.waitForExistence(timeout: Self.uiTimeout), "never got back to Home")
    }
}
