import XCTest

/// The Exercises and Loops search bars are **there without a pull** (ADR 0226 D1).
///
/// Under an inline title the default `.searchable` placement opens the list scrolled past its own
/// search bar, and on CI's iOS 18 the bar is not in the accessibility tree until the list is pulled
/// down. So this test only discriminates there: on iOS 26 the default already puts the bar in the
/// tree, and the test would pass with or without the decision. That is also why, unlike
/// `RoutineLibraryUITests.searchField`, it has **no pull-down fallback** — the placement is the thing
/// under test, and a fallback would quietly pass the old behaviour.
final class LibrarySearchUITests: UITestCase {

    @MainActor
    func testExercisesAndLoopsShowTheirSearchWithoutAPull() throws {
        let app = launchApp()
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(tap(practiceCard, until: app.navigationBars["Practice"], in: app),
                      "the Practice tap never landed")

        for library in ["Exercises", "Loops"] {
            let row = app.cells.containing(.staticText, identifier: library).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: Self.uiTimeout), "\(library) library row missing")
            XCTAssertTrue(tap(row, until: app.navigationBars[library], in: app),
                          "the \(library) tap never landed")

            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: Self.uiTimeout),
                          "the \(library) library shows no search field until it is pulled down")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "\(library) library"
            shot.lifetime = .keepAlways
            add(shot)

            app.navigationBars[library].buttons["Practice"].tap()
            XCTAssertTrue(app.navigationBars["Practice"].waitForExistence(timeout: Self.uiTimeout),
                          "back from \(library) did not return to Practice")
        }
    }
}
