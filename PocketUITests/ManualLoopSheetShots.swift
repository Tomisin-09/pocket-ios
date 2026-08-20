import XCTest

/// The sheets that open **from** the song player (ADR 0165, Phase 5) — Edit loop, the automator, the
/// tempo editor, and the two ⓘ popovers inside the loop editor that the glossary page illustrates.
///
/// Split from `ManualPlayerShots` so neither file carries the whole player area, and because these
/// have a property the player does not: every one of them **has a navigation bar**, so they take the
/// ordinary `capture` path with its strong screen gate, while the screen underneath them cannot.
///
/// All of them are read-only. `Edit loop` is opened and photographed, never saved — the sheet edits a
/// local copy and `Cancel` discards it (`writeEdits` runs on Done), so the pass leaves the loops
/// exactly as the seed wrote them.
final class ManualLoopSheetShots: ManualShotCase {

    /// `reference/loop-edit` — the top of the Edit loop sheet.
    ///
    /// Reached by **holding the loop row and choosing `Edit`** — the row's context menu offers Edit,
    /// Adjust range and Delete. Note the menu item is `Edit`, not `Edit loop`; `Edit loop` is the
    /// sheet's title, and aiming the tap at the title would find nothing.
    ///
    /// The figure is the top of the sheet: Name, Favourite, Range, and the Practice **header**.
    ///
    /// **Its alt text used to promise more than the frame holds** — Mastery, Focus, Type and Command
    /// tempo as well — and requiring `Mastery` failed here with *on 'Edit loop' but 'Mastery' was not
    /// in the frame*. The header fits and the rows beneath it do not; those four are what
    /// `looping/loop-edit-practice` is for, one scroll further down. The marker now says so, which is
    /// the right correction: the alternative is a `swipeUp` that makes the figure "fit" by pushing
    /// Name and Range out of the top, which is how `journal/progress` was once shot.
    @MainActor
    func testLoopEdit() {
        let app = launchForShoot()
        openLoopEditor(in: app)

        capture(app, slug: "reference/loop-edit",
                assertingOnScreen: "Edit loop",
                alsoRequiring: ["Name", "Favourite", "Range", "Loop", "Practice"])
    }

    /// `looping/loop-edit-practice` — the Practice section, scrolled into the frame.
    ///
    /// A `role: panel` crop, so the section has to be **in the picture**, not merely on the screen.
    /// `scrollIntoFrame` is aimed at `Command tempo`, the *last* of the four rows the marker names —
    /// stopping at the section header would leave the rest below the fold, which is how the
    /// references figure failed twice before this rule was written down.
    @MainActor
    func testLoopEditPractice() {
        let app = launchForShoot()
        openLoopEditor(in: app)

        scrollIntoFrame(element(in: app, labelStartingWith: "About Command tempo"),
                        called: "the Command tempo row", in: app)

        capture(app, slug: "looping/loop-edit-practice",
                assertingOnScreen: "Edit loop",
                alsoRequiring: ["Practice", "Mastery", "Focus", "Type", "Command tempo"])
    }

    /// `terms/mastery-info` · `terms/info-button` — the Mastery row with its ⓘ popover open.
    ///
    /// The ⓘ carries the label `About Mastery` (`FieldInfoLabel`), which is what makes it findable
    /// and also what makes it a good gate: the popover's own text is `PracticeFieldInfo.mastery`,
    /// app copy that the Help & FAQs catalogue quotes verbatim, so asserting a prefix of it here ties
    /// the figure to the same string the FAQ is pinned to.
    ///
    /// `terms/info-button` needs only an ⓘ somewhere in the frame and is served by this one.
    @MainActor
    func testMasteryInfo() {
        let app = launchForShoot()
        openLoopEditor(in: app)

        let info = element(in: app, labelStartingWith: "About Mastery")
        scrollIntoFrame(info, called: "the Mastery ⓘ", in: app)
        tap(info, labelled: "the Mastery ⓘ",
            revealing: element(in: app, labelStartingWith: "How cleanly you own this loop"),
            called: "the Mastery popover")

        capture(app, slug: "terms/mastery-info",
                assertingOnScreen: "Edit loop",
                alsoRequiring: ["Mastery"],
                orBeginningWith: ["How cleanly you own this loop"],
                alsoServing: ["terms/info-button"])
    }

