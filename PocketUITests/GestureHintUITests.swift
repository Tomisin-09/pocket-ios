import XCTest

/// **Hold tips** on the song player (ADR 0244). Which tag shows, and when none may, is unit-tested
/// (`GestureHintTests`). What only a driven run shows is the wiring: that a real control reports where it
/// is, that the tag is drawn beside it and says the right thing, that its ✕ — or the hold itself — puts
/// it away without another taking its place in the same opening, and that the switch in Settings is
/// what the layer reads.
///
/// The way in is the naming seed (`-seedNamingPiece`): its song has one loop, *Verse riff*, and the loop
/// row is the tag that ranks first. `-gestureHints` opens the tags under test and brings every one back,
/// so each test starts with nothing retired.
final class GestureHintUITests: UITestCase {

    /// The player loads the song's audio before it shows; generous, as the shoot's is.
    private let playerTimeout: TimeInterval = 90

    /// `GestureHint.loopRow.text`. Written out: the UI-test target can't see the app's types, and a tag
    /// that says something else should fail here.
    private let loopTip = "Hold a loop to edit it: its name, its range and how you practise it."

    @MainActor
    func testTheLoopsTipShowsAndItsCloseButtonPutsItAway() {
        let app = openSeededSong()
        let tip = app.staticTexts[loopTip]
        XCTAssertTrue(tip.waitForExistence(timeout: Self.uiTimeout), "no tip beside the loop row")
        XCTAssertTrue(anyTip(in: app).exists, "the tip shows, but the query for any tip can't see it")
        attach(app, named: "gesture-tip-loop-row")

        anyTip(in: app).tap()
        XCTAssertTrue(waitForDisappearance(of: tip), "✕ didn't close the tip")
        // One an opening: nothing takes its place, though five more are in play.
        XCTAssertFalse(anyTip(in: app).waitForExistence(timeout: 3), "a second tip showed in the same opening")
    }

