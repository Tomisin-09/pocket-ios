import XCTest

/// The manual's **Settings** figures (ADR 0165, Phase 5) — the hub and four of its destinations.
///
/// Six markers, five frames: `reference/settings-privacy` and `privacy/settings` are the same screen
/// photographed for two pages, so only one attachment is made (see `ManualShotCase.capture`).
///
/// Every destination is a push, so each test returns to the hub by relaunching rather than by tapping
/// Back. A relaunch costs seeding time but cannot leave the shoot one screen deeper than it thinks it
/// is — and a figure taken one screen off is the failure this whole harness exists to prevent.
final class ManualSettingsShots: ManualShotCase {

    /// `reference/settings-hub` — the nine destinations that replaced the flat thirteen-section form.
    @MainActor
    func testSettingsHub() {
        let app = launchForShoot()
        openSettings(in: app)
        // `Red Moon Pro` rather than the first row: it sits below `You` and its presence proves the
        // list rendered past its first cell, which an assertion on the nav title alone does not.
        capture(app, slug: "reference/settings-hub",
                assertingOnScreen: "Settings",
                alsoRequiring: ["Red Moon Pro"])

        // The hub ships **nine** destinations, and the manual's alt text names all nine. A Debug
        // build adds a tenth — `Developer` — which the first shoot duly photographed into a figure
        // whose own page says it is not there. `ScreenshotSeed.isShooting` now hides it; this is the
        // assertion that keeps it hidden, because nothing else in the suite would notice it coming
        // back and the figure would be wrong in a way that reads as perfectly normal.
        XCTAssertFalse(app.staticTexts["Developer"].exists,
                       """
                       the Debug-only Developer row is on the Settings hub during a shoot, so \
                       reference/settings-hub shows a destination that ships to nobody.
                       \(stepLog)
                       """)
    }

    /// `reference/settings-you` — the player's own details.
    @MainActor
    func testSettingsYou() {
        let app = launchForShoot()
        openSettings(in: app)
        tapRow(labelStartingWith: "You", in: app)
        capture(app, slug: "reference/settings-you", assertingOnScreen: "You")
    }

    /// `reference/settings-privacy` · `privacy/settings` — one screen, two pages.
    ///
    /// ADR 0162 D7 rests on this control staying reachable: it is the DUAA "simple, free means of
    /// objecting", and it is the one Settings screen the manual documents twice.
    @MainActor
    func testSettingsPrivacy() {
        let app = launchForShoot()
        openSettings(in: app)
        tapRow(labelStartingWith: "Privacy", in: app)
        capture(app, slug: "reference/settings-privacy", assertingOnScreen: "Privacy")
    }

    /// `reference/settings-routines` — auto-start, auto-advance, rest length, song looping.
    @MainActor
    func testSettingsRoutines() {
        let app = launchForShoot()
        openSettings(in: app)
        tapRow(labelStartingWith: "Routines", in: app)
        capture(app, slug: "reference/settings-routines",
                assertingOnScreen: "Routines",
                alsoRequiring: ["Auto-start blocks"])
    }

    /// `reference/settings-sound` — haptics and the metronome sound.
    @MainActor
    func testSettingsSound() {
        let app = launchForShoot()
        openSettings(in: app)
        tapRow(labelStartingWith: "Sound & feel", in: app)
        capture(app, slug: "reference/settings-sound",
                assertingOnScreen: "Sound & feel",
                alsoRequiring: ["Haptics"])
    }

    // MARK: - Navigation

    /// Home ▸ the gear. A push, not a sheet (ADR 0050).
    ///
    /// `.firstMatch` because "Settings" is a common label and the toolbar's is the one on screen at
    /// launch; matched exactly rather than by prefix, since a prefix would also take the metronome's
    /// *Metronome settings* control on any screen that carried one.
    ///
    /// The wait for the hub itself is not decoration. Without it the row query starts while the push
    /// is still animating, and on a loaded runner it can time out against a screen that is on its way
    /// in — which failed as *"no row whose label begins 'Privacy'"*, a sentence that sends you looking
    /// at the row rather than at the navigation. Gating on arrival both fixes the race and puts the
    /// failure at the step that actually went wrong.
    @MainActor
    private func openSettings(in app: XCUIApplication) {
        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.shootTimeout),
                      "no Settings gear on Home. \(stepLog)")
        gear.tap()
        note("tapped the Settings gear")

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.shootTimeout),
                      "the Settings gear was tapped but the hub never appeared. \(stepLog)")
        note("arrived at the Settings hub")
    }
}
