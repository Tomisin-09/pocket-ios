import XCTest

/// Getting to the Journal and through its ＋ menu, shared by `JournalNewMenuUITests` and
/// `SaveFailedUITests`.
extension UITestCase {
    /// Tap a menu item until `revealed` appears — re-tapping **only while the item is still on
    /// screen**, i.e. while the menu is still open and nothing ran. Once the item has gone, the menu
    /// closed on a tap that landed, and a second tap would be aimed at whatever is underneath.
    @MainActor
    func tapItem(_ item: XCUIElement, revealing revealed: XCUIElement, attempts: Int = 3) -> Bool {
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
    func openJournal(in app: XCUIApplication) throws {
        let journalCard = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(journalCard.waitForExistence(timeout: Self.uiTimeout), "Journal card missing")
        XCTAssertTrue(scrollIntoView(journalCard, in: app), "Journal card not reachable by scrolling")
        journalCard.tap()
    }
}
