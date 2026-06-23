import XCTest

final class PocketLaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        // The app launches into the song library (LibraryView). Assert a stable
        // element present whether or not the library has songs yet: the nav title.
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
    }
}