    @MainActor
    func testHoldingTheLoopPutsItsTipAway() {
        let app = openSeededSong()
        let tip = app.staticTexts[loopTip]
        XCTAssertTrue(tip.waitForExistence(timeout: Self.uiTimeout), "no tip beside the loop row")
        XCTAssertTrue(anyTip(in: app).exists, "the tip shows, but the query for any tip can't see it")

        // The hold the tip describes lands through it: the ring is never hit-tested. 1.5 s, not the usual
        // 1.0: on a simulator's first run a busy main thread read a 1-second press as a tap (iOS 18.5, seen
        // 2026-10-03), and a tap here plays the loop, which hides the tip and opens nothing.
        app.buttons["Play Verse riff"].press(forDuration: 1.5)
        let sheet = app.navigationBars["Edit loop"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.uiTimeout), "holding the row didn't open Edit loop")
        sheet.buttons["Cancel"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet), "Cancel didn't close Edit loop")

        XCTAssertFalse(tip.exists, "the tip outlived the hold it describes")
        XCTAssertFalse(anyTip(in: app).waitForExistence(timeout: 3), "a second tip showed in the same opening")
    }

    /// **Settings ▸ Song player ▸ Show hold tips** drives the layer both ways (D6): off, the song opens with
    /// no tip; on again, from the player's own settings sheet, the tip that was waiting shows. The second
    /// half is what makes the first mean something — a tip that hadn't loaded yet would also be absent.
    @MainActor
    func testTheSwitchInSettingsTurnsTheTipsOffAndOn() {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument, UITestHooks.gestureHintsArgument])
        let gear = app.buttons["Settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: Self.uiTimeout), "no Settings on Home")
        XCTAssertTrue(tap(gear, until: app.navigationBars["Settings"], in: app), "Settings didn't open")
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song player")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "no Song player row")
        XCTAssertTrue(tap(row, until: app.navigationBars["Song player"], in: app), "Song player didn't open")

        let toggle = showHoldTips(in: app)
        XCTAssertTrue(scrollIntoView(toggle, in: app), "Show hold tips isn't in reach")
        XCTAssertEqual(toggle.value as? String, "1", "the tips aren't on by default")
        XCTAssertFalse(app.buttons["Show the tips again"].isEnabled, "nothing has been put away to bring back")
        attach(app, named: "settings-song-player-hold-tips")
        flip(toggle, to: "0")

        app.navigationBars["Song player"].buttons.firstMatch.tap()
        app.navigationBars["Settings"].buttons.firstMatch.tap()
        openSeededSong(in: app)
        let tip = app.staticTexts[loopTip]
        XCTAssertFalse(tip.waitForExistence(timeout: 5), "a tip showed with the tips turned off")

        // On again, from where the player is: holding Loop controls opens the same screen as a sheet.
        app.buttons["Loop controls"].press(forDuration: 1.0)
        let sheet = app.navigationBars["Song player"]
        XCTAssertTrue(sheet.waitForExistence(timeout: Self.uiTimeout), "holding Loop controls didn't open it")
        // It opens at the medium detent, and a `Form` draws only the rows it shows. A swipe on the sheet's
        // title bar left it at medium (seen 2026-10-03); a drag that starts in its rows grows it, then scrolls.
        let again = showHoldTips(in: app)
        var drags = 0
        while !again.waitForExistence(timeout: 1), drags < 3 {
            sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 4))
                .press(forDuration: 0.05,
                       thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -4)))
            drags += 1
        }
        XCTAssertTrue(again.waitForExistence(timeout: Self.uiTimeout), "Show hold tips isn't in the sheet")
        XCTAssertTrue(scrollIntoView(again, in: app), "Show hold tips isn't in reach in the sheet")
        flip(again, to: "1")
        sheet.buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet), "Done didn't close the sheet")
        XCTAssertTrue(tip.waitForExistence(timeout: Self.uiTimeout), "turned back on, the tip didn't show")
    }

    // MARK: - The way in

    /// Any tip, found by the ✕ every tip carries. Not by the tag's own identifier: a SwiftUI container's
    /// identifier didn't surface in the tree (2026-10-03), which made every "no tip" check pass on nothing.
    /// Each test that asserts there's no tip has first found one this way.
    @MainActor
    private func anyTip(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Close this tip"]
    }

    /// The switch's label carries its ⓘ, so it is matched on how it starts.
    @MainActor
    private func showHoldTips(in app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Show hold tips")).firstMatch
    }

    /// Tap the switch itself, at the row's trailing end: the middle of the row is its label and ⓘ.
    @MainActor
    private func flip(_ toggle: XCUIElement, to value: String, file: StaticString = #filePath, line: UInt = #line) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let flipped = NSPredicate(format: "value == %@", value)
        let wait = XCTNSPredicateExpectation(predicate: flipped, object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: Self.uiTimeout), .completed,
                       "Show hold tips didn't turn \(value == "1" ? "on" : "off")", file: file, line: line)
    }

    /// Launched for the tips, then the seeded song, idle.
    @MainActor
    private func openSeededSong(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(extraArguments: [UITestHooks.namingPieceArgument, UITestHooks.gestureHintsArgument],
                            file: file, line: line)
        openSeededSong(in: app, file: file, line: line)
        return app
    }

    /// Home ▸ Song library ▸ the seeded song, idle.
    @MainActor
    private func openSeededSong(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout), "no Song library on Home",
                      file: file, line: line)
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "the library didn't open",
                      file: file, line: line)

        let song = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Naming test")).firstMatch
        // A simulator that has run the shoot holds more songs, and the list draws only the rows on
        // screen: on CI's clean one the song is in view, on a used one it is a few swipes down.
        var swipes = 0
        while !song.waitForExistence(timeout: 2), swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(song.waitForExistence(timeout: Self.uiTimeout), "the seeded song isn't in the library",
                      file: file, line: line)
        // `tap(_:until:)`, not a bare tap: on a simulator's first launch the library can take the touch
        // and stay put (seen here, 2026-10-03). The player's back button is drawn before its audio loads.
        let back = app.buttons["Back to library"]
        _ = tap(song, until: back, in: app)
        XCTAssertTrue(back.waitForExistence(timeout: playerTimeout),
                      "the song player never opened", file: file, line: line)
        XCTAssertTrue(app.buttons["Play Verse riff"].waitForExistence(timeout: Self.uiTimeout),
                      "no Verse riff row", file: file, line: line)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
