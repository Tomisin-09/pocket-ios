import XCTest

/// The shared machinery behind every user-manual capture (ADR 0165, Phase 5).
///
/// The shoot is split across several classes — one per area of the manual — so a broken tap in
/// Settings does not take the Toolkit's figures down with it, and so no single file carries ninety-six
/// captures. What they share lives here: the launch arguments, the step log, and `capture` itself.
///
/// **The failure this is written against:** a missed tap yields a perfectly good screenshot of the
/// previous screen, and the run still reports success. Every capture therefore asserts what is on
/// screen *before* it shoots, and records that assertion beside the image. An exit code and a file
/// count are not evidence here; the recorded context is.
///
/// Run against an **erased** simulator via `scripts/shoot-manual.sh`. Both seeds refuse to run twice —
/// `ScreenshotSeed` skips a library that already has songs, `PracticeHistorySeed` skips a store that
/// already has runs — so a second run on a dirty device produces images of whatever the first left
/// behind. That script also lists which classes the shoot runs; a new one has to be added there.
class ManualShotCase: UITestCase {

    /// Launch arguments the shoot adds: a library to photograph, and a past for it to have had.
    static let shootArguments = ["-seedScreenshots", "-seedHistory"]

    /// How long a shoot waits for anything — deliberately longer than `UITestCase.uiTimeout`.
    ///
    /// The suite's 10 seconds is calibrated for a regression test, where a long wait hides how slow
    /// things really are and turns a genuine hang into a slow pass. A shoot is a different job: it
    /// runs against a device erased seconds earlier, whose first boot is heavy enough on its own to
    /// take this machine's load average past 130, and its output is a photograph. A capture taken
    /// late is still correct; a capture abandoned early is a missing figure and another six minutes.
    ///
    /// Not a substitute for waiting on the boot (`shoot-manual.sh` blocks on `simctl bootstatus`) or
    /// for gating each push on arrival. Those remove the race; this is the headroom underneath them.
    static let shootTimeout: TimeInterval = 30

    /// How long a *retried* tap waits before concluding the tap was swallowed.
    ///
    /// Short on purpose, and only used on attempts before the last — the failure it is looking for
    /// (an event synthesised, accepted, and dropped) shows up as *nothing at all happening*, not as
    /// slowness, so waiting the full `shootTimeout` three times over only makes a failing shoot take
    /// three times as long to say so. The final attempt still gets the full timeout, so a genuinely
    /// slow push is never called a swallowed one.
    static let tapProbeTimeout: TimeInterval = 10

    /// Every tap and every miss, in order, attached to the run.
    ///
    /// The one artefact that explains a failed shoot. A bare `NSLog` is lost the moment `xcodebuild`
    /// is piped through `tail`, which is how the output is read on every machine this runs on.
    private var steps: [String] = []

    /// Launch with the shoot's seeds. Every capture test starts here.
    @MainActor
    @discardableResult
    func launchForShoot() -> XCUIApplication {
        launchApp(extraArguments: Self.shootArguments)
    }

    // MARK: - Capture

