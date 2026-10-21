import XCTest

/// **The Add-to-routine picker keeps its search field in view once something is added** (device
/// report, 2026-10-21).
///
/// The picker used the default `.searchable` placement. On iOS 26 that puts the field at the
/// **bottom**, and the running *1 block added* tally, a bottom inset on the same stack, drew over it
/// from the first add onwards. On CI's iOS 18 the same default hid the field under the inline title
/// until the list was pulled. The fix is the libraries' placement (ADR 0178 D8, 0226 D1), so this
/// asserts both halves with **no pull-down fallback**: the field is there, and it sits above the tally.
///
/// The field is found by its **prompt**, because the Routines library behind the editor has a search
/// field of its own and stays in the tree under the sheets.
///
/// Nothing is saved: the editor works in a sandbox that only Save writes, and this never taps it.
final class AddRoutineUnitSearchUITests: UITestCase {

    /// A seeded drill (`PracticePresets.firstRunSlugs`), near the top of the flat A→Z list.
    private static let seededDrill = "Alternate Picking"

    @MainActor
    func testTheSearchFieldStaysInViewAfterABlockIsAdded() throws {
        let app = launchApp()
        let practice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Practice,")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout), "no Practice card on Home")
        XCTAssertTrue(tap(practice, until: app.navigationBars["Practice"], in: app), "Practice never opened")
        openPracticeLibrary("Routines", in: app)

        let addRow = app.buttons["Add exercise, loop or song"]
        XCTAssertTrue(tap(app.buttons["New routine"], until: addRow, in: app), "the routine editor never opened")
        XCTAssertTrue(tap(addRow, until: app.navigationBars["Add to routine"], in: app),
                      "the Add sheet never opened")

        // Add one drill, two levels down, then come back up to the root where the field lives.
        let allExercises = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All exercises,"))
            .firstMatch
        XCTAssertTrue(tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exercises,")).firstMatch,
                          until: allExercises, in: app), "the Exercises bucket never opened")
        XCTAssertTrue(tap(allExercises, until: app.navigationBars["All exercises"], in: app),
                      "the flat exercise list never opened")
        let drill = app.buttons[Self.seededDrill]
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no \(Self.seededDrill) to add")
        XCTAssertTrue(scrollIntoReach(drill, in: app), "\(Self.seededDrill) isn't reachable")
        drill.tap()
        goBack(from: "All exercises", to: "Exercises", in: app)
        goBack(from: "Exercises", to: "Add to routine", in: app)

        let tally = app.staticTexts["1 block added"]
        XCTAssertTrue(tally.waitForExistence(timeout: Self.uiTimeout), "the add never landed")
        let search = app.searchFields
            .matching(NSPredicate(format: "placeholderValue == %@", "Search exercises, loops, songs")).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: Self.uiTimeout),
                      "the picker shows no search field until it is pulled down")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Add to routine — one block added"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertLessThanOrEqual(search.frame.maxY, tally.frame.minY,
                                 "the search field (\(search.frame)) sits under the tally (\(tally.frame))")

        // Done closes the picker; the routine itself is never saved.
        app.navigationBars["Add to routine"].buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["Add to routine"]), "Done didn't close the picker")
    }

    /// Back one screen, by the leading item of the bar being **left**: named, because a screen under a
    /// pushed one leaves its bar in the tree too.
    @MainActor
    private func goBack(from leaving: String, to arriving: String, in app: XCUIApplication) {
        let bar = app.navigationBars[leaving]
        XCTAssertTrue(bar.waitForExistence(timeout: Self.uiTimeout), "not on '\(leaving)' to go back from")
        bar.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars[arriving].waitForExistence(timeout: Self.uiTimeout),
                      "left '\(leaving)' and never reached '\(arriving)'")
    }
}
