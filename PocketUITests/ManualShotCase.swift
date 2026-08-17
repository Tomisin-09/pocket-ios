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

    /// The hour every figure is shot at unless it asks for another — **09**, because the status bar
    /// is overridden to 09:41 and the two clocks in one frame have to agree.
    ///
    /// Before this, Home's greeting came from the wall clock and the shoot defended the mismatch by
    /// refusing to run outside 05:00–11:59. That made the images depend on when someone happened to
    /// start the run, and it could not express a figure needing a different hour at all.
    static let defaultShotHour = 9

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

    /// Record a step. Lives here beside `steps`, which is `private` — Swift has no
    /// cross-file-private, so the log's writer cannot move to the `+Reach` half.
    @MainActor
    func note(_ step: String) { steps.append(step) }

    /// Every step so far, numbered — the one artefact that explains a failed shoot.
    var stepLog: String {
        steps.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    /// Launch with the shoot's seeds. Every capture test starts here.
    ///
    /// - Parameter hour: the hour Home's greeting is computed from. Defaults to `defaultShotHour`,
    ///   which matches the faked status bar; pass another only for a figure whose `state:` asks for
    ///   a different part of the day, as `getting-started/home` does.
    @MainActor
    @discardableResult
    func launchForShoot(hour: Int = ManualShotCase.defaultShotHour) -> XCUIApplication {
        launchApp(extraArguments: Self.shootArguments
                  + [UITestHooks.shotHourArgument, String(hour)])
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
    /// - Parameter alsoServing: the other markers this one frame satisfies — crops of it, or the same
    ///   screen shown on a second page. Still **one** attachment; this only records the sharing.
    ///
    ///   It used to be recorded in the test's doc comment, which is true and unreadable by anything.
    ///   `check-manual.py`'s C13 compares markers against `capture()` calls to say how much of the
    ///   shoot is built, and a frame serving three markers counted as one — so eight slugs that are
    ///   photographed reported as unshot, and the number Phase 5 is tracked by was wrong in the
    ///   direction that hides finished work.
    @MainActor
    func capture(_ app: XCUIApplication,
                 slug: String,
                 assertingOnScreen title: String,
                 alsoRequiring required: [String] = [],
                 orBeginningWith prefixes: [String] = [],
                 alsoServing shared: [String] = [],
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
        let serves = shared.isEmpty ? "" : "also serves: \(shared.joined(separator: ", "))\n"
        let context = XCTAttachment(string: "slug: \(slug)\n\(serves)screen: \(title)\nsteps:\n\(stepLog)")
        context.name = "\(shot.name ?? slug).context"
        context.lifetime = .keepAlways
        add(context)
    }

}
