import XCTest

/// **The Journal's ＋ holds both doors** (ADR 0224) — *Write a note* and *Record a take*.
///
/// What this pins is the wiring no unit test can reach: that the menu offers both, that each opens its
/// own sheet, and that the take sheet can be left without recording. The record control itself is
/// **not tapped** — the first tap raises the system microphone prompt, which a UI test cannot answer
/// reliably, and what the take is filed against is `RecordingOwner.standalone`, covered in
/// `RecordingTests`.
///
/// The ＋ is a toolbar `Menu`, which CI's iOS 18 reports as never hittable, so it is tapped by
/// coordinate. A tap on one of its **items** was swallowed once locally (the menu stayed open, nothing
/// ran; the same tap passed first time on the next run), so an item is re-tapped while the menu is
/// still showing it — `tapItem`. Neither can turn a dead control green: every tap is followed by an
/// assertion that the menu or sheet it should open actually opened.
final class JournalNewMenuUITests: UITestCase {

    @MainActor
    func testThePlusOffersANoteAndATake() throws {
        let app = launchApp()
        try openJournal(in: app)

        let plus = app.navigationBars.buttons["Add to Journal"]
        XCTAssertTrue(plus.waitForExistence(timeout: Self.uiTimeout), "no ＋ on the Journal")
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let record = app.buttons["Record a take"]
        XCTAssertTrue(record.waitForExistence(timeout: Self.uiTimeout), "the ＋ offered no Record a take")
        XCTAssertTrue(app.buttons["Write a note"].exists, "the ＋ offered no Write a note")

        let start = app.buttons["Start recording"]
        XCTAssertTrue(tapItem(record, revealing: start), "Record a take opened no record sheet")
        let done = app.navigationBars["Record a take"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: Self.uiTimeout), "the record sheet has no Done")
        done.tap()
        XCTAssertTrue(waitForDisappearance(of: start), "Done left the record sheet up")

        plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let write = app.buttons["Write a note"]
        XCTAssertTrue(write.waitForExistence(timeout: Self.uiTimeout), "the ＋ offered no Write a note")
        // The composer's title rather than its field: `TextField(axis: .vertical)` is a text field on
        // some runtimes and a text view on others, and the title is one element on all of them.
        XCTAssertTrue(tapItem(write, revealing: app.navigationBars["Quick note"]),
                      "Write a note opened no composer")
    }

    /// Tap a menu item until `revealed` appears — re-tapping **only while the item is still on
    /// screen**, i.e. while the menu is still open and nothing ran. Once the item has gone, the menu
    /// closed on a tap that landed, and a second tap would be aimed at whatever is underneath.
    @MainActor
    private func tapItem(_ item: XCUIElement, revealing revealed: XCUIElement, attempts: Int = 3) -> Bool {
        for attempt in 1...attempts {
            item.tap()
            let patience: TimeInterval = attempt == attempts ? Self.uiTimeout : 3
            if revealed.waitForExistence(timeout: patience) { return true }
            guard item.exists else { return false }
        }
        return false
    }

    /// Home → Journal.
    @MainActor
    private func openJournal(in app: XCUIApplication) throws {
        let journalCard = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journalCard.waitForExistence(timeout: Self.uiTimeout), "Journal card missing")
        XCTAssertTrue(scrollIntoView(journalCard, in: app), "Journal card not reachable by scrolling")
        journalCard.tap()
    }
}
