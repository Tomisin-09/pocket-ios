import XCTest

/// A routine with its songs (ADR 0236 D6), both ways, as wiring. `RoutineSongsShareTests` covers which
/// blocks keep their ids and how they bind; neither can say whether the routine's share button opens the
/// send screen, or whether a received routine's loop block plays the loop that came with it once it's in
/// the store, where SwiftData, not the test, keeps the relationships.
///
/// `-receiveRoutinePack` builds *Pack routine* at launch, a block on *Pack test*'s loop *Riff* and a block
/// playing the song, sent by *Tester*, and opens it on the receive door as a tapped file arrives.
final class RoutineSendUITests: UITestCase {

    /// The share sheet runs out of process: about two seconds on a warm simulator, longer on a cold one.
    private let shareSheetTimeout: TimeInterval = 30

    /// The preview names who sent it and the song coming with it; **Add** lands both, and the loop block
    /// reads as its loop rather than as a placeholder.
    @MainActor
    func testARoutineSentWithItsSongLandsPlayingIt() throws {
        let app = launchApp(extraArguments: [UITestHooks.receiveRoutinePackArgument])
        try receiveRoutine(in: app)
        try openReceivedRoutine(in: app)

        // A block row reads as one element, "<title>. <subtitle>": a bound loop block names its loop and
        // its song, and a placeholder says it was skipped.
        let blocks = app.descendants(matching: .any)
        let riff = blocks.matching(NSPredicate(format: "label BEGINSWITH %@", "Riff. Pack test")).firstMatch
        XCTAssertTrue(riff.waitForExistence(timeout: Self.uiTimeout),
                      "the loop block isn't bound to the loop and song that came with the routine")
        let skipped = blocks.matching(NSPredicate(format: "label CONTAINS %@", "not on this device")).firstMatch
        XCTAssertFalse(skipped.exists, "a block arrived as a placeholder")
    }

    /// A routine that plays a song opens **Send this routine** before the share sheet, with *Include the
    /// songs* on, and **Send…** opens the share sheet on the pack.
    @MainActor
    func testARoutineThatPlaysASongSendsFromItsSendScreen() throws {
        let app = launchApp(extraArguments: [UITestHooks.receiveRoutinePackArgument])
        try receiveRoutine(in: app)
        try openReceivedRoutine(in: app)

        let share = app.navigationBars.buttons["Send this routine"]
        XCTAssertTrue(share.waitForExistence(timeout: Self.uiTimeout), "the routine has no Send this routine")
        let screen = app.navigationBars["Send this routine"]
        XCTAssertTrue(tap(share, until: screen, in: app), "the send screen didn't open")
        let include = app.switches["Include the songs"]
        XCTAssertTrue(include.waitForExistence(timeout: Self.uiTimeout), "the send screen has no Include the songs")
        XCTAssertEqual(include.value as? String, "1", "Include the songs isn't on by default")

        screen.buttons["Send…"].tap()
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: shareSheetTimeout), "Send… didn't open the share sheet")
        // A file URL's sheet names it without its extension: the pack is named for the routine.
        let named = sheet.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Pack routine"))
        XCTAssertTrue(named.firstMatch.waitForExistence(timeout: Self.uiTimeout),
                      "the share sheet opened, but not on the routine's pack")
    }

    // MARK: - Steps

    /// The receive preview, then **Add**, then the confirmation.
    @MainActor
    private func receiveRoutine(in app: XCUIApplication) throws {
        let preview = app.navigationBars["Add this routine?"]
        XCTAssertTrue(preview.waitForExistence(timeout: 30), "the pack didn't open on the receive door")
        let sentBy = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sent by Tester")).firstMatch
        XCTAssertTrue(sentBy.exists, "the preview doesn't say who sent it")
        let song = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Pack test")).firstMatch
        XCTAssertTrue(song.exists, "the preview doesn't list the song coming with it")

        // Tapped until it takes: on a cold iOS 18.5 simulator a tap the moment the sheet appears lands and
        // does nothing. Once Add has gone, reading the song's audio is only slow.
        let added = app.alerts["Added"]
        XCTAssertTrue(tap(preview.buttons["Add"], until: added, in: app) || added.waitForExistence(timeout: 30),
                      "the routine never landed")
        let said = added.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "“Pack routine”")).firstMatch
        XCTAssertTrue(said.exists, "the confirmation doesn't name the routine")
        // Tapped until the alert has gone: a tap during its appear animation is dropped, and the alert
        // then sits over Home, where every card is found and none is hittable.
        for _ in 0..<3 where added.exists {
            added.buttons["OK"].tap()
            if waitForDisappearance(of: added, timeout: 3) { break }
        }
        XCTAssertFalse(added.exists, "the confirmation never closed")
    }

    /// Home → Practice → Routines → *Pack routine*.
    @MainActor
    private func openReceivedRoutine(in app: XCUIApplication) throws {
        let practice = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(scrollIntoView(practice, in: app), "the Practice card isn't reachable")
        practice.tap()

        let routines = app.cells.containing(.staticText, identifier: "Routines").firstMatch
        XCTAssertTrue(routines.waitForExistence(timeout: Self.uiTimeout), "no Routines row in Practice")
        XCTAssertTrue(tap(routines, until: app.navigationBars["Routines"], in: app), "the Routines library didn't open")

        let row = app.cells.containing(.staticText, identifier: "Pack routine").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the received routine isn't in the library")
        XCTAssertTrue(scrollIntoView(row, in: app), "the received routine isn't reachable")
        XCTAssertTrue(tap(row, until: app.navigationBars["Pack routine"], in: app), "the routine didn't open")
    }
}
