import XCTest

/// The manual's **Metronome** figures (ADR 0165, Phase 5) — the screen, its settings sheet and the
/// tempo automator.
///
/// Six markers, three frames. `metronome/screen`, `reference/metronome` and `metronome/tempo-controls`
/// are a screen, a screen and a band crop of one frame; `metronome/settings-sheet` and
/// `reference/metronome-settings` are one sheet photographed for two pages.
final class ManualMetronomeShots: ManualShotCase {

    /// The tempo both metronome markers specify. The engine opens at `defaultBPM`, which is **90**, so
    /// this is six taps away rather than free — and a figure captioned 96 that shows 90 is the kind of
    /// error the prose check cannot see, because the number lives in the image.
    private static let figureBPM = 96

    /// How many dropped `+` taps the run tolerates before calling the stepper broken rather than the
    /// machine busy. Generous, because each one costs only `tapProbeTimeout` and the alternative is a
    /// six-minute shoot lost to a single dropped event; bounded, because a stepper that has genuinely
    /// stopped responding should say so rather than spin.
    private static let maxSwallowedTaps = 6

    /// `metronome/screen` · `reference/metronome` · `metronome/tempo-controls` — 96 BPM, 4/4, stopped.
    @MainActor
    func testMetronome() {
        let app = launchForShoot()
        openMetronome(in: app)
        raiseTempoToFigureBPM(in: app)

        // "4/4, stopped" needs no driving — both are the engine's opening state — but they are still
        // asserted, because "no work needed" and "still true" are different claims and only the
        // second one is what the figure rests on. `Start` is the transport's label while stopped; it
        // reads `Pause` or `Resume` otherwise.
        capture(app, slug: "metronome/screen",
                assertingOnScreen: "Metronome",
                alsoRequiring: ["Start"],
                orBeginningWith: ["\(Self.figureBPM) beats per minute",
                                  "Metronome settings. Time signature 4/4"],
                alsoServing: ["reference/metronome", "metronome/tempo-controls"])
    }

    /// `metronome/settings-sheet` · `reference/metronome-settings` — time signature, subdivision and
    /// click withdrawal.
    ///
    /// ⚠️ The sheet's navigation title is **also** "Metronome", so `assertingOnScreen` cannot tell it
    /// apart from the screen underneath it — a missed tap here would pass that check cleanly. `Done`
    /// is what actually proves the sheet is up: it is the sheet's own dismiss control, and the screen
    /// underneath carries no button by that name.
    ///
    /// The first attempt asserted the **click-withdrawal footer** instead, and failed: that is the
    /// third section of a `Form` holding seven time signatures above it, so it is far below the fold
    /// and absent from the accessibility tree entirely. Worth keeping as a note rather than a silent
    /// edit — the sheet is taller than one screen, which is a fact about the *figure* too, and both
    /// markers' alt text had to be corrected to describe the top of the sheet rather than all three
    /// of its sections.
    @MainActor
    func testMetronomeSettings() {
        let app = launchForShoot()
        openMetronome(in: app)

        // The meter control is a button, not a menu: its label carries the current signature and
        // subdivision after a fixed opening, so it is matched on that opening.
        // Arrival is `Done`, not a navigation bar: the sheet's bar is titled "Metronome" too, so the
        // usual gate cannot tell it from the screen underneath. `Done` is the sheet's own control.
        tapRow(labelStartingWith: "Metronome settings.", in: app,
               arrivingAt: app.buttons["Done"], called: "the settings sheet")

        capture(app, slug: "metronome/settings-sheet",
                assertingOnScreen: "Metronome",
                alsoRequiring: ["Done"],
                alsoServing: ["reference/metronome-settings"])
    }

