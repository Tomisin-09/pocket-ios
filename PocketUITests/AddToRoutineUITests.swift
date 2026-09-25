import XCTest

/// **Add to routine…** from a drill's hold menu (ADR 0222) — the wiring a unit test cannot reach:
/// that the hold menu carries the entry, that the entry presents the sheet, and that a tap on a
/// routine adds a block the sheet can see and a second tap takes it back.
///
/// Which block a pick makes, where it lands and that a fresh context reads it are pinned in
/// `AddToRoutineTests`; nothing here re-asserts them.
///
/// **Every assertion is a delta, and the test leaves the store as it found it.** The simulator keeps
/// the app's store between runs, so the seeded routine's block count is whatever earlier runs left:
/// the test reads it, asserts it went up by one, then takes the block back out and asserts it is
/// back where it started.
///
/// The hold menu is a context menu from `press(forDuration:)`, which resolves on CI's toolchain
/// (`RowUndoUITests`); a toolbar `Menu` would not, which is why nothing here goes near one.
final class AddToRoutineUITests: UITestCase {

    /// A seeded drill (`PracticePresets.firstRunSlugs`) whose name collides with no section header.
    private static let seededDrill = "Alternate Picking"
    /// The seeded starter routine (`RoutinePresets`).
    private static let seededRoutine = "Morning Routine"

    @MainActor
    func testHoldingADrillAddsItToARoutineAndASecondTapTakesItBack() throws {
        let app = launchApp()
        try openExercisesLibrary(in: app)

        let drill = app.cells.containing(.staticText, identifier: Self.seededDrill).firstMatch
        XCTAssertTrue(drill.waitForExistence(timeout: Self.uiTimeout), "no seeded drill to hold")
        scrollIntoView(drill, in: app)
        drill.press(forDuration: 1.2)

        let entry = app.buttons["Add to routine…"]
        XCTAssertTrue(entry.waitForExistence(timeout: Self.uiTimeout),
                      "the drill's hold menu offered no Add to routine…")
        entry.tap()
        XCTAssertTrue(app.navigationBars["Add to routine"].waitForExistence(timeout: Self.uiTimeout),
                      "Add to routine… presented no sheet")

        let routine = app.buttons[Self.seededRoutine]
        XCTAssertTrue(routine.waitForExistence(timeout: Self.uiTimeout), "no seeded routine to add to")
        let before = try XCTUnwrap(routine.value as? String)
        attach(app, named: "Add to routine — before")

        routine.tap()
        XCTAssertTrue(waitFor(routine, NSPredicate(format: "value BEGINSWITH %@", "Added, ")),
                      "the tapped routine never read as Added")
        let after = try XCTUnwrap(routine.value as? String)
        XCTAssertEqual(try blocks(in: after), try blocks(in: before) + 1,
                       "the routine's block count did not go up by one: \(before) → \(after)")
        attach(app, named: "Add to routine — added")

        // The take-back: the same routine, tapped again, is exactly where it started.
        routine.tap()
        XCTAssertTrue(waitFor(routine, NSPredicate(format: "value == %@", before)),
                      "a second tap did not take the block back out: now \(routine.value ?? "nil")")

        app.buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.navigationBars["Add to routine"]),
                      "Done did not close the sheet")
    }

    // MARK: - Helpers

    /// The leading count in "5 blocks · 1 rest", after an optional "Added, ".
    private func blocks(in value: String) throws -> Int {
        let trimmed = value.hasPrefix("Added, ") ? String(value.dropFirst("Added, ".count)) : value
        let digits = trimmed.prefix { $0.isNumber }
        return try XCTUnwrap(Int(digits), "no block count at the start of “\(value)”")
    }

    /// A format predicate, not a block: a block reading `XCUIElement.value` runs off the main actor,
    /// which CI's Swift 6 toolchain rejects (`waitForLabel` is the precedent).
    @MainActor
    private func waitFor(_ element: XCUIElement, _ predicate: NSPredicate) -> Bool {
        let settled = expectation(for: predicate, evaluatedWith: element)
        return XCTWaiter().wait(for: [settled], timeout: Self.uiTimeout) == .completed
    }

    @MainActor
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Home → Practice → Exercises.
    @MainActor
    private func openExercisesLibrary(in app: XCUIApplication) throws {
        let practiceCard = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practiceCard.waitForExistence(timeout: Self.uiTimeout), "Practice card missing")
        XCTAssertTrue(scrollIntoView(practiceCard, in: app), "Practice card not reachable by scrolling")
        practiceCard.tap()

        let exercisesRow = app.cells.containing(.staticText, identifier: "Exercises").firstMatch
        XCTAssertTrue(exercisesRow.waitForExistence(timeout: Self.uiTimeout), "Exercises library row missing")
        exercisesRow.tap()
    }
}
