import XCTest

/// The doors ADR 0236 adds, as wiring. `TakeExportTests` covers what a file is called and where it is
/// staged; neither can say whether *Export take…* is on the menu a player holds, or whether tapping it
/// reaches the share sheet. A `ShareLink` inside a `contextMenu` is exactly the kind of thing that can
/// be built right and still do nothing.
///
/// **The share sheet is found by `ActivityListView`**, the identifier UIKit has given its activity
/// sheet since iOS 13. The sheet runs out of process and draws blank in a screenshot, so the tree is
/// the only witness. The file name is checked by its extension rather than its full text, since the
/// date in it is the seed's, and the seed's date is yesterday's.
final class ExportUITests: UITestCase {

    /// The share sheet waits on a system service that runs out of process before it appears: about two
    /// seconds on a warm simulator, and past `uiTimeout` on a cold one.
    private let shareSheetTimeout: TimeInterval = 30

    /// Hold the seeded take in the Journal, then **Export take…**, and the share sheet opens on a file.
    @MainActor
    func testATakeInTheJournalExportsFromItsHoldMenu() throws {
        let app = launchApp(extraArguments: ["-seedHistory"])
        let take = try openJournalTake(in: app)

        take.press(forDuration: 1.0)
        let export = app.buttons["Export take…"]
        XCTAssertTrue(export.waitForExistence(timeout: Self.uiTimeout), "the take's hold menu has no Export take…")
        export.tap()

        assertShareSheetOpens(showing: NSPredicate(format: "label ENDSWITH %@", ".m4a"), in: app)
    }

    /// The take's own screen (ADR 0174) offers the same item in its **Take actions** menu.
    @MainActor
    func testATakesOwnScreenExportsFromItsActionsMenu() throws {
        let app = launchApp(extraArguments: ["-seedHistory"])
        try openJournalTake(in: app).tap()

        // Tapped by coordinate: a toolbar `Menu` is found but never hittable on CI's iOS 18. If the
        // control were really dead the menu wouldn't open, and the next wait fails.
        let actions = app.buttons["Take actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: Self.uiTimeout), "the take's screen did not open")
        actions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let export = app.buttons["Export take…"]
        XCTAssertTrue(export.waitForExistence(timeout: Self.uiTimeout), "Take actions has no Export take…")
        export.tap()

        assertShareSheetOpens(showing: NSPredicate(format: "label ENDSWITH %@", ".m4a"), in: app)
    }

    /// Song details › Audio offers **Export audio file only…** for a song Red Moon holds a copy of, and
    /// it reaches the share sheet. The starter track is that song: it ships in the app, is the author's
    /// own recording, and arrives by one tap on a fresh install (ADR 0219).
    @MainActor
    func testASongsAudioExportsFromSongDetails() throws {
        let app = launchApp()

        // Adopt the starter track if it isn't in the library yet. On a simulator that already holds
        // it, the card still opens it (`HomeFeed.shouldOfferStarterTrack`).
        let card = app.buttons["Binta by Jack Trader, a song to start on"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout),
                      "No Start here card on Home — does this simulator's store already hold songs?")
        let title = app.buttons["Binta, Jack Trader"]
        XCTAssertTrue(tap(card, until: title, in: app) || title.waitForExistence(timeout: Self.uiTimeout),
                      "the starter track didn't open")

        // Holding the title on the practice screen opens Song details: the door one hold from where a
        // song is heard (`SongAudioSection`).
        title.press(forDuration: 1.0)

        let export = app.buttons["Export audio file only…"]
        XCTAssertTrue(reveal(export, in: app), "Song details › Audio has no Export audio file only…")
        export.tap()

        // A file URL's sheet names it without its extension, so this is the song's title.
        assertShareSheetOpens(showing: NSPredicate(format: "label == %@", "Binta"), in: app)
    }

    // MARK: - Steps

    /// Swipe until `element` exists and sits **wholly clear of the bottom edge**. A `List` in a sheet
    /// builds its rows lazily, so a row below the fold doesn't exist yet and `scrollIntoView` (which
    /// needs it to) can't reach it. And `isHittable` alone is not enough: a row peeking out by a sliver
    /// at the home indicator reports hittable, and the tap goes to the system instead.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        let floor = app.windows.firstMatch.frame.maxY - 100
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 2), element.isHittable, element.frame.maxY < floor {
                return settled(element)
            }
            app.swipeUp()
        }
        return element.exists && element.isHittable && element.frame.maxY < floor && settled(element)
    }

    /// Wait until `element` stops moving. A list still coasting from a swipe takes the next tap as
    /// "stop scrolling", so a tap on a row mid-glide never reaches the row.
    @MainActor
    private func settled(_ element: XCUIElement) -> Bool {
        var last = element.frame
        for _ in 0..<10 {
            usleep(300_000)
            let now = element.frame
            if now == last { return true }
            last = now
        }
        return false
    }

    /// Home → Journal → the seeded take's row, scrolled into reach.
    @MainActor
    private func openJournalTake(in app: XCUIApplication) throws -> XCUIElement {
        let journal = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journal.waitForExistence(timeout: Self.uiTimeout), "no Journal card on Home")
        journal.tap()
        XCTAssertTrue(app.buttons["Journal options"].waitForExistence(timeout: Self.uiTimeout),
                      "the Journal did not open")

        let take = app.buttons[UITestHooks.takeRowOpen].firstMatch
        XCTAssertTrue(take.waitForExistence(timeout: Self.uiTimeout), "no seeded take in the Journal")
        XCTAssertTrue(scrollIntoView(take, in: app), "the seeded take was not reachable")
        return take
    }

    /// The share sheet is up, and something in it is labelled as `name` describes: the file the
    /// export staged, as the sheet's header names it.
    @MainActor
    private func assertShareSheetOpens(showing name: NSPredicate, in app: XCUIApplication) {
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: shareSheetTimeout), "the export did not open the share sheet")
        let named = sheet.descendants(matching: .any).matching(name).firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: Self.uiTimeout),
                      "the share sheet opened, but not on the file expected (\(name.predicateFormat))")
    }
}
