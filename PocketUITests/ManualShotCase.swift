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

    /// Wait until `element` will actually take a touch.
    ///
    /// `waitForExistence` returns when an element **enters the tree**, not when it settles, and a
    /// gesture synthesised in between fails outright: *Failed to synthesize event: Not hittable*.
    /// That is not the swallowed tap this file's retries are about — nothing is dropped, the gesture
    /// never happens — and it is not a wrong screen either. It is a race, and it shows up on whichever
    /// step happens to be fastest to reach.
    ///
    /// Measured, on the loop rows in the song player: `Play Verse riff` sits at a fixed frame well
    /// inside the window, `ManualPlayerShots` taps it successfully, and four `ManualLoopSheetShots`
    /// tests failed to press it — the only difference being that they arrive at the panel and press
    /// immediately rather than after another query has already made the runner wait.
    @MainActor
    @discardableResult
    func awaitHittable(_ element: XCUIElement,
                       timeout: TimeInterval = ManualShotCase.tapProbeTimeout) -> Bool {
        if element.exists && element.isHittable { return true }
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"),
                                   evaluatedWith: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    /// Why a tap could not be synthesised — **which** of the two reasons, because `awaitHittable`
    /// answers `false` for both.
    ///
    /// It returns false for a control that is present and covered, and for one that was never in the
    /// tree at all. `tap` used to call every one of them *"a race, not a swallowed tap"*, which is a
    /// message that sends whoever reads it hunting for a timing problem when the actual fault is a
    /// query resolving to nothing. It cost precisely that: a routine block reported as "in the tree
    /// but never became hittable" was not in the tree, so the first fix swapped one absent query for
    /// another and failed with the identical sentence. **A failure message naming the wrong cause is
    /// worse than a bare assertion** — the bare one at least does not send you somewhere.
    ///
    /// The screen dump comes along because the answer to "then what *is* there?" is the next thing
    /// wanted every single time, and it is not recoverable after the fact from a step log.
    @MainActor
    func unreachable(_ control: XCUIElement, labelled label: String) -> String {
        let cause = control.exists
            ? "is in the tree but never became hittable, so the tap could not be synthesised. "
                + "Something is drawn over it, or it is scrolled out of reach — an occlusion, not a "
                + "swallowed tap."
            : "never entered the tree at all, so the query resolved to nothing. This is the wrong "
                + "screen, the wrong name for the control, or a row that has to be scrolled into "
                + "existence before it can be asked for."
        return """
            '\(label)' \(cause)
            \(diagnosis(for: label, in: XCUIApplication()))
            \(stepLog)
            """
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
                 wholeDisplay: Bool = false,
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
            \(diagnosis(for: title, in: app))
            \(stepLog)
            """, file: file, line: line)

        record(app, slug: slug, screen: title, required: required, prefixes: prefixes,
               shared: shared, wholeDisplay: wholeDisplay, file: file, line: line)
    }

    /// Shoot a screen that has **no navigation bar**, gated on labels it owns instead.
    ///
    /// `capture` resolves the intended screen inside the navigation bar's subtree, and that is the
    /// right gate precisely because content cannot satisfy it. A `fullScreenCover` has no bar at all,
    /// so for those screens the gate has to come from somewhere — and the somewhere must still be
    /// something **only the destination has**. The first-run intake is the case in hand: it draws its
    /// own header over `PocketColor.background` with no `navigationTitle` anywhere in it.
    ///
    /// Kept as a separate entry point rather than making `capture`'s title optional. An optional gate
    /// is one a caller forgets, and the failure it lets through — a clean photograph of the previous
    /// screen — is the one this whole file exists to prevent. Ninety-odd figures keep the strong gate;
    /// this is the door for the handful that genuinely cannot use it.
    ///
    /// - Parameter screen: what to call this screen in the step log and the `.context` file. Not
    ///   asserted — `ownedBy` is what is asserted.
    /// - Parameter ownedBy: labels the destination has and the screen before it does not. The intake
    ///   is reached from Home, so `A few quick things` qualifies and `Skip` would not.
    @MainActor
    func captureChromeless(_ app: XCUIApplication,
                           slug: String,
                           screen name: String,
                           ownedBy owned: [String],
                           alsoRequiring required: [String] = [],
                           orBeginningWith prefixes: [String] = [],
                           alsoServing shared: [String] = [],
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(owned.isEmpty,
                       "captureChromeless needs at least one label the screen owns, or it asserts "
                       + "only that the app was running.", file: file, line: line)

        for marker in owned {
            let target = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR identifier == %@", marker, marker))
            let arrived = target.firstMatch.waitForExistence(timeout: Self.shootTimeout)
                && isInFrame(target, of: app)
            note(arrived ? "arrived at '\(name)' via '\(marker)' for \(slug)"
                         : "MISSED '\(marker)' for \(slug)")
            XCTAssertTrue(arrived, """
                expected to be on '\(name)' before shooting \(slug), and '\(marker)' was not in the \
                frame — so this capture would have been a clean photograph of the wrong screen.
                \(diagnosis(for: marker, in: app))
                \(stepLog)
                """, file: file, line: line)
        }

        record(app, slug: slug, screen: name, required: required, prefixes: prefixes,
               shared: shared, file: file, line: line)
    }

    /// How many elements `diagnosis` will walk before giving up. Generous on purpose: this runs only
    /// on a failure, where the cost of one slow enumeration is nothing beside the cost of a reader
    /// being told a control is absent when the scan merely stopped short of it.
    static let diagnosisScanCap = 500

    /// Assert the state, shoot, and write the context beside it — the half both capture paths share.
    ///
    /// The three state lists carry defaults because a figure legitimately has none: several captures
    /// assert only the screen, and their `state:` is the screen's own default.
    /// What the screen *does* have, for a state assertion that failed on what it *wanted*.
    ///
    /// **Written because the absence of this cost two separate diagnoses in one shoot.** The
    /// assertion above says "'Artist' was not in the frame" and stops, and every explanation for
    /// that sentence — the row is below the fold, the label is the field's value rather than its
    /// placeholder, the element is clipped by a sheet detent, the screen is not the one we think —
    /// is equally consistent with it. Each one sends you to different source, and the only way to
    /// choose between them was to open the app's code and reason about SwiftUI's labelling, which is
    /// guessing with extra steps. The tree already knows; it simply was not being asked.
    ///
    /// Two lists, because the distinction is the whole diagnosis: what is **in the frame** (so the
    /// screen is right and the wanted label is wrong) versus what is **in the tree but out of the
    /// frame** (so the label is right and the scrolling is wrong). Capped, because a failure message
    /// nobody reads to the end is not a failure message.
    @MainActor
    func diagnosis(for wanted: String, in app: XCUIApplication) -> String {
        var inFrame: [String] = []
        var offscreen: [String] = []
        let window = app.windows.firstMatch.frame

        for candidate in app.descendants(matching: .any).allElementsBoundByAccessibilityElement {
            let label = candidate.label
            guard !label.isEmpty else { continue }
            let frame = candidate.frame
            if !frame.isEmpty && window.contains(frame) {
                inFrame.append(label)
            } else {
                offscreen.append(label)
            }
            if inFrame.count + offscreen.count >= Self.diagnosisScanCap { break }
        }
        let truncated = inFrame.count + offscreen.count >= Self.diagnosisScanCap

        func list(_ labels: [String], _ heading: String) -> String {
            let unique = Array(NSOrderedSet(array: labels)).compactMap { $0 as? String }
            guard !unique.isEmpty else { return "\(heading): (nothing)" }
            let shown = unique.prefix(120).map { "'\($0)'" }.joined(separator: ", ")
            let more = unique.count > 120 ? " … and \(unique.count - 120) more" : ""
            return "\(heading): \(shown)\(more)"
        }

        // **Say so when the scan stopped early, because otherwise this reads as a complete answer.**
        // The cap used to be 120 with nothing announcing it, and a sheet presented over a long list
        // is exactly the case that overruns it: the library behind the Edit song sheet spends the
        // budget before the sheet's own fields are reached, so a field that is plainly on screen is
        // absent from both buckets. Read as "not in the tree", which is what the message next to this
        // one says, that sends you hunting for a renamed control that was never renamed. A partial
        // scan presented as a full one is the same defect as a parser that reads two thirds of its
        // input and reports a number.
        let caveat = truncated
            ? "\n  ⚠️ stopped after \(Self.diagnosisScanCap) elements — this listing is PARTIAL, so a "
                + "name missing from it may simply be past the cap rather than off the screen."
            : ""
        return """
            Looking for '\(wanted)'. What the screen actually offers:
            \(list(inFrame, "  IN FRAME"))
            \(list(offscreen, "  IN THE TREE BUT NOT IN FRAME — scrolling, not naming"))\(caveat)
            """
    }

    @MainActor
    private func record(_ app: XCUIApplication,
                        slug: String,
                        screen title: String,
                        required: [String] = [],
                        prefixes: [String] = [],
                        shared: [String] = [],
                        wholeDisplay: Bool = false,
                        file: StaticString = #filePath, line: UInt = #line) {
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
                \(diagnosis(for: needed, in: app))
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
                \(diagnosis(for: prefix, in: app))
                \(stepLog)
                """, file: file, line: line)
        }

        // `app.screenshot()` photographs **this app**, and two figures in the manual are of something
        // else drawn over it: the system document picker is `com.apple.DocumentManagerUICore`, a
        // separate process, and an app-scoped screenshot of it comes back as a clean picture of the
        // library with no picker in it — the wrong-subject failure, arriving through the camera
        // rather than through a missed tap. `XCUIScreen.main.screenshot()` takes the display.
        //
        // Not the default, because the display shot also carries the simulator's own status bar
        // rather than the app's view of it, and ninety-odd figures are better off with the narrower
        // one they have always used.
        let shot = XCTAttachment(screenshot: wholeDisplay ? XCUIScreen.main.screenshot()
                                                          : app.screenshot())
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
