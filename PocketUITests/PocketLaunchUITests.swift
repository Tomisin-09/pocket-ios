import XCTest

final class PocketLaunchUITests: UITestCase {

    @MainActor
    func testAppLaunches() throws {
        // `launchApp()` also proves first-launch seeding completes — so this is now a smoke test of
        // the launch *and* the seeding path, and it is the test that fails first and most clearly if
        // the readiness signal itself ever breaks.
        let app = launchApp()
        // The app launches into the home hub (HomeView, ADR 0044). Assert a stable element
        // present whether or not there's any practice history yet: the greeting headline.
        XCTAssertTrue(app.staticTexts["Ready to practice?"].waitForExistence(timeout: Self.uiTimeout))
    }
}
