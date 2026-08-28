import XCTest

/// The manual's **Today's session** figures (ADR 0165, Phase 5) — the goals that steer a session,
/// the editor behind one of them, and the session Generate produces.
///
/// Its own pass, on its own erased device, because saving a goal is a one-way door.
///
/// ## Why this is one test and not four
///
/// Every figure here is of a planner in a *later* state than the one before it, and there is no way
/// back short of erasing the device. XCTest orders test methods, not intentions, so split across
/// four tests the earliest state would be shot last: right screen, wrong state, green run. One
/// method that shoots each state as it reaches it is longer than the house style likes and is the
/// only shape that is correct.
///
/// **Two figures were cut in Phase 5** — `reference/planner`, the planner before anything was asked
/// of it, and `sessions/goal-templates`, the ten starting points. The templates are a table in the
/// prose, which is the form that can be checked against the source; a photograph of the same ten
/// rows is a second copy that cannot. Losing the empty-planner figure also cost this class its
/// hardest ordering constraint, since every remaining figure has at least one goal in it.
final class ManualSessionShots: ManualShotCase {

    /// The four figures of the planner, in the order the states can exist.
    ///
    /// 1. `sessions/goals` — two saved, in the This session section
    /// 2. `sessions/goal-editor` — one of them reopened
    /// 3. `sessions/planner` — the whole screen with them on it
    /// 4. `sessions/review` — what Generate produced
    @MainActor
    func testSessionPlanning() {
        let app = launchForShoot()
        openPlanner(in: app)

        // 1. Two goals, and the section they land in.
        //
        // **Every template row is reached by prefix, never by name.** `GoalAuthoringSections` builds
        // each one as a `Button` wrapping a title *and* a blurb, so SwiftUI combines the children and
        // the label is "Build speed, <blurb>" — one element, not two. Exact-match queries find
        // nothing. `element(in:labelStartingWith:)` warns about this in its own doc comment.
        addGoal("Build speed", in: app)
        addGoal("Tighten your timing", in: app)

        scrollIntoFrame(element(in: app, labelStartingWith: "Tighten your timing"),
                        called: "the second goal", in: app)
        capture(app, slug: "sessions/goals",
                assertingOnScreen: "Today's session",
                orBeginningWith: ["This session", "Build speed", "Tighten your timing"])

        // 2. One of them **reopened**, which is a different screen from the one a template opens.
        //
        // This used to shoot the editor on the way in, straight off a template, and the frame it
        // produced was titled `New goal`. A reopened goal is titled `Edit goal` and carries two
        // controls the new-goal form has not got — `Mark as met` and `Delete goal` — and those are
        // what the page beside the figure spends its paragraphs on. So the figure is taken on the
        // way back in, and the navigation bar is the assertion that proves which of the two screens
        // is in the picture.
        tap(element(in: app, labelStartingWith: "Tighten your timing"), labelled: "the saved goal",
            revealing: app.buttons["Normal"], called: "the goal editor")

        capture(app, slug: "sessions/goal-editor",
                assertingOnScreen: "Edit goal",
                alsoRequiring: ["Priority", "Low", "Normal", "High", "Skills",
                                "Mark as met", "Delete goal"])

        // Cancel, not Save — the goal is already as this pass wants it, and a Save here would be a
        // write made only to close a sheet.
        tap(app.buttons["Cancel"], labelled: "Cancel",
            revealing: app.buttons["Add a goal for this session"], called: "the planner")

        // 3. The whole screen with both on it — the length control at the top through Generate at
        // the bottom.
        //
        // Declared in `docs/manual-shoot-list.md` as *same frame as* `sessions/goals`, and on the
        // hand shot it genuinely was: Today's session fits in one screen, so the scroll below
        // changes nothing and the two captures come back byte-identical. That is why the pair is
        // named there — an undeclared duplicate is the signature of a missed tap, and the check
        // that looks for it has no way to tell this one apart.
        scrollIntoFrame(app.staticTexts["How long do you have?"],
                        called: "the length control", in: app)
        capture(app, slug: "sessions/planner",
                assertingOnScreen: "Today's session",
                alsoRequiring: ["How long do you have?", "Away from your instrument",
                                "Generate today's session"],
                orBeginningWith: ["Build speed"])

        // 4. Generate. The review screen is a provisional `RoutineDetailView` whose navigation title
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
        // **The gate is the navigation bar, not a row.** `Something else` is the last thing on the
        // picker, under ten title-and-blurb rows, so it begins below the fold and therefore outside
        // the tree — a gate that cannot resolve until the screen is scrolled reports an opened sheet
        // as a sheet that never opened, which is exactly how this failed twice. The bar is sound
        // despite also titling the form behind it, because the screen being left is the planner,
        // whose bar says `Today's session`. The row itself is taken by prefix, per the note in
        // `testSessionPlanning`.
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
