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

        // Practice is a hub (ADR 0046): open the Exercises library first.
        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: 5), "Exercises library row missing")
        exercisesRow.tap()

        // Tapping a seeded unit must open its run screen without the freeze. The library groups
        // into template sections (ADR 0068), so target a drill in the first alphabetical section
        // ("Chords" → "Chord Changes") — it's at the top of the list, on-screen without scrolling,
        // and its row (not a section header) is the tappable NavigationLink.
        // Generous timeout to match the run-screen wait below: on a cold install the library only
        // paints once first-launch seeding (exercises + routine presets) has run, which is variable.
        let drillCell = app.cells.containing(.staticText, identifier: "Chord Changes").firstMatch
        XCTAssertTrue(drillCell.waitForExistence(timeout: 20), "no seeded exercise to tap")
        drillCell.tap()

        // Generous timeout: a cold simulator seeds + spins up the run engine on first navigation.
        let start = app.buttons["Start training routine"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "run screen did not appear (freeze regression)")
    }
}