    /// Assert where we are, then shoot, then record both.
    ///
    /// `assertingOnScreen` is the intended screen's **navigation-bar title**, resolved against the
    /// navigation bar itself rather than against any text with that name on it. It is the whole
    /// safeguard: without it a screenshot proves only that the app was running.
    ///
    /// One frame often serves several markers — `journal/progress`, `reference/progress` and
    /// `journal/month-heatmap` are three crops of one Progress screen. Only **one** attachment is made
    /// in that case, named for the first slug, and the others are recorded in the test's doc comment.
    /// Attaching the same pixels twice would defeat the audit rule that two identical images mean a
    /// missed tap — which is not theoretical: it is what caught `reference/settings-you` being shot
    /// on the Settings hub.
    ///
    /// Share a frame only when every marker's subject is actually inside it, and assert both ends of
    /// the picture rather than assuming a `role: panel` crop falls within the screen shot.
    ///
    /// - Parameter alsoRequiring: strings that must be **inside the frame**, matched exactly, for the
    ///   *state* to be right rather than just the screen. Being on the correct screen in the wrong
    ///   state photographs just as cleanly, and the marker's `state:` field is what these come from.
    ///   Inside the frame, not merely in the tree — see `isInFrame`, and the figure that taught it.
    /// - Parameter orBeginningWith: the same check for labels too long or too variable to spell out —
    ///   a wrapped FAQ answer, a readout that carries a tempo marking after the number.
    @MainActor
    func capture(_ app: XCUIApplication,
                 slug: String,
                 assertingOnScreen title: String,
                 alsoRequiring required: [String] = [],
                 orBeginningWith prefixes: [String] = [],
                 file: StaticString = #filePath, line: UInt = #line) {
        // Text **inside a navigation bar** — not any static text with this name on it, and not the
        // bar's own identifier either.
        //
        // `app.staticTexts["You"]` was the original check, and it matched the Settings hub's own `You`
        // row: a swallowed tap left the shoot on the hub, the assertion agreed it was on "You", and
        // `reference/settings-you` came back byte-identical to `reference/settings-hub`. Nothing in
        // the run objected — the duplicate image was the only evidence.
        //
        // `app.navigationBars[title]` was the fix, and it was too narrow: `MetronomeView` sets no
        // `navigationTitle` at all, putting a custom `Text("Metronome")` in a `.principal` toolbar
        // item, so its bar carries no such identifier and two passing figures started failing. Asking
        // for the title *within the bar's subtree* covers both spellings, and still cannot be
        // satisfied by a row in the content — which is the whole point.
        let inBar = app.navigationBars.staticTexts[title]
        var arrived = inBar.waitForExistence(timeout: Self.shootTimeout)
        if !arrived { arrived = app.navigationBars[title].exists }
        note(arrived ? "arrived at '\(title)' for \(slug)" : "MISSED '\(title)' for \(slug)")

        XCTAssertTrue(arrived, """
            expected to be on '\(title)' before shooting \(slug), and was not — so this capture \
            would have been a clean photograph of the wrong screen.
            \(stepLog)
            """, file: file, line: line)

        for needed in required {
            // Label *or* identifier, which is what the `[needed]` subscript matched before this
            // became a query — narrowing it to one or the other here would quietly drop assertions.
            let target = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR identifier == %@", needed, needed))
            let present = target.firstMatch.waitForExistence(timeout: Self.shootTimeout)
                && isInFrame(target, of: app)
            note(present ? "state '\(needed)' in frame" : "state '\(needed)' NOT IN FRAME")
            XCTAssertTrue(present, """
                on '\(title)' but '\(needed)' was not in the frame, so \(slug) would have been shot \
                in the wrong state.
                \(stepLog)
                """, file: file, line: line)
        }

        for prefix in prefixes {
            let target = elements(in: app, labelStartingWith: prefix)
            let present = target.firstMatch.waitForExistence(timeout: Self.shootTimeout)
                && isInFrame(target, of: app)
            note(present ? "state '\(prefix)…' in frame" : "state '\(prefix)…' NOT IN FRAME")
            XCTAssertTrue(present, """
                on '\(title)' but nothing in the frame had a label beginning '\(prefix)', so \(slug) \
                would have been shot in the wrong state.
                \(stepLog)
                """, file: file, line: line)
        }

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = slug.replacingOccurrences(of: "/", with: "-")
        shot.lifetime = .keepAlways
        add(shot)

        // The context, stored beside the image. An image whose recorded screen is missing or
        // surprising is the one to open first when auditing the set.
        let context = XCTAttachment(string: "slug: \(slug)\nscreen: \(title)\nsteps:\n\(stepLog)")
        context.name = "\(shot.name ?? slug).context"
        context.lifetime = .keepAlways
        add(context)
    }

    /// Is this element in the **photograph** — not merely in the accessibility tree?
    ///
    /// `exists` was the original check here, and it is not the same question. A scrolled-away section
    /// stays in the tree at its true offset, so an element metres above the top of the screen reports
    /// `exists == true` for as long as its scroll view holds it. `journal/progress` was shot that way
    /// and passed: the run asserted `THIS WEEK`, the tree agreed, and the image that came back showed
    /// This month and All-time with This week nowhere in it. A green run, a clean picture, the wrong
    /// figure — which is the one failure this whole file is written against, arriving through the
    /// assertion meant to prevent it.
    ///
    /// Full containment, not intersection: a section sliced by the edge of the frame is not a section
    /// the reader can see, and half a bar chart in a manual is worse than a missing one.
    ///
    /// Occlusion is a separate problem this cannot see — the navigation bar is translucent and draws
    /// over content that is legitimately inside the window. That is a matter of how a figure is
    /// composed rather than what is asserted about it, and is handled by not scrolling a header under
    /// the bar in the first place.
    /// Takes a **query**, not an element, and asks whether *any* match is in the picture.
    ///
    /// Both halves of that matter. `element.frame` throws outright when its query matches more than
    /// one thing — `Start`, `Done` and `Less` each match a button and the label inside it — and
    /// `exists` does not, so the first version of this sailed through the existence gate and then
    /// failed five tests with `Multiple matching elements found`. Taking `.firstMatch` would have
    /// silenced that while introducing something worse: a screen showing two `More`s would be judged
    /// on whichever the query reached first, which may be the one scrolled off the top.
    @MainActor
    private func isInFrame(_ query: XCUIElementQuery, of app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        return query.allElementsBoundByAccessibilityElement.contains { candidate in
            let frame = candidate.frame
            return !frame.isEmpty && window.contains(frame)
        }
    }

