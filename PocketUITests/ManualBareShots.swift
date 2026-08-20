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
    /// it the song library is behind the Pro wall, so the figure would be a paywall rather than an
    /// empty state. First-launch seeding still runs — six exercises and a routine — and writes **no
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

        let question = app.staticTexts["Where are you with the guitar?"]
        XCTAssertTrue(question.waitForExistence(timeout: Self.seedingTimeout), """
            the first-run intake never appeared. It is suppressed by `-uiTesting`, so check first \
            that this launch does not carry it.
            \(stepLog)
            """)

        // `A few quick things` is the intake's own header and is on no other screen; the question is
        // step one specifically, which is the step the marker asks for. `Question 1 of 4` is the
        // progress dots' label — the "first of four dots" the shoot list names, and the only thing
        // in the frame that distinguishes step 1 from the three steps after it.
        captureChromeless(app, slug: "getting-started/first-run",
                          screen: "the first-run intake",
                          ownedBy: ["A few quick things", "Where are you with the guitar?"],
                          alsoRequiring: ["Question 1 of 4", "Skip setup"])
    }
}
