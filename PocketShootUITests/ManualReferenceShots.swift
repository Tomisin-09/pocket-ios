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

    /// `references/section` — the section on an exercise's References screen, with two links on it.
    @MainActor
    func testReferencesSection() {
        let app = launchForShoot()
        openExerciseDetail(in: app)
        openReferences(in: app)

        // The section is the References screen's only one since ADR 0258, so it is in frame as it opens.
        // It used to be fourth of six on the sheet, which took a scroll aimed at its last element and then
        // a drag to settle the heading back into frame; a drag on a screen this short pulls the sheet
        // down instead, so neither is done. Waited for, because the screen is still arriving.
        let addFile = app.buttons["Add a file"]
        XCTAssertTrue(addFile.waitForExistence(timeout: Self.shootTimeout),
                      "the References screen has no Add a file.\n\(stepLog)")

        capture(app, slug: "references/section",
                assertingOnScreen: "References",
                alsoRequiring: ["Where you learned it",
                                "The lesson this came from",
                                "Tab for the whole run",
                                "Add a link",
                                "Add a file"],
                orBeginningWith: ["The pattern, written out"])
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
        openReferences(in: app)

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
                alsoRequiring: ["Link", "Name", "Note", "Paste"])
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

        // The Practice hub is shelves since ADR 0257: the Exercises shelf's *All* link opens the
        // library, through the UI tests' own helper.
        note("open the Exercises library from its shelf")
        openPracticeLibrary("Exercises", in: app)

        // Pinned by name to the drill the seed hangs its links on. A prefix match on the row rather
        // than an exact label, because the row carries its tempo and template after the name.
        tapRow(labelStartingWith: "Alternate Picking", in: app,
               arrivingAt: app.buttons["Exercise details"], called: "the run screen")

        // Gated on the sheet's *Folders* row, which sits near the top. *Where you learned it* used to
        // be the gate, until sections above it (Songs among them) pushed it below the fold, where a
        // lazy list hasn't built it: the sheet opened every time and the gate could never see it.
        // Since ADR 0258 Folders is a row whose label carries its value, so it is matched by its start.
        let info = app.buttons["Exercise details"]
        tap(info, labelled: "Exercise details",
            revealing: element(in: app, labelStartingWith: "Folders"), called: "the detail sheet")
    }

    /// The detail sheet's **References** row (ADR 0258), where *Where you learned it* now lives.
    @MainActor
    private func openReferences(in app: XCUIApplication) {
        tap(element(in: app, labelStartingWith: "References"), labelled: "References",
            revealing: app.navigationBars["References"], called: "the References screen")
    }
}