    // MARK: - Queries

    /// The first element of any type whose label begins with `prefix`.
    ///
    /// Rows built as `NavigationLink`s wrapping a `LabeledContent` surface as a button, a cell or an
    /// other-element depending on what is inside them, and the trait is not worth predicting — the
    /// existing `SettingsHubUITests` and `ToolkitUITests` both learned that. Prefix rather than exact
    /// because a row's label carries its current value after the title.
    ///
    /// ⚠️ Never aim a prefix at content the **back button** could also match: inside a pushed screen
    /// that control carries the *previous* screen's title, so a loose match pops the stack and every
    /// later capture is quietly of the wrong screen — green the whole way.
    @MainActor
    func element(in app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElement {
        elements(in: app, labelStartingWith: prefix).firstMatch
    }

    /// The same query, unresolved — for callers that need to weigh every match rather than the first.
    @MainActor
    func elements(in app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }

    /// Tap one of Home's nav cards, which live in titled sections below the fold (ADR 0102).
    ///
    /// **Not `scrollIntoView`.** That helper swipes at the default velocity, which on Home's short
    /// scroll view moves more than a card's height per swipe, and it decides where it is by comparing
    /// frames between swipes. Two things follow, and this shoot hit both in one run: a single swipe
    /// can carry the card clean past the viewport, so the next `exists` check fails and the helper
    /// gives up on a card that is right there; and a card can pass `isHittable` and then be somewhere
    /// else by the time the tap is synthesised, because the scroll is still decelerating — which
    /// produces a tap on whatever slid into that spot, a green navigation step, and a figure of the
    /// wrong screen.
    ///
    /// So: slow swipes, and the hittable check re-read immediately before the tap on each pass rather
    /// than once at the end. Both failures were intermittent, which is the reason to fix the movement
    /// rather than retry the run — at ninety-six figures a shoot that misses two at random is a shoot
    /// whose output has to be audited twice.
    /// - Parameter arrivingAt: an element that exists on the destination and **not on Home**. The tap
    ///   is retried until this appears, because a tap on the coldest first launch can be accepted and
    ///   then swallowed, leaving the app on Home with the run none the wiser.
    ///
    ///   Choosing it needs care. The first version of this gate waited for `staticTexts["Metronome"]`
    ///   after tapping the Metronome card — and Home's card is *titled* "Metronome", so the assertion
    ///   was true before the tap and could never fail. It duly passed while the app sat on Home, and
    ///   the run failed three steps later with "no + stepper on the metronome": a true sentence about
    ///   a screen we were never on. Pick something the destination owns — a toolbar control, a
    ///   navigation bar — never a word Home also says.
    @MainActor
    func tapHomeCard(_ label: String,
                     in app: XCUIApplication,
                     arrivingAt arrival: XCUIElement,
                     maxSwipes: Int = 8,
                     attempts: Int = 3,
                     file: StaticString = #filePath, line: UInt = #line) {
        let card = app.buttons[label]
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no '\(label)' card on Home.\n\(stepLog)", file: file, line: line)

        tap(card, labelled: label, revealing: arrival, called: "the destination",
            attempts: attempts, file: file, line: line) {
            guard self.scrollToCard(card, in: app, maxSwipes: maxSwipes) else {
                XCTFail("""
                    '\(label)' never became tappable on Home within \(maxSwipes) slow swipes — it \
                    exists in the tree, so this is a scrolling problem, not a missing card.
                    \(self.stepLog)
                    """, file: file, line: line)
                return false
            }
            return true
        }
    }

    /// Tap a control and wait for what it opens, re-tapping only while the control is still there.
    ///
    /// The shoot's second recurring failure, after the swallowed Home-card tap, and the same shape:
    /// the ⋯ menu on the Journal was found, tapped, the event was synthesised — and the menu did not
    /// open. Thirty seconds of `Checking existence of "Progress" Button` later the run failed, from a
    /// screen where one more tap would have worked.
    ///
    /// **Why a retry here is not the retry ADR 0146 argues against.** That one re-runs a failing test
    /// and takes the second answer, which converts a real defect into a slower green. This one is
    /// gated on evidence that the first tap did nothing: `control.isHittable` is false the moment a
    /// menu's scrim or a pushed screen covers it, so a re-tap only ever happens from a screen that
    /// visibly did not change. If something *did* open and it was the wrong thing, this fails rather
    /// than tapping blind — because a shoot that carries on from an unknown screen is exactly how a
    /// clean photograph of the wrong subject gets made. Every attempt is written to the step log, so
    /// a figure that needed three taps is visible afterwards rather than smoothed away.
    ///
    /// - Parameter revealing: an element the destination owns and the current screen does **not**.
    ///   A gate the starting screen can already satisfy is not a gate — see `tapHomeCard`.
    /// - Parameter prepare: run before each tap; return `false` to abandon (it has already failed).
    @MainActor
    func tap(_ control: XCUIElement,
             labelled label: String,
             revealing revealed: XCUIElement,
             called revealedName: String,
             attempts: Int = 3,
             file: StaticString = #filePath, line: UInt = #line,
             beforeEachTap prepare: () -> Bool = { true }) {
        for attempt in 1...attempts {
            guard prepare() else { return }

            control.tap()
            note("tapped '\(label)'" + (attempt > 1 ? " (attempt \(attempt))" : ""))

            // Only the last attempt is given the full timeout: a swallowed tap shows as nothing
            // happening, not as slowness, so probing briefly first costs a failing shoot nothing.
            let patience = attempt == attempts ? Self.shootTimeout : Self.tapProbeTimeout
            if revealed.waitForExistence(timeout: patience) {
                note("\(revealedName) appeared after '\(label)'")
                return
            }

            guard control.exists && control.isHittable else {
                XCTFail("""
                    tapped '\(label)' and it is no longer reachable, but \(revealedName) never \
                    appeared — so something opened and it is not what this shot needs, and any \
                    capture from here would be of the wrong thing.
                    \(stepLog)
                    """, file: file, line: line)
                return
            }
            note("tap \(attempt) changed nothing — '\(label)' is still there, retrying")
        }

        XCTFail("""
            tapped '\(label)' \(attempts)× and \(revealedName) never appeared.
            \(stepLog)
            """, file: file, line: line)
    }

    /// Bring a Home card into reach with slow swipes. Returns whether it ended up hittable.
    @MainActor
    private func scrollToCard(_ card: XCUIElement,
                              in app: XCUIApplication,
                              maxSwipes: Int) -> Bool {
        for _ in 0...maxSwipes {
            if card.exists && card.isHittable { return true }
            app.swipeUp(velocity: .slow)
        }
        return card.exists && card.isHittable
    }

    /// Wait for a row, scroll it into reach, tap it, and log all three — the shape every navigation
    /// step in the shoot takes.
    ///
    /// Returns nothing and fails loudly rather than returning a flag: a shoot that carries on past a
    /// missed tap is precisely how a set of clean images of the wrong screens gets made.
    /// - Parameter arrivingAt: an element the destination owns. Omitting it means the tap is not
    ///   checked at all, which is how `reference/settings-you` came back as a picture of the Settings
    ///   hub: the row was found, the tap was swallowed, and nothing downstream disagreed. Pass it
    ///   wherever the row opens a screen.
    @MainActor
    func tapRow(labelStartingWith prefix: String,
                in app: XCUIApplication,
                arrivingAt arrival: XCUIElement? = nil,
                called arrivalName: String = "the destination",
                file: StaticString = #filePath, line: UInt = #line) {
        let row = element(in: app, labelStartingWith: prefix)
        let found = row.waitForExistence(timeout: Self.shootTimeout)
        note(found ? "found row '\(prefix)'" : "MISSED row '\(prefix)'")
        XCTAssertTrue(found, "no row whose label begins '\(prefix)'.\n\(stepLog)",
                      file: file, line: line)

        XCTAssertTrue(scrollIntoView(row, in: app),
                      "row '\(prefix)' never became tappable.\n\(stepLog)", file: file, line: line)

        guard let arrival else {
            row.tap()
            note("tapped '\(prefix)' (no arrival check)")
            return
        }
        tap(row, labelled: prefix, revealing: arrival, called: arrivalName, file: file, line: line)
    }

    // MARK: - Step log

    @MainActor
    func note(_ step: String) { steps.append(step) }

    var stepLog: String {
        steps.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}
