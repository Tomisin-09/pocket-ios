import XCTest

/// Regression guard for the "tapping a unit freezes" bug (ADR 0046 Phase B): a SwiftData optional
/// `!= nil` `@Query` predicate in `PracticeView` churned the context and starved the main thread,
/// so navigating into a run screen (exercises included) stalled. This drives Home → Practice →
/// first exercise and asserts the run screen actually appears.
final class PracticeRunUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingExerciseOpensRunScreen() throws {
        let app = XCUIApplication()
        app.launch()

        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: 5), "Practice card missing")
        practiceCard.tap()

        // A seeded preset (Phase A seeds six on first launch); tap its row, not the bare text.
        let spiderCell = app.cells.containing(.staticText, identifier: "Spider Walk").firstMatch
        XCTAssertTrue(spiderCell.waitForExistence(timeout: 5), "no seeded exercise to tap")
        spiderCell.tap()

        let start = app.buttons["Start training routine"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "run screen did not appear (freeze regression)")
    }
}
