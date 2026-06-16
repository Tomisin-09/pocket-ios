import XCTest

final class PocketLaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        // The app currently launches into the waveform practice screen
        // (temporary until navigation lands — see PocketApp). Assert a stable
        // control on it: the transport's play button.
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
    }
}
