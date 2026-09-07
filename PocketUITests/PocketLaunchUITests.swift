import XCTest

final class PocketLaunchUITests: UITestCase {

    @MainActor
    func testAppLaunches() throws {
        // `launchApp()` also proves first-launch seeding completes — so this is now a smoke test of
        // the launch *and* the seeding path, and it is the test that fails first and most clearly if
        // the readiness signal itself ever breaks.
        let app = launchApp()
        // The app launches into the home hub (HomeView, ADR 0044). Assert a stable element
        // present whether or not there's any practice history yet: the greeting headline.
        XCTAssertTrue(app.staticTexts["Ready to practice?"].waitForExistence(timeout: Self.uiTimeout))
    }

    /// **The six map labels, in one place** (ADR 0197 D2).
    ///
    /// ADR 0102 §1 made a home destination's accessibility label the UI-test contract, and until now
    /// that contract was only ever asserted *incidentally* — five suites and six shoot classes each
    /// tap the one card they need on the way somewhere else, so a label that moved would fail in
    /// whichever of them ran first, describing a Practice run or a Toolkit section rather than a
    /// renamed control.
    ///
    /// ADR 0197 moved all six call sites in one commit and dropped the subtitles they used to draw.
    /// The labels deliberately did **not** move with them — the description a strip showed is now
    /// spoken instead — and that is exactly the kind of "kept on purpose" that decays without
    /// something watching it. So it is asserted directly, once, here.
    ///
    /// `Song library` is matched by prefix because its label carries the song count, the same way
    /// every other suite matches it.
    @MainActor
    func testHomeMapCarriesEverySpokenLabel() throws {
        let app = launchApp()

        for label in ["Practice, your exercises and training runs",
                      "Metronome, standalone click and tempo trainer",
                      "Journal, your notes and practice takes",
                      "Red Moon Oracle, a reading of your week",
                      "Toolkit, tuner, your chords and a glossary"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: Self.uiTimeout), """
                no home tile labelled '\(label)'. Since ADR 0197 the tiles draw a glyph and a name \
                only, so this label is the whole of what VoiceOver gets and what every other UI \
                test taps by — it is not free to change with the copy on screen.
                """)
        }

        let library = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout),
                      "no home tile whose label begins 'Song library,' — its tail is the song count.")
    }
}
