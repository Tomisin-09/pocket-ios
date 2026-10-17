import XCTest

/// **The free path** (ADR 0256 D2, D3, D9), the one UI test that runs without Red Moon's plan.
///
/// Every other test launches on Pay once, because the suite tests features, not the gate. That was
/// 0237's complaint about the old gates: `-uiTesting` forced them open, so the locked branch a
/// player actually met was the one no test ever ran. This test runs it. The rules behind it (which
/// purchases open what) are `PlanAccessTests`. What only a driven run can show is that the gates sit
/// on the right screens: the free doors open, and the gated ones draw a lock and then the wall.
///
/// It asserts on doors, not on the starter track's card, so it holds on a simulator whose store
/// already has songs in it.
final class PlanWallUITests: UITestCase {

    @MainActor
    func testFreeDoorsOpenAndGatedDoorsShowTheWall() {
        let app = launchApp(extraArguments: [UITestHooks.planArgument, UITestHooks.planFree])
        let wall = app.staticTexts[UITestHooks.planWallHeadline]

        // Gated, and saying so before the tap: Practice draws its lock, then the wall in place of the hub.
        let practice = app.buttons["Practice, your exercises and training runs"]
        XCTAssertTrue(practice.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(practice.value as? String, "Needs the plan", "Practice drew no lock without the plan")
        XCTAssertTrue(tap(practice, until: wall, in: app), "Practice opened without the plan")
        XCTAssertFalse(app.buttons["New exercise"].exists, "The hub was built behind the wall")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Free: the Song library opens to the library, with no wall and no lock.
        let library = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Song library,'")).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertNotEqual(library.value as? String, "Needs the plan", "The Song library drew a lock")
        XCTAssertTrue(tap(library, until: app.navigationBars["Library"], in: app), "The Song library didn't open")
        XCTAssertFalse(wall.exists, "The Song library showed the wall")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Gated: the Journal.
        let journal = app.buttons["Journal, your notes and practice takes"]
        XCTAssertTrue(tap(journal, until: wall, in: app), "The Journal opened without the plan")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // The Toolkit holds both sides of the line in one list: the Tuner is free and My chords is not.
        let toolkit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Toolkit,'")).firstMatch
        XCTAssertTrue(tap(toolkit, until: app.navigationBars["Toolkit"], in: app), "The Toolkit didn't open")
        let myChords = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'My chords,'")).firstMatch
        XCTAssertTrue(myChords.waitForExistence(timeout: Self.uiTimeout))
        XCTAssertEqual(myChords.value as? String, "Needs the plan", "My chords drew no lock without the plan")
        // Not opened: the Tuner asks for the microphone, and the prompt would outlive this test.
        let tuner = app.buttons["Tuner, tune by ear or mic"]
        XCTAssertNotEqual(tuner.value as? String, "Needs the plan", "The Tuner drew a lock")
        let glossary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Glossary,'")).firstMatch
        XCTAssertTrue(tap(glossary, until: app.navigationBars["Glossary"], in: app), "The Glossary didn't open")
        XCTAssertFalse(wall.exists, "The Glossary showed the wall")
    }
}
