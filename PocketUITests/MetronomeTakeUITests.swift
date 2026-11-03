import XCTest

/// **The metronome's take arm sits beside Start, and only while the click is stopped** (ADR 0287 D2).
///
/// The take itself is not recorded here. The first arm raises the system microphone prompt, which a
/// UI test cannot answer, and the simulator has no real microphone, so a take is a device check. What
/// this pins is the grammar around it: the arm is offered before the click, is gone while the click
/// runs (arming then would flip the audio session under it), and is back once it stops. It also checks
/// that **Start ramp** still starts the click, now that it goes through the screen's own start rather
/// than the engine's.
final class MetronomeTakeUITests: UITestCase {

    @MainActor
    private func openMetronome(in app: XCUIApplication) {
        let card = app.buttons["Metronome, standalone click and tempo trainer"]
        XCTAssertTrue(card.waitForExistence(timeout: Self.uiTimeout), "no Metronome tile on Home")
        XCTAssertTrue(scrollIntoView(card, in: app), "Metronome tile not reachable by scrolling")
        card.tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: Self.uiTimeout),
                      "the metronome did not open")
    }

    @MainActor
    func testTheArmIsOfferedOnlyWhileTheClickIsStopped() {
        let app = launchApp()
        openMetronome(in: app)

        let arm = app.buttons["Record this session"]
        XCTAssertTrue(arm.waitForExistence(timeout: Self.uiTimeout), "no take arm beside Start")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "metronome-take-arm"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: Self.uiTimeout), "Start did not start")
        XCTAssertTrue(waitForDisappearance(of: arm), "the arm stayed while the click ran")

        app.buttons["Stop and reset"].tap()
        XCTAssertTrue(arm.waitForExistence(timeout: Self.uiTimeout), "the arm did not come back after Stop")
    }

    @MainActor
    func testStartRampStillStartsTheClick() {
        let app = launchApp()
        openMetronome(in: app)

        app.buttons["By Bars"].tap()
        let ramp = app.buttons["Start ramp"]
        XCTAssertTrue(ramp.waitForExistence(timeout: Self.uiTimeout), "the automator did not arm")
        XCTAssertTrue(scrollIntoView(ramp, in: app), "Start ramp not reachable by scrolling")
        ramp.tap()

        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: Self.uiTimeout),
                      "Start ramp did not start the click")
        XCTAssertTrue(app.buttons["Stop ramp"].exists, "the ramp did not start with the click")
        app.buttons["Stop and reset"].tap()
    }
}
