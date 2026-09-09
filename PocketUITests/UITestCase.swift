import XCTest

/// The shared launch seam for every UI test (ADR 0146 pass 2).
///
/// Before this, each test opened with the same three lines — `continueAfterFailure = false`, append
/// `-uiTesting`, `launch()` — and then guessed at first-launch seeding with a 20-second
/// `waitForExistence` on whatever content it happened to want first. Those guesses were the flake:
/// seeding has no completion signal, so the number was chosen to be "probably enough" and a loaded
/// runner made it not enough. `PracticeRunUITests` failed on `main` that way, on a PR that touched
/// nothing in the failing path.
///
/// `launchApp()` replaces the guessing with **one** wait, on a signal the app actually raises. Two
/// things follow from that:
///
/// - Every assertion after it is against a settled app, so the generous timeouts drop to
///   `Self.uiTimeout`. A wait that is long "just in case" hides how long things really take, and
///   turns a genuine hang into a slow pass.
/// - The failure sentence becomes *"first-launch seeding never completed"* rather than *"no seeded
///   exercise to tap"* — the first names the cause, the second names a symptom three screens away.
///
/// Deliberately **no `setUp` override.** `XCTestCase.setUp` is nonisolated and an override cannot add
/// isolation its superclass method lacks, so main-actor work there compiles locally and fails CI's
/// stricter Swift 6 (that burn is recorded in ADR 0146 and cost a red CI run once already). Launching
/// from the `@MainActor` test body sidesteps it entirely.
class UITestCase: XCTestCase {

    /// The wait for anything that is merely a screen transition or a query settling. Generous enough
    /// for a loaded runner, short enough that a real hang fails in reasonable time rather than
    /// stalling the suite.
    static let uiTimeout: TimeInterval = 10

    /// The one long wait in the suite: cold-install seeding writes six exercises, a routine and a
    /// demo song that decodes off-main. This is the only place a number this big is justified,
    /// because it is the only wait covering genuinely variable work.
    static let seedingTimeout: TimeInterval = 60

    /// Launch the app and return only once first-launch seeding has actually finished.
    ///
    /// Every test starts here. A test that queried the app before seeding completed is what pass 1
    /// papered over with retries; routing all four files through one function means a new test
    /// cannot forget the wait, which is the part that makes this hold over time.
    /// - Parameter extraArguments: launch arguments appended after `-uiTesting`. The manual shoot
    ///   passes `-seedScreenshots` and `-seedHistory` this way (ADR 0165 Phase 5); ordinary tests
    ///   pass nothing and get the same launch they always had.
    @MainActor
    @discardableResult
    func launchApp(extraArguments: [String] = [],
                   file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [UITestHooks.launchArgument] + extraArguments
        app.launch()

        let seeded = app.otherElements[UITestHooks.homeSeedingComplete]
        XCTAssertTrue(
            seeded.waitForExistence(timeout: Self.seedingTimeout),
            """
            first-launch seeding never completed within \(Int(Self.seedingTimeout))s.
            Home renders before its seeding `.task` finishes; the app raises \
            '\(UITestHooks.homeSeedingComplete)' when it does. If Home is on screen but this never \
            appeared, suspect the seeding task (or the marker in HomeView) — not the assertion that \
            failed after it.
            """,
            file: file, line: line)
        return app
    }

    /// Scroll `element` into a tappable position, stopping as soon as it is hittable **or** the view
    /// has stopped moving.
    ///
    /// Replaces `while !element.isHittable && swipes < 6 { app.swipeUp() }`, which was wrong in both
    /// directions: a fixed swipe budget overshoots a short list (scrolling past the target, or
    /// bouncing at the end while the counter burns down) and under-reaches a long one. Watching the
    /// element's own frame instead makes the stop condition a fact about the app rather than a guess
    /// about how many swipes a layout needs.
    ///
    /// Returns whether it ended up hittable, so callers can assert with their own message.
    @MainActor
    @discardableResult
    func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) -> Bool {
        guard element.exists else { return false }
        if element.isHittable { return true }

        var lastFrame = element.frame
        for _ in 0..<maxSwipes {
            app.swipeUp()
            guard element.exists else { return false }
            if element.isHittable { return true }
            // The frame not moving means the scroll view is already at its limit; more swipes would
            // only rubber-band. Bail rather than spend the rest of the budget on a foregone result.
            if element.frame == lastFrame { return false }
            lastFrame = element.frame
        }
        return element.exists && element.isHittable
    }

    /// Wait for `element` to go away — the mirror of `waitForExistence`, which XCTest doesn't ship.
    @MainActor
    func waitForDisappearance(of element: XCUIElement,
                              timeout: TimeInterval = UITestCase.uiTimeout) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
