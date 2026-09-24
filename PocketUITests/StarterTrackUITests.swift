import XCTest

/// Home's **Start here** card (ADR 0219), and what the song behind it arrives knowing (ADR 0220).
///
/// The unit tests pin the figures and prove `SongImporter.signpostStarterTrack` writes them onto an
/// uninserted song. What only a driven run can show is that they survive the **real** path: the card
/// adopts the bundled file, inserts the song into the live store, assigns the markers to a song that
/// is already in a context, and the waveform then reads all of it back. A missing inverse or a marker
/// that never got inserted passes every unit test and fails here.
///
/// **Stable across re-runs on one simulator**, which keeps its store: the card is offered while the
/// library is empty *or* holds only the starter track (`HomeFeed.shouldOfferStarterTrack`), so a
/// second run opens the song the first one adopted. First-run seeding writes no song, and no UI test
/// imports one.
final class StarterTrackUITests: UITestCase {

    @MainActor
    func testTheStarterTrackArrivesSignposted() {
        let app = launchApp()

        let card = app.buttons["Binta by Jack Trader, a song to start on"]
        // A simulator that has run the manual shoot holds its five seeded songs, and the card rightly
        // steps aside for them — delete the app and re-run. CI's simulator is always fresh.
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout),
                      "No Start here card on Home — does this simulator's store already hold songs?")

        // The metronome only offers a click once a grid exists, which needs a tempo *and* a downbeat
        // (`canUseMetronome` is `!beatGrid.isEmpty`). Without ADR 0220 this same control reads
        // "Set tempo". The longer wait covers adoption, which decodes the file off the main actor.
        let metronome = app.buttons["Metronome click"]
        XCTAssertTrue(tap(card, until: metronome, in: app)
                      || metronome.waitForExistence(timeout: Self.uiTimeout),
                      "The starter track opened without a beat grid")
        // An `Other`, not a button — see `ManualPlayerShots.testCarryTempo`. Full speed on open, so
        // the readout is the stored tempo itself: 83, not 0219's 104.
        XCTAssertTrue(app.descendants(matching: .any)["83 beats per minute"].exists)
        XCTAssertTrue(app.buttons["Hide gridlines"].exists, "Grid lines should be on when it opens")
        // Still no loop: making the first one is the player's job (ADR 0219 D1, kept by 0220). Asked
        // of the panel's own empty state, and before the panel is folded away below — once it is,
        // an absent loop row would prove nothing.
        XCTAssertTrue(app.staticTexts["No loops yet"].exists, "The starter track arrived with a loop")
        // `-uiTesting` alone keeps the first-song walkthrough off this screen (ADR 0149): it would sit
        // over the controls every other test here drives. `SongWalkthroughUITests` asks for it by name.
        XCTAssertFalse(app.buttons["Close the guide"].exists, "The walkthrough ran without -walkthrough")

        // Loops opens expanded and Markers collapsed (`WaveformPracticeModel`, per visit, never
        // persisted), which leaves the marker rows below the fold where SwiftUI has not built them.
        // Folding Loops away and opening Markers puts both rows on screen without a swipe. Swipes are
        // what the first three runs of this test tried: from the screen's centre one scrubs the
        // waveform, and from a panel header it lands as a tap and folds the panel shut again.
        app.buttons["Loops, expanded"].tap()
        app.buttons["Markers, collapsed"].tap()
        for label in ["Chords start", "Solo start"] {
            XCTAssertTrue(app.buttons["Go to \(label)"].waitForExistence(timeout: Self.uiTimeout),
                          "The starter track arrived without its \(label) marker")
        }
    }
}