    /// `terms/command-tempo-info` — the same, on Command tempo.
    @MainActor
    func testCommandTempoInfo() {
        let app = launchForShoot()
        openLoopEditor(in: app)

        let info = element(in: app, labelStartingWith: "About Command tempo")
        scrollIntoFrame(info, called: "the Command tempo ⓘ", in: app)
        tap(info, labelled: "the Command tempo ⓘ",
            revealing: element(in: app, labelStartingWith: "The fastest speed you own this loop at"),
            called: "the Command tempo popover")

        capture(app, slug: "terms/command-tempo-info",
                assertingOnScreen: "Edit loop",
                alsoRequiring: ["Command tempo"],
                orBeginningWith: ["The fastest speed you own this loop at"])
    }

    /// `reference/loop-automator` · `looping/automator` — the per-loop speed ramp (ADR 0013).
    ///
    /// Opened from the row's **automator button**, not from its context menu: the menu offers Edit,
    /// Adjust range and Delete, and the automator has a control of its own beside the row labelled
    /// `Set up automator for <loop>`.
    ///
    /// Two markers, one frame — `looping/automator` and the reference figure describe the same sheet.
    /// The shoot list flagged their alt lines as needing to be checked against each other; they name
    /// the same four fields above the same summary, so one frame serves both.
    @MainActor
    func testAutomator() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let automator = app.buttons["Set up automator for Verse riff"]
        tap(automator, labelled: "the Verse riff automator button",
            revealing: app.navigationBars["Automator"], called: "the Automator sheet")

        capture(app, slug: "reference/loop-automator",
                assertingOnScreen: "Automator",
                alsoServing: ["looping/automator"])
    }

    /// `reference/tempo-editor` · `looping/tempo-editor` — the tap-tempo / manual BPM sheet.
    ///
    /// Reached from the metronome glyph in the speed bar, whose label is `Set tempo` — the same words
    /// as the sheet's title, so the gate is the **navigation bar** rather than the phrase, which the
    /// button already carries before anything opens.
    @MainActor
    func testTempoEditor() {
        let app = launchForShoot()
        openSlowBend(in: app)

        let setTempo = app.buttons["Set tempo"]
        tap(setTempo, labelled: "Set tempo",
            revealing: app.navigationBars["Set tempo"], called: "the tempo sheet")

        capture(app, slug: "reference/tempo-editor",
                assertingOnScreen: "Set tempo",
                alsoServing: ["looping/tempo-editor"])
    }

    // MARK: - Navigation

    /// Slow Bend, then **hold a loop row** — which opens the Edit loop sheet directly.
    ///
    /// **There is no menu in between, and the manual said there was.** `reference/song-player.md`
    /// read *"Hold a row for its menu, including `Edit loop`"*, and the row has no `contextMenu` at
    /// all: `WaveformPanels` attaches an explicit `onLongPressGesture` that calls `onEdit()`, and the
    /// Edit / Adjust range / Delete triple lives in `.accessibilityActions` — custom VoiceOver
    /// actions, which are not a menu anyone can see or tap.
    ///
    /// **C9 could not have caught it.** That check asks whether backticked control names are real
    /// on-screen strings, and `Edit loop` is one — it is the sheet's own title. The name was true and
    /// the sentence around it was false, which is the same shape as the `Relink` control the manual
    /// claimed for months. The prose is now corrected.
    ///
    /// It cost four tests a run to find, and the failure was legible only because the hold retried:
    /// gate one on a menu item that does not exist, and the sheet opens anyway, covers the row, and
    /// the second attempt reports the row as unreachable.
    @MainActor
    private func openLoopEditor(in app: XCUIApplication) {
        openSlowBend(in: app)
        hold(app.buttons["Play Verse riff"], labelled: "the Verse riff row",
             revealing: app.navigationBars["Edit loop"], called: "the Edit loop sheet")
    }
}
