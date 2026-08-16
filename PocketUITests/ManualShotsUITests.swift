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

        // A segmented option opens no destination, so `tap(_:revealing:)` has nothing to gate on and
        // this step has to prove the filter moved by other means. It matters more here than the
        // missing gate suggests: **All** shows the same take this figure is of, with the seeded notes
        // above it, so a swallowed tap yields a clean, plausible, wrong photograph — the exact failure
        // the rest of this harness is built against.
        //
        // Two assertions, because neither alone is sufficient. `isSelected` proves the picker's state
        // moved but not that the list redrew; the vanished note proves the list redrew but would also
        // hold if the timeline had simply failed to load. Waited on rather than read, since the filter
        // animates and the tap returns before it settles.
        let selected = expectation(for: NSPredicate(format: "isSelected == true"),
                                   evaluatedWith: takes)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: Self.shootTimeout), .completed,
                       "tapped Takes and the picker never moved off All. \(stepLog)")

        let aNote = app.staticTexts["The bend still lands flat when I take it above three quarters speed."]
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: aNote)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: Self.shootTimeout), .completed,
                       "the Takes filter is selected but a seeded note is still in the timeline, so "
                       + "this frame is of the unfiltered list. \(stepLog)")
        note("the timeline is filtered to takes")

        capture(app, slug: "journal/take-row", assertingOnScreen: "Journal")
    }

    /// `journal/progress` · `reference/progress` · `journal/month-heatmap` — one frame, three markers.
    ///
    /// **The screen as it opens, unscrolled.** An earlier version added a `swipeUp` to bring All-time
    /// into shot, which pushed This week off the top — and passed, because a section above the frame
    /// is still in the accessibility tree at its true offset. The image that came back showed This
    /// month and All-time while both markers' alt text promised a bar chart that was not in it.
    ///
    /// Splitting the heatmap into its own scrolled capture was the next attempt, and was an
    /// overcorrection: the unscrolled frame already holds This week's chart, the complete month grid
    /// and its key, with nothing occluded. The scrolled version only added a `THIS MONTH` header
    /// sliced by the navigation bar. So the three markers share this frame again — the fault was
    /// never the sharing, it was the scroll.
    ///
    /// All-time begins at the foot of the frame and is cut, which the alt text says.
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

        // No scroll, and one frame for all three markers. `THIS WEEK` is the first section; `Less` and
        // `More` are the key under the month grid, so requiring all three *in frame* is what proves
        // both ends of the picture fit — the bar chart at the top, the whole grid and its key at the
        // bottom. If they ever stop fitting, this fails and says so.
        capture(app, slug: "journal/progress",
                assertingOnScreen: "Progress",
                alsoRequiring: ["THIS WEEK", "Less", "More"])
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
