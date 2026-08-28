import XCTest

/// The user manual's Home, Journal and Practice log figures, driven (ADR 0165, Phase 5).
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
        capture(app, slug: "journal/timeline", assertingOnScreen: "Journal",
                alsoServing: ["reference/journal"])
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

    /// `journal/take-trim` — trim mode, with the handles on the strip and the keep-span readout.
    @MainActor
    func testTakeTrim() {
        let app = launchForShoot()
        openTakeDetail(in: app)

        let actions = app.buttons["Take actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: Self.shootTimeout),
                      "the take's actions menu never appeared. \(stepLog)")
        actions.tap()
        note("opened the take actions menu")

        // The trim item is `Trim…` with a real ellipsis character, not three dots.
        let trim = app.buttons["Trim…"]
        XCTAssertTrue(trim.waitForExistence(timeout: Self.shootTimeout),
                      "no Trim item in the take's menu. \(stepLog)")
        trim.tap()
        note("entered trim mode")

        // Trim mode is proven by the strip changing role, not by the menu having been tapped — a
        // swallowed tap leaves a perfectly plausible take screen, which is the failure this whole
        // harness exists against.
        let strip = app.otherElements["Trim range"]
        XCTAssertTrue(strip.waitForExistence(timeout: Self.shootTimeout),
                      "tapped Trim and the scrubber never became a trim range. \(stepLog)")
        note("the strip is a trim range")

        // Gated on the strip's role above, not on the keep-span readout: that sits below the
        // transport and can be under the fold on a short device, which is a framing question for
        // whoever crops the figure rather than evidence the app is in the wrong state.
        capture(app, slug: "journal/take-trim", assertingOnScreen: "Take")
    }

    /// `journal/take-moments` — the pins on the strip and the Moments list beneath (ADR 0175).
    ///
    /// **No scroll and no tap beyond opening the take.** The seed writes the take's two moments
    /// (`PracticeHistorySeed.seedTake`), so the section is populated the moment the screen appears —
    /// which is the whole reason the seed writes them rather than the shoot adding them by hand: a
    /// figure of a list is a figure of a list with rows in it, and driving the editor twice to fill
    /// one would put two sheet dismissals between the launch and the frame.
    ///
    /// Gated on the **Moments section's own add control**, not on the words "Add note here": the
    /// take's actions menu carries an item with the same label, so a label query has two hits on
    /// this screen and picks whichever it orders first — the same class of mistake `takeRowOpen`
    /// exists for.
    @MainActor
    func testTakeMoments() {
        let app = launchForShoot()
        openTakeDetail(in: app)

        let add = app.buttons[UITestHooks.takeAddMoment]
        XCTAssertTrue(add.waitForExistence(timeout: Self.shootTimeout),
                      "the take screen has no Moments section. \(stepLog)")
        note("the Moments section is on screen")

        // The rows are the subject. A seeded moment's timecode button is the one element that can
        // only exist if a `TakeNote` was read back off the store and rendered — an empty section
        // still has its heading and its add control, and would photograph as a plausible screen.
        let moment = app.buttons["Play from 0:12"]
        XCTAssertTrue(moment.waitForExistence(timeout: Self.shootTimeout),
                      "the Moments section is empty — the seeded take's notes never landed. \(stepLog)")
        note("a seeded moment is in the list")

        // **One frame, two markers — declared, because it was being shot twice.**
        // `journal/take-detail` had a test of its own that did exactly what this one does: open the
        // take, capture, no scroll and no interaction between them. The two markers carry the *same*
        // `state:` ("seeded library, Journal, a take opened") and differ only in which half of the
        // screen their alt text reads — the strip and transport, or the pins and the Moments list.
        // So two byte-identical images were being filed under two names.
        //
        // That is not merely wasteful: identical images are the signature this shoot uses to detect a
        // missed tap, and an undeclared duplicate spends that signal. `./scripts/shoot-progress.py
        // --verify` flagged exactly this pair. `alsoServing` is what the harness already provides for
        // a frame shown on a second page, and `Take position` comes across from the deleted test so
        // the transport is still asserted.
        capture(app, slug: "journal/take-moments", assertingOnScreen: "Take",
                alsoRequiring: ["Moments", "Take position"],
                alsoServing: ["journal/take-detail"])
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
    func testPracticeLog() {
        let app = launchForShoot()
        openJournal(in: app)

        // One tap now, not two. This figure used to be reached through the ⋯ menu, and that hop was
        // the shoot's second recurring failure — the button was found, the event was synthesised, and
        // the menu never came up (see `tap(_:labelled:revealing:called:)`). ADR 0176 moved the
        // practice log onto a row on the Journal itself, so the menu that swallowed the tap is no
        // longer on the path. The retry stays: the row is still an unguarded tap, which is the shape
        // that recurs.
        let row = app.buttons["Practice log"]
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout),
                      "the Practice log row never appeared on the Journal. \(stepLog)")

        // `THIS WEEK` is the screen's first section, and — unlike "Practice log" — it is not also the
        // name of the control we just tapped. Gating on "Practice log" here would be the metronome
        // mistake again: an assertion already true of the screen we are leaving.
        tap(row, labelled: "Practice log",
            revealing: app.staticTexts["THIS WEEK"], called: "the Practice log screen")

        // No scroll, and one frame for all three markers. `THIS WEEK` is the first section; `Less` and
        // `More` are the key under the month grid, so requiring all three *in frame* is what proves
        // both ends of the picture fit — the bar chart at the top, the whole grid and its key at the
        // bottom. If they ever stop fitting, this fails and says so.
        // The slug stays `journal/progress`: a shot slug is an id, and renaming it would orphan
        // every already-captured frame that names it (ADR 0176).
        capture(app, slug: "journal/progress",
                assertingOnScreen: "Practice log",
                alsoRequiring: ["THIS WEEK", "Less", "More"],
                alsoServing: ["reference/progress", "journal/month-heatmap"])
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
        // `getting-started/home` was briefly its own frame at `hour: 19`, because its marker asked
        // for an evening greeting. It photographed "Good evening" above the 09:41 status bar the
        // shoot fakes for every figure — the same contradiction the retired wall-clock gate existed
        // to prevent, arriving from the other direction. The status bar is set once per run and the
        // greeting was the only thing that could move, so the two could not be made to agree without
        // a second pass over the device.
        //
        // One morning frame serves both pages instead, which is what ADR 0165 D7 asks for anyway —
        // one master per screen per appearance. `Good morning` is asserted rather than assumed: it
        // is now the only thing keeping the greeting and the status bar in agreement.
        capture(app, slug: "reference/home",
                assertingOnScreen: "Red Moon",
                alsoRequiring: ["JUMP BACK IN", "Good morning"],
                alsoServing: ["getting-started/home"])
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

    /// Home → Journal → the seeded take's own screen (ADR 0174).
    ///
    /// The row's title line is its **own** button, separate from the play glyph, so tapping the take
    /// opens it rather than starting it.
    ///
    /// Matched by **identifier**, not by label prefix. The label is the whole line concatenated —
    /// name, duration, note marker, time — so the only stable part of it is the word *Take*, and
    /// that is also the prefix of the Journal's **Takes** filter a few points above. A prefix match
    /// found the filter first, tapped it, and reported the take as opened.
    @MainActor
    private func openTakeDetail(in app: XCUIApplication) {
        openJournal(in: app)

        let row = app.buttons[UITestHooks.takeRowOpen]
        XCTAssertTrue(row.waitForExistence(timeout: Self.shootTimeout),
                      "no seeded take in the Journal timeline. \(stepLog)")
        tap(row, labelled: "the take row", revealing: app.buttons["Take actions"],
            called: "the take's actions menu")
        note("opened the take")
    }
}
