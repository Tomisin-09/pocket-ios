import XCTest

/// The two figures that need a device with **nothing on it** (ADR 0165, Phase 5) — the opposite of
/// every other shot in the manual, and the reason the `bare` pass exists.
///
/// Neither test calls `launchForShoot()`. That helper adds `-seedScreenshots` and `-seedHistory`,
/// which is exactly what these figures must not have; both seeds are also idempotent, so a device
/// that has been seeded once cannot be un-seeded and this pass has to be the whole of its own device.
///
/// **This used to be a list of two and is now a list of one plus an unrelated one.**
/// `reference/loops-library` was grouped here as "the second figure needing a bare device" and does
/// not belong: `LoopLibraryView` draws one empty state when the library holds unmeasured loops and a
/// different one when it holds none at all, and the marker's alt text quotes the first. A bare device
/// produces the second. It is shot on the seeded device by `ManualPracticeShots` instead.
final class ManualBareShots: ManualShotCase {

    /// `songs/empty-library` — the library with no songs in it.
    ///
    /// Seeded launch arguments are omitted; `-uiTesting` is not, and is doing real work here. Without
    /// it the first-launch intake comes up over Home, so the shoot would meet a sheet rather than the
    /// Song library card. (It also used to unlock the library from behind the Pro wall, which went
    /// with ADR 0237.) First-launch seeding still runs — six exercises and a routine — and writes **no
    /// song**, which is why an unseeded device is an empty library rather than an empty app.
    ///
    /// All three of the empty state's parts are required, because "the list is empty" is also true of
    /// a library that failed to load.
    @MainActor
    func testEmptyLibrary() {
        let app = launchApp()
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])

        capture(app, slug: "songs/empty-library",
                assertingOnScreen: "Library",
                alsoRequiring: ["No songs yet", "Import a song", "Try the demo"])
    }

    /// `getting-started/first-run` — the intake, on the very first launch.
    ///
    /// **The one launch in the whole shoot without `-uiTesting`**, and that is the entire trick. The
    /// intake is suppressed by `UITestRuntime.isActive`, not by the seed flags — `HomeView+ProfileMoment`
    /// returns early on it — so every other figure in the manual is shot on a launch that cannot show
    /// this screen. The README said the seed flags were responsible for months, which made this figure
    /// look as though it needed a bare install to be *unshootable* rather than merely unseeded.
    ///
    /// `launchApp()` cannot be used for the same reason: it adds `-uiTesting` unconditionally and then
    /// waits on Home's seeding marker, which is behind a `fullScreenCover` here. The wait is on the
    /// intake's own first question instead, which is a stronger signal anyway — it says the cover is
    /// up, not merely that the app started.
    ///
    /// Shot chromeless: the intake is a `ZStack` over `PocketColor.background` with no
    /// `navigationTitle` anywhere in it, so there is no bar for the usual gate to resolve a title in.
    ///
    /// **Order-independent within the pass, and worth knowing why.** `artistIntakeSeen` is written in
    /// exactly one place — the cover's `onDismiss` — and the `-uiTesting` path returns *before*
    /// touching it. So `testEmptyLibrary` running first leaves the flag false, and this test never
    /// dismisses the intake, so it leaves it false too. Neither test can spoil the other, which is
    /// the only reason two tests that disagree about a launch argument can share one device.
    @MainActor
    func testFirstRun() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [UITestHooks.shotHourArgument, String(Self.defaultShotHour)]
        app.launch()
        note("launched without -uiTesting, so the intake is not suppressed")

        let question = app.staticTexts["What do you play?"]
        XCTAssertTrue(question.waitForExistence(timeout: Self.seedingTimeout), """
            the first-run intake never appeared. It is suppressed by `-uiTesting`, so check first \
            that this launch does not carry it.
            \(stepLog)
            """)

        // `A few quick things` is the intake's own header and is on no other screen; the question is
        // step one specifically, which is the step the marker asks for. `Question 1 of 6` is the
        // progress dots' label — five since ADR 0246 added the goals card, six since ADR 0248 asked
        // what you play first — and the only thing in the frame that distinguishes step 1 from the rest.
        captureChromeless(app, slug: "getting-started/first-run",
                          screen: "the first-run intake",
                          ownedBy: ["A few quick things", "What do you play?"],
                          alsoRequiring: ["Question 1 of 6", "Skip setup", "Guitar", "Bass", "Piano or keys"])

        // On to the goals card (ADR 0246), in the same test because it is the same launch further on.
        // A dream is answered, since the card orders its goals by it; two goals are picked, so the
        // figure shows the order the page describes. Never finished, so `artistIntakeSeen` stays false.
        // Continue stays put when it works, so it is tapped once a step by hand rather than through
        // `tap(_:revealing:)`, whose retry would read a slow redraw as a swallowed tap and skip a card.
        let next = app.buttons["Continue"]
        func advance(to step: Int) {
            awaitHittable(next)
            next.tap()
            let dots = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Question \(step) of 6")).firstMatch
            XCTAssertTrue(dots.waitForExistence(timeout: Self.shootTimeout),
                          "Continue didn't move on to question \(step).\n\(stepLog)")
            note("on question \(step)")
        }
        // Guitar, so the goals card is asked: anything without a neck leans on songs and skips it (ADR 0248).
        let guitar = app.buttons["Guitar"]
        awaitHittable(guitar)
        guitar.tap()
        note("picked Guitar")
        advance(to: 2)
        advance(to: 3)
        advance(to: 4)
        let dream = app.buttons["Play songs I love"]
        XCTAssertTrue(dream.waitForExistence(timeout: Self.shootTimeout), "no dream to pick.\n\(stepLog)")
        dream.tap()
        note("picked Play songs I love")
        advance(to: 5)

        let offered = app.scrollViews.buttons
        for rank in 0..<2 {
            let goal = offered.element(boundBy: rank)
            awaitHittable(goal)
            goal.tap()
            note("picked goal \(rank + 1): \(goal.label)")
        }
        captureChromeless(app, slug: "getting-started/goals-card",
                          screen: "the first-run goals card",
                          ownedBy: ["What are you working toward?"],
                          alsoRequiring: ["Question 5 of 6"])
    }
}
