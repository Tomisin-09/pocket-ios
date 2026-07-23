import XCTest

final class PocketLaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] // suppress the first-launch profile intake covering Home
        app.launch()
        // The app launches into the home hub (HomeView, ADR 0044). Assert a stable element
        // present whether or not there's any practice history yet: the greeting headline.
        XCTAssertTrue(app.staticTexts["Ready to practice?"].waitForExistence(timeout: 5))
    }
}
