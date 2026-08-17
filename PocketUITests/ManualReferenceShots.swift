import XCTest

/// The user manual's **Where you learned it** figures (ADR 0167, manual page `references.md`),
/// driven against the seeded library.
///
/// Written with the feature rather than after it, which is the manual's own rule 8 applied to the
/// capture as well as the marker. The navigation it does — Home ▸ Practice ▸ Exercises ▸ a drill ▸
/// its ⓘ — is the route the eleven still-unshot `exercises/*` figures need too, so it lives in a
/// helper here rather than inline.
///
/// The two links themselves are **seeded** (`PracticeHistorySeed.seedReferences`); the editor sheet
/// is **driven**. Typing a URL through the keyboard is where a UI test goes wrong — autocorrect, a
/// missed dismissal, a `.` landing as `,` — so the flow a player takes is photographed while the
/// data behind it is not typed.
final class ManualReferenceShots: ManualShotCase {

    /// `references/section` — the section on an exercise's detail sheet, with two links on it.
    @MainActor
    func testReferencesSection() {
        let app = launchForShoot()
        openExerciseDetail(in: app)

        // Fourth of six sections, so it opens below the fold. Two things this got wrong first:
        // scrolling on hittability rather than frame containment (which returns happy with the
        // section off-screen), and then scrolling to the section's *header*, which leaves the rest
        // of it below the fold. Aim at the last element the figure needs — the button.
        scrollIntoFrame(app.buttons["Add a link"], called: "Add a link", in: app)

        capture(app, slug: "references/section",
                assertingOnScreen: "Alternate Picking",
                alsoRequiring: ["Where you learned it",
                                "The lesson this came from",
                                "Tab for the whole run",
                                "Add a link"])
    }

    /// `references/editor` — the Add a link sheet, with something on the clipboard so the paste
    /// affordance is in the picture.
    ///
    /// **The clipboard is set before the sheet opens**, because the paste row is decided when the
    /// body evaluates. Setting it afterwards produces a sheet with no paste button and a figure whose
    /// alt text promises one — a clean photograph of the wrong state, which is the failure this whole
    /// harness is built against, so it is asserted rather than assumed.
    @MainActor
    func testReferenceEditor() {
        let app = launchForShoot()
        UIPasteboard.general.string = "https://example.com/lessons/legato-runs"
        openExerciseDetail(in: app)

        let addLink = app.buttons["Add a link"]
        scrollIntoFrame(addLink, called: "Add a link", in: app)
        // Gated on an identifier the app sets, after two gates that guessed at somebody else's text
        // failed — see `UITestHooks.referenceLinkField`. What none of those gates could tell us was
        // that the app was wrong: the tap was dismissing the *detail sheet*, and only an
        // unconditional dump of the accessibility hierarchy said so. `ReferenceLinkEditing` carries
        // the fix and the reasoning.
        tap(addLink, labelled: "Add a link",
            revealing: app.textFields[UITestHooks.referenceLinkField], called: "the editor sheet")

        // `Paste` is asserted, having been read off the shipped frame rather than assumed: the
        // system control does surface with that label, so the marker's alt text can promise it.
        capture(app, slug: "references/editor",
                assertingOnScreen: "Add a link",
                alsoRequiring: ["Link", "Name", "Paste"])
    }

    // MARK: - Navigation

    /// Home ▸ Practice ▸ Exercises ▸ Alternate Picking ▸ ⓘ.
    ///
    /// Each hop gates on something the *destination* owns and the screen we are leaving does not —
    /// the rule `tapHomeCard` was written for. "Practice" is a word Home says on its own card, so the
    /// arrival is the hub's navigation bar, not that text.
    @MainActor
    private func openExerciseDetail(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Practice card on Home. \(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])

        tapRow(labelStartingWith: "Exercises", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the exercise library")

        // Pinned by name to the drill the seed hangs its links on. A prefix match on the row rather
        // than an exact label, because the row carries its tempo and template after the name.
        tapRow(labelStartingWith: "Alternate Picking", in: app,
               arrivingAt: app.buttons["Exercise details"], called: "the run screen")

        let info = app.buttons["Exercise details"]
        tap(info, labelled: "Exercise details",
            revealing: app.staticTexts["Where you learned it"], called: "the detail sheet")
    }

}
