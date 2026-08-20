import XCTest

/// The manual's **Today's session** figures (ADR 0165, Phase 5) — the planner before anything is
/// asked of it, the goal authoring behind it, and the session it generates.
///
/// Its own pass, on its own erased device, because saving a goal is a one-way door.
///
/// ## Why this is one test and not six
///
/// `reference/planner` is a figure of a planner with **no session goals**, and `sessions/goals` is a
/// figure of the same screen with two. Once a goal exists there is no way back short of erasing the
/// device, so the two figures are ordered by construction — and XCTest orders *test methods*, not
/// intentions. Split across two tests, `testGoalSequence` sorts before `testPlannerBeforeAnyGoal`
/// and the empty-planner figure would be shot on a planner with two goals in it: right screen, wrong
/// state, green run.
///
/// So the whole of session 5 is one method that shoots each state as it reaches it. It is longer than
/// the house style likes and it is the only shape that is correct.
final class ManualSessionShots: ManualShotCase {

    /// The six figures of the planner, in the order the states can exist.
    ///
    /// 1. `reference/planner` — nothing added for today
    /// 2. `sessions/goal-templates` — the ten starting points
    /// 3. `sessions/goal-editor` — one of them, opened
    /// 4. `sessions/goals` — two saved, in the This session section
    /// 5. `sessions/planner` — the whole screen with them on it
    /// 6. `sessions/review` — what Generate produced
    @MainActor
    func testSessionPlanning() {
        let app = launchForShoot()
        openPlanner(in: app)

        // 1. The empty planner. `Nothing extra for today` is what the marker's *no goals yet* means —
        // it is the one thing on this screen that a saved goal removes, and the two seeded long-term
        // goals below it are a different section that belongs in the picture.
        capture(app, slug: "reference/planner",
                assertingOnScreen: "Today's session",
                alsoRequiring: ["How long do you have?", "Away from your instrument",
                                "Add a goal for this session", "Generate today's session"],
                orBeginningWith: ["Quick ·", "Nothing extra for today"])

        // 2. The template picker, and it took two wrong gates to get here.
        //
        // **Every row is reached by prefix, never by name.** `GoalAuthoringSections` builds each one
        // as a `Button` wrapping a title *and* a blurb, so SwiftUI combines the children and the
        // label is "Build speed, <blurb>" — one element, not two. Exact-match queries find nothing.
        // `element(in:labelStartingWith:)` warns about this in its own doc comment.
        //
        // **And the gate is the navigation bar, not `Something else`.** That row is the last thing
        // on the screen, under ten title-and-blurb rows, so it begins below the fold and therefore
        // outside the tree — a gate that cannot resolve until the screen is scrolled reports an
        // opened sheet as a sheet that never opened, which is exactly how this failed twice. The bar
        // is sound here despite also titling the form behind it, because the screen being left is
        // the planner, whose bar says `Today's session`.
        tap(app.buttons["Add a goal for this session"], labelled: "Add a goal",
            revealing: app.navigationBars["New goal"], called: "the goal template picker")

        capture(app, slug: "sessions/goal-templates",
                assertingOnScreen: "New goal",
                orBeginningWith: ["Pick a starting point", "Play a specific song", "Build speed",
                                  "Improvise in a style", "Something else"])

        // 3. The form behind one of them. Same navigation bar, different state — so the assertion has
        // to be something only the form has. The priority control is that: three segments the picker
        // step does not draw.
        tap(element(in: app, labelStartingWith: "Build speed"), labelled: "Build speed",
            revealing: app.buttons["Normal"], called: "the goal editor")

        capture(app, slug: "sessions/goal-editor",
                assertingOnScreen: "New goal",
                alsoRequiring: ["Priority", "Low", "Normal", "High", "Skills"])

        // 4. Save it, add a second, and shoot the section they land in.
        saveGoal(in: app)
        addGoal("Tighten your timing", in: app)

        scrollIntoFrame(element(in: app, labelStartingWith: "Tighten your timing"),
                        called: "the second goal", in: app)
        capture(app, slug: "sessions/goals",
                assertingOnScreen: "Today's session",
                orBeginningWith: ["This session", "Build speed", "Tighten your timing"])

        // 5. The whole screen with both on it. A separate frame from `sessions/goals`, which is a
        // `role: panel` crop of the section: this one has to reach the length control at the top and
        // Generate at the bottom, and after two goals the screen is taller than it was at step 1.
        scrollIntoFrame(app.staticTexts["How long do you have?"],
                        called: "the length control", in: app)
        capture(app, slug: "sessions/planner",
                assertingOnScreen: "Today's session",
                alsoRequiring: ["How long do you have?", "Away from your instrument",
                                "Generate today's session"],
                orBeginningWith: ["Build speed"])

        // 6. Generate. The review screen is a provisional `RoutineDetailView` whose navigation title
        // is the **dated draft name** — different every day — so there is no fixed title to gate on
        // and this takes the chromeless path. `Save` in the toolbar is what makes it the review
        // screen rather than a saved routine.
        tap(app.buttons["Generate today's session"], labelled: "Generate today's session",
            revealing: app.buttons["Save"], called: "the review screen")

        captureChromeless(app, slug: "sessions/review",
                          screen: "the generated session, under review",
                          ownedBy: ["Save"],
                          orBeginningWith: ["Estimated length"])
    }

    // MARK: - Steps

    /// Save whatever is open in the goal editor and wait for the planner to come back.
    @MainActor
    private func saveGoal(in app: XCUIApplication) {
        tap(app.buttons["Save"], labelled: "Save",
            revealing: app.buttons["Add a goal for this session"], called: "the planner")
    }

    /// Add a goal from a named template, start to finish.
    @MainActor
    private func addGoal(_ template: String, in app: XCUIApplication) {
        // Bar as the gate, prefix for the row — both for the reasons spelled out at the picker's
        // first use above.
        tap(app.buttons["Add a goal for this session"], labelled: "Add a goal",
            revealing: app.navigationBars["New goal"], called: "the goal template picker")
        // Scrolled to before it is tapped: the templates are ten title-and-blurb rows, so which of
        // them start on screen depends on the name, and a caller naming one near the bottom would
        // otherwise fail as though the picker had not opened.
        let row = element(in: app, labelStartingWith: template)
        scrollIntoFrame(row, called: "the '\(template)' template", in: app)
        tap(row, labelled: template,
            revealing: app.buttons["Normal"], called: "the goal editor")
        saveGoal(in: app)
        note("added the '\(template)' goal")
    }

    // MARK: - Navigation

    /// Home ▸ Practice ▸ `Today's session`.
    @MainActor
    private func openPlanner(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])

        tapRow(labelStartingWith: "Today's session", in: app,
               arrivingAt: app.navigationBars["Today's session"], called: "the planner")
    }
}
