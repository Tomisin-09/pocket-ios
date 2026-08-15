import XCTest

/// The user manual's Home, Journal and Progress figures, driven (ADR 0165, Phase 5).
///
/// Committed rather than thrown away, because the manual is re-shot every time a screen changes and
/// a shoot nobody can repeat is a shoot that silently goes stale. `docs/manual/shots.md` is the
/// manifest; each test here names the slugs it produces, so a marker and its capture stay findable
/// from either end. The machinery — launch, capture, step log — is `ManualShotCase`.
final class ManualShotsUITests: ManualShotCase {

    /// `journal/timeline` · `reference/journal` — the timeline with notes and a take across two days.
    @MainActor
    func testJournalTimeline() {
        let app = launchForShoot()
        openJournal(in: app)
        capture(app, slug: "journal/timeline", assertingOnScreen: "Journal")
    }

    /// `journal/take-row` — the Takes filter, for the row crop.
    @MainActor
    func testJournalTakes() {
        let app = launchForShoot()
        openJournal(in: app)

        // The filter is a segmented `Picker`, so its options are buttons *inside* a segmented
        // control, not buttons on the screen. `app.buttons["Takes"]` finds nothing.
        let takes = app.segmentedControls.buttons["Takes"]
        XCTAssertTrue(takes.waitForExistence(timeout: Self.shootTimeout),
                      "the All / Notes / Takes filter never appeared. \(stepLog)")
        takes.tap()
        note("tapped Takes")

        capture(app, slug: "journal/take-row", assertingOnScreen: "Journal")
    }

    /// `journal/progress` · `reference/progress` — the screen as it opens. Then `journal/month-heatmap`.
    ///
    /// **Two frames, not one.** These were written as three crops of a single capture, and that was
    /// wrong: This week, the month grid, All-time and *What you've built* come to well over one
    /// screen on the master device, so a frame holding all three sections does not exist to be shot.
    /// The first attempt at making it fit added a `swipeUp`, which produced a figure with This week
    /// scrolled off the top and the This month header sliced in half by the navigation bar — and it
    /// passed, because a section above the top of the screen is still in the accessibility tree. Both
    /// markers' alt text described three sections that were never in the picture.
    ///
    /// So: the screen figure is the screen **as it opens**, unscrolled, which is what a reader sees on
    /// arriving; and the heatmap gets the separate capture its `role: panel` always implied.
    @MainActor
    func testProgress() {
        let app = launchForShoot()
        openJournal(in: app)

        // Two taps, both retried, because both are the swallowed-tap shape. Opening the ⋯ menu is
        // where a cold run actually broke: the button was found, the event was synthesised, and the
        // menu never came up. `Progress` is the only thing that proves it did — the menu draws no
        // container of its own that the timeline underneath does not also have.
        let options = app.buttons["Journal options"]
        XCTAssertTrue(options.waitForExistence(timeout: Self.shootTimeout),
                      "the Journal options (⋯) button never appeared. \(stepLog)")

        let progress = app.buttons["Progress"]
        tap(options, labelled: "Journal options", revealing: progress, called: "the ⋯ menu")

        // `THIS WEEK` is the Progress screen's first section, and — unlike the word "Progress" — it
        // is not also the name of the control we just tapped. Gating on "Progress" here would be the
        // metronome mistake again: an assertion that is already true of the menu we are leaving.
        tap(progress, labelled: "Progress",
            revealing: app.staticTexts["THIS WEEK"], called: "the Progress screen")

        // No scroll. `THIS WEEK` is the first section and is required *in frame* — with the old
        // existence check this same assertion passed on a screen scrolled well past it.
        capture(app, slug: "journal/progress",
                assertingOnScreen: "Progress",
                alsoRequiring: ["THIS WEEK"])

        // The panel figure: the month grid and the key that explains its shading. `Less` and `More`
        // sit at the bottom of the grid, so requiring both in frame is what proves the whole grid is
        // in the picture — and that the scroll below did not carry it past.
        app.swipeUp(velocity: .slow)
        note("swiped up to bring the month grid and its key into frame")

        capture(app, slug: "journal/month-heatmap",
                assertingOnScreen: "Progress",
                alsoRequiring: ["Less", "More"])
    }

    /// `reference/home` — Home with something recently practised.
    @MainActor
    func testHome() {
        let app = launchForShoot()
        // `Jump back in` is the state this figure is *of*, and it only draws when a song carries a
        // `lastPracticed`. Asserting the nav title alone passed this test while photographing a Home
        // with no resume card on it — a clean picture of the wrong state.
        // `JUMP BACK IN`, not `Jump back in`: the eyebrow is set in caps as typography, and the
        // accessibility tree carries the literal. The manual's prose quotes it the other way round
        // (C9 — a name is written as the app writes it, not as a screen sets it), so the two will
        // not match and are not meant to.
        capture(app, slug: "reference/home",
                assertingOnScreen: "Red Moon",
                alsoRequiring: ["JUMP BACK IN"])
    }

    // MARK: - Navigation

    /// Home ▸ `Journal`. Every journal shot starts here, so the assertion lives in one place.
    ///
    /// The card is a `NavigationLink` carrying an explicit `.accessibilityLabel`, so its label in the
    /// tree is the whole sentence and **not** the "Journal" written on it. `app.buttons["Journal"]`
    /// finds nothing and three shots fail at once — which is how this was found.
    @MainActor
    private func openJournal(in app: XCUIApplication) {
        // Exact-label, never a prefix: inside a pushed screen the back control carries the previous
        // screen's title, and a loose match pops the stack and photographs Home instead — green.
        // Arrival is the ⋯ button, not the word "Journal" — Home's card says "Journal" as well, and a
        // gate that is already true on the screen you are leaving proves nothing.
        tapHomeCard("Journal, your notes and practice takes",
                    in: app,
                    arrivingAt: app.buttons["Journal options"])
    }
}