    /// `metronome/automator` — the ramp armed **By Bars**.
    ///
    /// Armed, not running: arming reveals the fields, and `Start ramp` is the control that would set
    /// it climbing. A climbing ramp changes the BPM under the shutter, which is how a figure ends up
    /// showing a tempo nothing in the manual mentions.
    @MainActor
    func testMetronomeAutomator() {
        let app = launchForShoot()
        openMetronome(in: app)
        // Raised to the same 96 as `metronome/screen`. Without this the automator figure sits on the
        // engine's opening 90, and the two figures — adjacent on one page of the manual — show the
        // readout at different tempos with nothing in the prose to explain the change.
        raiseTempoToFigureBPM(in: app)

        // A segmented `Picker` — its options are buttons inside the segmented control, not buttons on
        // the screen, the same shape as the Journal's All / Notes / Takes filter.
        let byBars = app.segmentedControls.buttons["By Bars"]
        XCTAssertTrue(byBars.waitForExistence(timeout: Self.shootTimeout),
                      "the automator's Off / By Bars / By Time picker never appeared. \(stepLog)")
        byBars.tap()
        note("armed the automator By Bars")

        // `Start ramp` exists only while a mode is armed — the panel draws its fields, the no-limit
        // toggle, the progress line and this button behind `automatorMode != .off`. It is therefore
        // the one string that separates the armed panel from the idle one.
        capture(app, slug: "metronome/automator",
                assertingOnScreen: "Metronome",
                alsoRequiring: ["Start ramp"])
    }

    // MARK: - Driving

    /// Nudge the engine from its opening 90 up to the 96 both figures are captioned with.
    ///
    /// One tap per BPM on the `+` stepper. The stepper also auto-repeats on a hold, which is why these
    /// are discrete taps rather than a press-and-hold: a hold overshoots by however long the runner
    /// took to let go, and the number in the frame would then vary from shoot to shoot.
    @MainActor
    private func raiseTempoToFigureBPM(in app: XCUIApplication) {
        let plus = app.buttons["Increase tempo"]
        XCTAssertTrue(plus.waitForExistence(timeout: Self.shootTimeout),
                      "no + stepper on the metronome. \(stepLog)")

        // **One tap at a time, each confirmed.** This was `for _ in 0..<steps { plus.tap() }`, and it
        // is the same swallowed-tap problem as the Settings gear and the Journal's filter, multiplied
        // by six: any one event dropped leaves the tempo a beat short, and on 2026-08-16 one was, and
        // the shoot failed on `95 beats per minute`. Six blind taps is six chances to lose one.
        //
        // The readout is re-read after every tap rather than counted, so a dropped tap is retried and
        // an accepted one is never repeated — a loop that just tapped harder would overshoot to 97,
        // which photographs as confidently as 95 and is equally wrong.
        var bpm = StandaloneMetronomeDefaults.bpm
        var swallowed = 0
        while bpm < Self.figureBPM {
            plus.tap()
            let next = element(in: app, labelStartingWith: "\(bpm + 1) beats per minute")
            if next.waitForExistence(timeout: Self.tapProbeTimeout) {
                bpm += 1
                continue
            }
            swallowed += 1
            note("+ tap \(swallowed) did nothing — still \(bpm) BPM, retrying")
            XCTAssertLessThanOrEqual(swallowed, Self.maxSwallowedTaps,
                                     """
                                     the + stepper stopped responding at \(bpm) BPM, \
                                     \(Self.figureBPM - bpm) short of the figure.
                                     \(stepLog)
                                     """)
            if swallowed > Self.maxSwallowedTaps { return }
        }
        note("reached \(bpm) BPM" + (swallowed > 0 ? " (\(swallowed) tap(s) swallowed)" : ""))
    }

    // MARK: - Navigation

    /// Home ▸ `Metronome`.
    ///
    /// Arrival is the **tap-tempo button**, not the word "Metronome" — Home's own card is titled
    /// "Metronome", so waiting for that text is a test that cannot fail, and it passed while the app
    /// sat on Home. `Tap to set tempo` exists on this screen and nowhere on the way to it.
    @MainActor
    private func openMetronome(in app: XCUIApplication) {
        tapHomeCard("Metronome, standalone click and tempo trainer",
                    in: app,
                    arrivingAt: app.buttons["Tap to set tempo"].firstMatch)
    }
}

/// The engine's opening tempo, restated for the UI-test target.
///
/// `StandaloneMetronomeEngine.defaultBPM` is the real owner, but the engine lives in the app target
/// and a UI test cannot import it — a UI test only ever sees the app through its accessibility tree.
/// Hard-coding 90 at the call site would leave a silent trap: change the engine's default and this
/// shoot taps the wrong number of times and photographs the wrong tempo, with nothing to say why.
/// Naming it here does not fix that, but it puts the assumption somewhere a grep for `defaultBPM`
/// will find. The capture asserts the resulting readout, so the failure is loud either way.
enum StandaloneMetronomeDefaults {
    static let bpm = 90
}
