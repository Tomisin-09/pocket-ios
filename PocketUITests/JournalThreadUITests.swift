import XCTest

/// The Journal thread's doors (ADR 0286): an exercise with two notes shows a count on its rows, the count
/// opens that exercise's rows on a screen of their own, and Back returns to the feed.
///
/// Which rows a thread holds is the pure `JournalTimeline` filter, tested in `JournalTimelineUnitTests`;
/// this pins the wiring. It writes its own two notes, as `RowUndoUITests` does, since a clean install's
/// Journal is empty. The simulator keeps its store between runs, so locally the exercise may have more
/// than two rows: the test checks the count names the exercise, never what number it shows.
final class JournalThreadUITests: UITestCase {

    @MainActor
    func testACountOpensTheExercisesThreadAndBackReturns() throws {
        let app = launchApp()
        let tag = UUID().uuidString.prefix(6)
        let first = "Thread note A \(tag)"
        let second = "Thread note B \(tag)"
        try writeAJournalNote(first, in: app)
        try writeAJournalNote(second, in: app)
        try openJournalFromHome(in: app)

        let row = app.cells.containing(.staticText, identifier: second).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "the note just written isn't on the feed")
        let count = row.buttons["journal.thread.count"]
        XCTAssertTrue(count.waitForExistence(timeout: Self.uiTimeout), "an exercise with two notes shows no count")
        XCTAssertTrue(count.label.hasPrefix("Show all") && count.label.hasSuffix("for Alternate Picking"),
                      "the count reads '\(count.label)'")
        count.tap()

        let header = app.descendants(matching: .any)["journal.thread.header"]
        XCTAssertTrue(header.waitForExistence(timeout: Self.uiTimeout), "the count opened no thread")
        XCTAssertTrue(app.navigationBars["Alternate Picking"].exists, "the thread isn't titled with its exercise")
        XCTAssertTrue(app.cells.containing(.staticText, identifier: first).firstMatch.exists,
                      "the thread is missing the exercise's first note")
        XCTAssertTrue(app.cells.containing(.staticText, identifier: second).firstMatch.exists,
                      "the thread is missing the exercise's second note")
        XCTAssertTrue(app.buttons["journal.thread.open"].exists, "the thread has no Open")
        // Kept, so the thread can be looked at, not only asserted on.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "journal-thread"
        shot.lifetime = .keepAlways
        add(shot)

        app.navigationBars["Alternate Picking"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Journal"].waitForExistence(timeout: Self.uiTimeout),
                      "Back didn't return to the Journal")
        XCTAssertTrue(row.exists, "the feed came back without the row the count was on")
    }
}
