import XCTest

/// **A song's exercises sit behind a row** (ADR 0309 D3). Song details listed the linked drills on the
/// sheet; now an **Exercises** row counts them and opens `SongExercisesScreen`, which raises the picker and
/// pushes the run screen itself. That's the new wiring a unit test can't reach: a presentation raised from
/// a pushed screen inside a sheet, which is the shape that has dismissed the sheet instead before (ADR 0258
/// D3). The row's words are unit-tested (`DetailSheetTextTests`).
///
/// The seeded song is the naming test's own (`-seedNamingPiece`), and the test unlinks what it linked, so
/// the store is as it found it. Its counts are read as a change, not as a fresh install's: the simulator
/// keeps its store between runs.
final class SongExercisesUITests: UITestCase {

    private let drill = "Spider Walk"

    @MainActor
    func testTheExercisesRowOpensTheListLinksADrillAndCountsIt() {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument])
        openSongDetails(in: app)

        let row = exercisesRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "Song details has no Exercises row")
        XCTAssertTrue(scrollIntoView(row, in: app), "the Exercises row isn't reachable")
        XCTAssertTrue(row.label.contains("None"),
                      "the seeded song should start with no drills linked; the row read \(row.label)")
        attach(app, named: "song-details-exercises-row")

        // The row opens the list, and the list raises the picker: link one drill.
        XCTAssertTrue(tap(row, until: app.navigationBars["Exercises"], in: app), "Exercises didn't open")
        let link = app.buttons["Link exercises"]
        XCTAssertTrue(link.waitForExistence(timeout: Self.uiTimeout), "Exercises has no Link exercises")
        XCTAssertTrue(tap(link, until: app.navigationBars["Link exercises"], in: app),
                      "Link exercises opened no picker")
        let candidate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", drill)).firstMatch
        XCTAssertTrue(candidate.waitForExistence(timeout: Self.uiTimeout), "\(drill) isn't in the picker")
        candidate.tap()
        let picker = app.navigationBars["Link exercises"]
        picker.buttons["Done"].tap()
        // The list under a sheet is in the tree before the sheet has gone, so a tap made while it slides
        // away lands on the sheet. Wait for it to go.
        XCTAssertTrue(waitForDisappearance(of: picker), "the picker didn't close on Done")

        // Closing the picker leaves the list, with the drill in it, not Song details or the library.
        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: Self.uiTimeout),
                      "closing the picker left Exercises")
        let linked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", drill)).firstMatch
        XCTAssertTrue(linked.waitForExistence(timeout: Self.uiTimeout), "\(drill) isn't listed once linked")
        attach(app, named: "song-exercises-linked")

        // A linked drill is a route (ADR 0172): it opens its run screen, and back returns to the list.
        XCTAssertTrue(tap(linked, until: app.navigationBars[drill], in: app),
                      "the drill's run screen didn't open from the list")
        app.navigationBars[drill].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: Self.uiTimeout),
                      "back from the run screen didn't return to Exercises")

        // Back on Song details, the row counts it.
        app.navigationBars["Exercises"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Song details"].waitForExistence(timeout: Self.uiTimeout),
                      "back from Exercises didn't return to Song details")
        XCTAssertTrue(exercisesRow(in: app).label.contains("1 linked"),
                      "the row didn't count the drill; it read \(exercisesRow(in: app).label)")

        // Unlink it with a swipe, which also leaves the store as the test found it.
        XCTAssertTrue(tap(exercisesRow(in: app), until: app.navigationBars["Exercises"], in: app),
                      "Exercises didn't open the second time")
        let toUnlink = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", drill)).firstMatch
        XCTAssertTrue(toUnlink.waitForExistence(timeout: Self.uiTimeout), "\(drill) went missing")
        toUnlink.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: Self.uiTimeout), "a swipe offered no Delete")
        delete.tap()
        XCTAssertTrue(app.staticTexts["No drills linked yet."].waitForExistence(timeout: Self.uiTimeout),
                      "unlinking the only drill didn't empty the list")
    }

    // MARK: - Helpers

    private func exercisesRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exercises")).firstMatch
    }

    /// Library → the naming test's song → hold its title in the player for Song details, as
    /// `WatchOnNeckUITests` does.
    @MainActor
    private func openSongDetails(in app: XCUIApplication) {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open")
        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library")
        XCTAssertTrue(scrollIntoView(song, in: app), "the seeded song isn't reachable")
        song.tap()
        let heading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test,")).firstMatch
        // CI's simulator can take most of a minute to open the player, as `WatchOnNeckUITests` found.
        XCTAssertTrue(heading.waitForExistence(timeout: 90), "the song player never opened")
        heading.press(forDuration: 1.0)
        XCTAssertTrue(app.navigationBars["Song details"].waitForExistence(timeout: Self.uiTimeout),
                      "holding the title didn't open Song details")
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
