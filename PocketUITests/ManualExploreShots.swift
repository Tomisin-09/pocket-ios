import XCTest

/// **Throwaway.** Walks the screens the manual still needs and attaches the accessibility tree at
/// each stop, so the real shot classes are written against what the app actually exposes rather than
/// against guesses (ADR 0165, Phase 5).
///
/// Not part of the shoot. Selected with `POCKET_SHOOT_ONLY=ManualExploreShots`, and it produces no
/// figures — every attachment is a `tree-*.txt`, which `file-shots.py` ignores because it is not a
/// slug the manual places. Delete it once the areas below are shot.
///
/// ## Round three, and why the first two rounds were not enough
///
/// **Round one** tapped and waited on nothing, so a swallowed tap produced a dump of the screen
/// before it, under the destination's name.
///
/// **Round two** added a gate and got the gate wrong in the way this harness has a written warning
/// about: `app.navigationBars.firstMatch` is satisfied by the navigation bar you are *leaving*. Four
/// walks reported "the sheet appeared" and dumped the screen underneath it. That is trap 1 —
/// a gate the starting screen already satisfies — reintroduced in the tool built to avoid it.
///
/// So round three **stops gating on identity and measures change instead.** Each tap snapshots the
/// tree, taps, and waits for the tree to differ; the step log says in so many words whether the
/// screen moved. A gate can be wrong about *which* screen arrived. It cannot be wrong about whether
/// anything happened at all, and "nothing happened" is the finding every failed walk so far was
/// really reporting.
///
/// It also waits much longer than a gate would. Opening a song decodes audio on an erased device,
/// and round two's ten-second probe abandoned the player mid-load three times, each time reporting
/// the row as "not hittable" — which was true, because the player it had successfully opened was
/// covering it.
final class ManualExploreShots: ManualShotCase {

    /// How long to wait for a screen to change before calling it unchanged. Deliberately long: this
    /// is the number round two got wrong.
    private static let settleTimeout: TimeInterval = 30

    // MARK: - Song player

    @MainActor
    func testExploreSongPlayer() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = revealRow(labelStartingWith: "Slow Bend", in: app)
        tapAndDump(row, "player-idle", in: app)

        tapAndDump(app.buttons["Loop controls"], "player-loop-controls", in: app)

