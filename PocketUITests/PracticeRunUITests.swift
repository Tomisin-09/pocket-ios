import XCTest

/// Regression guard for the "tapping a unit freezes" bug (ADR 0046 Phase B): a SwiftData optional
/// `!= nil` `@Query` predicate in `PracticeView` churned the context and starved the main thread,
/// so navigating into a run screen (exercises included) stalled. This drives Home → Practice →
/// first exercise and asserts the run screen actually appears.
///
/// Every wait below is `Self.uiTimeout` because `launchApp()` has already established that seeding
/// finished (ADR 0146 pass 2). They used to be 20s each — not because a screen transition takes 20
/// seconds, but because each one was independently guessing at how long seeding might still be
/// running. This is the test that failed on `main` for exactly that reason.
final class PracticeRunUITests: UITestCase {

    @MainActor
    func testTappingExerciseOpensRunScreen() throws {
        let app = launchApp()

        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        // Home groups its strips into titled sections (ADR 0102); Practice heads the first section, so
        // it's normally above the fold — but scroll it into view before tapping rather than assuming a
        // fixed position.
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()

        // Practice is a hub (ADR 0046): open the Exercises library first.
        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: Self.uiTimeout),
                      "Exercises library row missing")
        exercisesRow.tap()

        // Tapping a seeded unit must open its run screen without the freeze. Target **Alternate
        // Picking**: it's in `PracticePresets.firstRunSlugs`, so a genuinely clean install has it
        // (ADR 0112 cut seeding to six drills — this test used to tap "Chord Changes", which a fresh
        // install no longer seeds), and its name collides with no section header, unlike "Legato",
        // which is both a drill and its own template section.
        let drillCell = app.cells.containing(.staticText, identifier: "Alternate Picking").firstMatch
        XCTAssertTrue(drillCell.waitForExistence(timeout: Self.uiTimeout), "no seeded exercise to tap")
        scrollIntoView(drillCell, in: app)
        drillCell.tap()

        let start = app.buttons["Start training routine"]
        XCTAssertTrue(start.waitForExistence(timeout: Self.uiTimeout),
                      "run screen did not appear (freeze regression)")
    }
}
