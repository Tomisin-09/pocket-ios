import XCTest

/// A copy the map made, removed from its hold menu (ADR 0310 D5): **Copy to…** makes one, its hold menu offers
/// **Remove copy**, the map asks, and only the copy goes. Which copies are the map's, and what a shift does, are
/// unit-tested (`SongMapCopyBarTests`, `SongMapCopyWriterTests`); what only a driven run shows is the offer in
/// the menu and the question asked from the map's root, which is where iOS 18 has lost a write before.
///
/// The way in is the watch seed's song (`-seedWatchPiece`), whose *Verse riff* has a piece to copy. The seed
/// takes out any copy the map made on each launch, so a run that fails before removing it leaves nothing.
final class SongMapCopyUITests: UITestCase {

    /// The player loads the song's audio before it shows.
    private let playerTimeout: TimeInterval = 90
    private let notesPiece = NSPredicate(format: "label ENDSWITH %@", ", notes")

    @MainActor
    func testACopyTheMapMadeIsRemovedFromItsHoldMenuAndNothingElseIs() {
        let app = launchApp(extraArguments: [UITestHooks.watchPieceArgument])
        let riff = openMap(in: app)
        let before = Set(app.buttons.matching(notesPiece).allElementsBoundByIndex.map(\.label))

        holdForMenu(riff)
        let copyTo = app.buttons["Copy to…"]
        XCTAssertTrue(copyTo.waitForExistence(timeout: Self.uiTimeout), "the riff's hold menu has no Copy to…")
        copyTo.tap()
        let sheet = app.navigationBars["Copy Verse riff"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.uiTimeout), "Copy to… opened no sheet")
        let place = app.buttons["copy.target"].firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: Self.uiTimeout), "the sheet offers nowhere to copy to")
        place.tap()
        sheet.buttons["Copy"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet), "the copy sheet didn't close")

        let copy = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND NOT (label IN %@)", ", notes",
                                                    Array(before))).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: Self.uiTimeout), "no new piece on the map after Copy")
        let name = copy.label
        attach(app, named: "copy-made")
        holdForMenu(copy)
        let remove = app.buttons["Remove copy"]
        XCTAssertTrue(remove.waitForExistence(timeout: Self.uiTimeout),
                      "a copy the map just made offers no Remove copy")
        attach(app, named: "copy-hold-menu")
        remove.tap()
        // The question's own button, once the menu has gone.
        let confirm = app.buttons["Remove copy"]
        XCTAssertTrue(confirm.waitForExistence(timeout: Self.uiTimeout), "Remove copy didn't ask first")
        confirm.tap()
        XCTAssertTrue(waitForDisappearance(of: app.buttons[name]), "the copy is still on the map")
        XCTAssertEqual(Set(app.buttons.matching(notesPiece).allElementsBoundByIndex.map(\.label)), before,
                       "removing the copy changed something else on the map")

        holdForMenu(riff)
        XCTAssertTrue(app.buttons["Copy to…"].waitForExistence(timeout: Self.uiTimeout))
        XCTAssertFalse(app.buttons["Remove copy"].exists, "a loop the player made offers Remove copy")
    }

    // MARK: - The way in

    /// Song library ▸ the seeded song ▸ hold its title for Song details ▸ Map the song, stopping on the map
    /// with the riff's piece in sight.
    @MainActor
    private func openMap(in app: XCUIApplication) -> XCUIElement {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()
        let heading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test,")).firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: playerTimeout), "the song player never opened")
        heading.press(forDuration: 1.0)
        let map = app.buttons["Map the song"]
        XCTAssertTrue(map.waitForExistence(timeout: Self.uiTimeout), "Song details has no Map the song")
        let riff = app.buttons["Verse riff, notes"]
        XCTAssertTrue(tap(map, until: riff, in: app), "the riff's piece isn't on the map")
        return riff
    }

    /// Hold a piece for its menu. Two seconds, not the suite's usual one: right after a copy the app is
    /// busy, and on CI a one-second hold let go while the context menu was still lifting, which iOS reads
    /// as a tap, so the copy's tab opened instead of its menu (three retries, 23–24 Nov; the run's video
    /// shows the lift starting and the tab sheet opening). Holding past the menu's opening costs nothing:
    /// it stays open. `GestureHintUITests` met the same thing and holds for 1.5.
    @MainActor
    private func holdForMenu(_ piece: XCUIElement) {
        piece.press(forDuration: 2.0)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