        attachSteps()
    }

    @MainActor
    func testExploreLoopsPanel() {
        let app = launchForShoot()
        openLibrary(in: app)
        tapAndDump(revealRow(labelStartingWith: "Slow Bend", in: app), "player-before-panel", in: app)

        tapAndDump(app.buttons["Loops and markers"], "player-loops-panel", in: app)

        // Hold whatever the seeded loop is called. If the name is wrong the panel dump above says so.
        holdAndDump(app.buttons.matching(prefix: "Verse riff").firstMatch, "loop-row-hold", in: app)

        attachSteps()
    }

    /// The BPM readout, held — the carry-tempo gateway (ADR 0170) — and the speed bar around it.
    @MainActor
    func testExploreCarryTempo() {
        let app = launchForShoot()
        openLibrary(in: app)
        tapAndDump(revealRow(labelStartingWith: "Slow Bend", in: app), "player-for-tempo", in: app)

        let readout = app.buttons.matching(suffix: "beats per minute").firstMatch
        holdAndDump(readout, "player-carry-tempo", in: app)

        attachSteps()
    }

    // MARK: - Song sheets

    @MainActor
    func testExploreSongSheets() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = revealRow(labelStartingWith: "Slow Bend", in: app)
        holdAndDump(row, "song-row-hold", in: app)
        tapAndDump(app.buttons["Details"], "song-details", in: app)
        swipeAndDump(app, "song-details-scrolled")

        attachSteps()
    }

    @MainActor
    func testExploreSongEdit() {
        let app = launchForShoot()
        openLibrary(in: app)

        let row = revealRow(labelStartingWith: "Slow Bend", in: app)
        holdAndDump(row, "song-edit-hold", in: app)
        tapAndDump(app.buttons["Edit"], "song-edit-top", in: app)
        swipeAndDump(app, "song-edit-1")
        swipeAndDump(app, "song-edit-2")

        attachSteps()
    }

    /// Two collections ticked. Round two ticked one and then looked for a control whose label had
    /// changed underneath it — the filter button is named for its own state.
    @MainActor
    func testExploreFilterMenu() {
        let app = launchForShoot()
        openLibrary(in: app)

        tapAndDump(app.buttons["Filter by collection"], "library-filter-menu", in: app)
        tapAndDump(app.buttons["chill"], "library-filter-one", in: app)
        tapAndDump(app.buttons["Filtering by 1 collection"], "library-filter-menu-again", in: app)
        tapAndDump(app.buttons["blues"], "library-filter-two", in: app)
        tapAndDump(app.buttons["Filtering by any of 2 collections"], "library-filter-two-ticked",
                   in: app)

        attachSteps()
    }

    // MARK: - Exercises

    /// One tap on the Practice Settings header, and a dump either side of it.
    ///
    /// Round two tapped three times and dumped a tree identical to the one before — which, for a
    /// plain `@State` disclosure toggled by a `Button`, should have been impossible. Three taps is an
    /// odd number, so the panel should have finished expanded. One tap and two dumps says whether the
    /// header responds at all, without the parity question in the way.
    @MainActor
    func testExplorePracticeSettings() {
        let app = launchForShoot()
        openAlternatePicking(in: app)
        dump(app, "exercise-run-setup-before")

        tapAndDump(app.buttons.matching(prefix: "Practice settings").firstMatch,
                   "exercise-practice-settings", in: app)

        // If the button did nothing, try the text inside it — a `.buttonStyle(.plain)` label can be
        // the element that actually takes the touch.
        tapAndDump(app.staticTexts["Practice Settings"], "exercise-practice-settings-via-text",
                   in: app)

        attachSteps()
    }

    @MainActor
    func testExploreExerciseCreation() {
        let app = launchForShoot()
        openExercises(in: app)

        tapAndDump(app.buttons["New exercise"], "exercise-template-picker", in: app)
        // Whatever the picker's rows are called, this dump will name them. `Warm-up` is the guess the
        // shoot list makes; the tree above is what settles it.
        tapAndDump(app.buttons.matching(prefix: "Warm-up").firstMatch, "exercise-configure", in: app)

        attachSteps()
    }

    // MARK: - Routines and goals

    @MainActor
    func testExploreRoutineEditor() {
        let app = launchForShoot()
        openPractice(in: app)
        tapAndDump(app.buttons.matching(prefix: "Routines,").firstMatch, "routines-library", in: app)
        tapAndDump(app.buttons["New routine"], "routine-editor", in: app)
        tapAndDump(app.buttons["Add exercise, loop or song"], "routine-add-unit", in: app)

        attachSteps()
    }

    @MainActor
    func testExploreGoalAuthoring() {
        let app = launchForShoot()
        openPractice(in: app)
        tapAndDump(app.buttons["Today's session"], "planner", in: app)
        tapAndDump(app.buttons["Add a goal for this session"], "goal-templates", in: app)

        attachSteps()
    }

    // MARK: - Tap, and say whether anything happened

    /// Snapshot the tree, tap, wait for it to differ, dump — and record which of those two it was.
    ///
    /// The whole of round three is this function. It cannot tell you *which* screen you reached, but
    /// it is never wrong about whether you reached one, and every failure in rounds one and two was
    /// a tap that did nothing being reported as a tap that worked.
    @MainActor
    private func tapAndDump(_ element: XCUIElement, _ name: String, in app: XCUIApplication) {
        act(element, name, in: app) { $0.tap() }
    }

    /// The same, for a long press.
    @MainActor
    private func holdAndDump(_ element: XCUIElement, _ name: String, in app: XCUIApplication) {
        act(element, name, in: app) { $0.press(forDuration: 1.0) }
    }

    @MainActor
    private func act(_ element: XCUIElement,
                     _ name: String,
                     in app: XCUIApplication,
                     _ gesture: (XCUIElement) -> Void) {
        guard element.waitForExistence(timeout: Self.tapProbeTimeout) else {
            note("MISS '\(name)' — the control is not in the tree; dumping where we are instead")
            dump(app, "\(name)-CONTROL-MISSING")
            return
        }
        _ = scrollIntoView(element, in: app)
        note("acting on '\(element.label)' for \(name)")

        let before = app.debugDescription
        gesture(element)

        let deadline = Date().addingTimeInterval(Self.settleTimeout)
        var changed = false
        while Date() < deadline {
            if app.debugDescription != before { changed = true; break }
        }
        note(changed ? "the screen changed for \(name)"
                     : "SCREEN DID NOT CHANGE for \(name) after \(Int(Self.settleTimeout))s")
        dump(app, changed ? name : "\(name)-UNCHANGED")
    }

    @MainActor
    private func swipeAndDump(_ app: XCUIApplication, _ name: String) {
        app.swipeUp(velocity: .slow)
        note("swiped up for \(name)")
        dump(app, name)
    }

    // MARK: - Routes
    //
    // These use `tap(_:revealing:)` with gates that are known good from the filed figures, so a route
    // failing is a real failure rather than another unknown.

    @MainActor
    private func openPractice(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Practice"])
    }

    @MainActor
    private func openExercises(in app: XCUIApplication) {
        openPractice(in: app)
        tapRow(labelStartingWith: "Exercises,", in: app,
               arrivingAt: app.navigationBars["Exercises"], called: "the exercise library")
    }

    @MainActor
    private func openAlternatePicking(in app: XCUIApplication) {
        openExercises(in: app)
        tapRow(labelStartingWith: "Alternate Picking", in: app,
               arrivingAt: app.buttons["Exercise details"], called: "the run screen")
    }

    @MainActor
    private func openLibrary(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])
    }

    // MARK: - Attachments

    @MainActor
    private func dump(_ app: XCUIApplication, _ name: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "tree-\(name)"
        tree.lifetime = .keepAlways
        add(tree)
        note("dumped the tree at '\(name)'")
    }

    @MainActor
    private func attachSteps() {
        let log = XCTAttachment(string: stepLog)
        log.name = "steps-\(name)"
        log.lifetime = .keepAlways
        add(log)
    }
}

private extension XCUIElementQuery {
    func matching(prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }

    func matching(suffix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label ENDSWITH %@", suffix))
    }
}
