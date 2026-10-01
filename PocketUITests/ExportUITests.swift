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

    /// A tab written in My tabs exports as plain text from its reading screen (ADR 0236 D9).
    @MainActor
    func testAWrittenTabExportsAsPlainText() throws {
        let app = launchApp()
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Toolkit,")).firstMatch
        XCTAssertTrue(toolkit.waitForExistence(timeout: Self.uiTimeout), "no Toolkit on Home")
        XCTAssertTrue(tap(toolkit, until: app.navigationBars["Toolkit"], in: app), "the Toolkit didn't open")
        let myTabs = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My tabs,")).firstMatch
        XCTAssertTrue(myTabs.waitForExistence(timeout: Self.uiTimeout), "no My tabs row")
        myTabs.tap()

        app.navigationBars["My tabs"].buttons["New tab"].tap()
        let spot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "B string, fret 3,")).firstMatch
        XCTAssertTrue(spot.waitForExistence(timeout: Self.uiTimeout), "the writer didn't open")
        spot.tap()
        app.navigationBars["New tab"].buttons["Done"].tap()

        let written = app.cells.element(boundBy: 0)
        XCTAssertTrue(written.waitForExistence(timeout: Self.uiTimeout), "the tab wasn't kept")
        written.tap()
        tapToolbarMenu(app.buttons["Export tab"], in: app)
        let text = app.buttons["Plain text"]
        XCTAssertTrue(text.waitForExistence(timeout: Self.uiTimeout), "Export has no Plain text")
        text.tap()

        assertShareSheetOpens(showing: NSPredicate(format: "label ENDSWITH %@", ".txt"), in: app)
        leaveNoTabBehind(in: app)
    }

    /// A song's tab exports as a PDF from Map the song's Tab view (ADR 0236 D9). The seeded song's Verse
    /// riff has a piece, so its tab has something to draw.
    @MainActor
    func testASongsTabExportsAsAPDFFromMapTheSong() throws {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument])
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()

        let title = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test,")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 90), "the song player never opened")
        title.press(forDuration: 1.0)
        let map = app.buttons["Map the song"]
        XCTAssertTrue(reveal(map, in: app), "Song details has no Map the song")
        map.tap()

        let tabMode = app.segmentedControls.buttons["Tab"]
        XCTAssertTrue(tabMode.waitForExistence(timeout: Self.uiTimeout), "the map has no Tab view")
        tabMode.tap()
        tapToolbarMenu(app.buttons["Export tab"], in: app)
        let pdf = app.buttons["PDF"]
        XCTAssertTrue(pdf.waitForExistence(timeout: Self.uiTimeout), "Export has no PDF")
        pdf.tap()

        assertShareSheetOpens(showing: NSPredicate(format: "label ENDSWITH %@", ".pdf"), in: app)
    }

    /// Song details › Audio › **Send this song…** opens the send screen, and **Send…** builds the pack and
    /// opens the share sheet on it (ADR 0236 D4, D8).
    @MainActor
    func testASongSendsAsAPackFromSongDetails() throws {
        let app = launchApp()
        let card = app.buttons["Binta by Jack Trader, a song to start on"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout),
                      "No Start here card on Home — does this simulator's store already hold songs?")
        let title = app.buttons["Binta, Jack Trader"]
        XCTAssertTrue(tap(card, until: title, in: app) || title.waitForExistence(timeout: Self.uiTimeout),
                      "the starter track didn't open")
        title.press(forDuration: 1.0)

        let send = app.buttons["Send this song…"]
        XCTAssertTrue(reveal(send, in: app), "Song details › Audio has no Send this song…")
        // Tapped until it takes: a tap on a row in this sheet is now and then dropped, settled or not.
        XCTAssertTrue(tap(send, until: app.navigationBars["Send this song"], in: app),
                      "the send screen didn't open")
        let sendNow = app.navigationBars["Send this song"].buttons["Send…"]
        XCTAssertTrue(sendNow.waitForExistence(timeout: Self.uiTimeout), "the send screen has no Send…")
        sendNow.tap()

        // A file URL's sheet names it without its extension: the pack is named for the song.
        assertShareSheetOpens(showing: NSPredicate(format: "label == %@", "Binta"), in: app)
    }

    /// A pack someone sent opens on **Add this song?**, and **Add** lands it in the library as the
    /// receiver's own (ADR 0236 D4, D5). `-receiveSongPack` builds the pack at launch and opens it as a
    /// tapped file arrives; everything from there is the real path.
    @MainActor
    func testAReceivedSongLandsInTheLibrary() throws {
        let app = launchApp(extraArguments: [UITestHooks.receivePackArgument])
        let preview = app.navigationBars["Add this song?"]
        XCTAssertTrue(preview.waitForExistence(timeout: 30), "the pack didn't open on the receive door")
        let sentBy = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sent by Tester")).firstMatch
        XCTAssertTrue(sentBy.exists, "the preview doesn't say who sent it")

        // Tapped until it takes: on a cold iOS 18.5 simulator a tap the moment the sheet appears lands
        // and does nothing, and the sheet stays up. Once Add has gone, the landing is only slow.
        let added = app.alerts["Added"]
        XCTAssertTrue(tap(preview.buttons["Add"], until: added, in: app) || added.waitForExistence(timeout: 30),
                      "the song never landed")
        let said = added.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "“Pack test")).firstMatch
        XCTAssertTrue(said.exists, "the confirmation doesn't name the song")
        // Tapped until the alert has gone: a tap during its appear animation is dropped, and the alert
        // then sits over Home, where every card is found and none is hittable.
        for _ in 0..<3 where added.exists {
            added.buttons["OK"].tap()
            if waitForDisappearance(of: added, timeout: 3) { break }
        }
        XCTAssertFalse(added.exists, "the confirmation never closed")

        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pack test")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the received song isn't in the library")
    }

    // MARK: - Steps

    /// A toolbar `Menu` is found but never hittable on CI's iOS 18, so it's tapped by coordinate. A dead
    /// control still fails: the menu wouldn't open, and the next wait would time out.
    @MainActor
    private func tapToolbarMenu(_ menu: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(menu.waitForExistence(timeout: Self.uiTimeout), "no \(menu.description) in the toolbar")
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Close the share sheet and delete the tab the test wrote. Best effort, with no assertions: the
    /// test has already said what it came to say, and the other My tabs tests count rows as a delta.
    @MainActor
    private func leaveNoTabBehind(in app: XCUIApplication) {
        let sheet = app.otherElements["ActivityListView"]
        let close = sheet.buttons["Close"]
        if close.exists { close.tap() } else { sheet.swipeDown(velocity: .fast) }
        _ = waitForDisappearance(of: sheet)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        guard app.navigationBars["My tabs"].waitForExistence(timeout: Self.uiTimeout) else { return }
        app.cells.element(boundBy: 0).swipeLeft()
        let delete = app.buttons["Delete Untitled tab"].firstMatch
        if delete.waitForExistence(timeout: 3) { delete.tap() }
    }

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
