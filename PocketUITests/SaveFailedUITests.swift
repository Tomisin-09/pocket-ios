import XCTest

/// **Couldn’t save** (ADR 0318), on a real sheet: a quick note whose save fails keeps the sheet open and
/// says so, and *Try again* saves it and closes the sheet, with the note written once.
///
/// The failure is `-failSaveIn`, which fails the first save made from the named file in a Debug build
/// under `-uiTesting` (`SaveFailureDrill`). The quick note is the door because it's the shortest way to a
/// sheet that saves on its own Save: Home, Journal, ＋, *Write a note*.
final class SaveFailedUITests: UITestCase {

    @MainActor
    func testAFailedSaveKeepsTheSheetOpenAndTryAgainSavesItOnce() throws {
        let app = launchApp(extraArguments: [UITestHooks.failSaveInArgument, "Pocket/QuickJournalSheet.swift"])
        try openJournal(in: app)

        let plus = app.navigationBars.buttons["Add to Journal"]
        XCTAssertTrue(plus.waitForExistence(timeout: Self.uiTimeout), "no ＋ on the Journal")
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let write = app.buttons["Write a note"]
        XCTAssertTrue(write.waitForExistence(timeout: Self.uiTimeout), "the ＋ offered no Write a note")
        let sheet = app.navigationBars["Quick note"]
        XCTAssertTrue(tapItem(write, revealing: sheet), "Write a note opened no composer")

        // The sheet opens with the caret in the field (`QuickJournalSheet.noteField`).
        let words = "Slower on the turnaround \(Int.random(in: 1000...9999))"
        app.typeText(words)
        sheet.buttons["Save"].tap()

        let alert = app.alerts["Couldn’t save"]
        XCTAssertTrue(alert.waitForExistence(timeout: Self.uiTimeout), "a failed save said nothing")
        XCTAssertTrue(sheet.exists, "the sheet closed on a note that wasn't saved")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "couldnt-save"
        shot.lifetime = .keepAlways
        add(shot)

        alert.buttons["Try again"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet), "Try again saved nothing, or left the sheet up")
        XCTAssertFalse(alert.exists, "the alert came back after a save that worked")

        let written = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", words))
        XCTAssertTrue(written.firstMatch.waitForExistence(timeout: Self.uiTimeout), "the note isn't in the Journal")
        XCTAssertEqual(written.count, 1,
                       "the note was written more than once: \(written.allElementsBoundByIndex.map(\.label))")
    }
}
