import XCTest

/// Smoke coverage for the **Red Moon Oracle** (ADR 0187 S1) — Home → Learn → a reading.
///
/// The unit suite owns every rule in this feature: D6's seven builder rules, D12's tone guard,
/// D13's two matchers and D15's cadence are all pure and tested there. What it cannot reach is the
/// wiring — that the Learn section exists, that the card opens the screen, and that the screen puts
/// something on it. That is all this asserts.
///
/// ### The gate is made deterministic at the composition root, not worked around here
///
/// The simulator keeps its data store *and its `UserDefaults`* between runs, so
/// `oracle.lastReadingDate` survives from one execution to the next: the second run of a suite
/// finds the week already spent and the screen showing a persisted reading instead of the button.
/// An earlier draft of this test hedged — *assert whichever side of the gate we land on* — which
/// tests almost nothing and would have gone green with the draw path completely broken.
///
/// `PocketApp.init` clears the reading log under `-uiTesting`, beside the Journal filters and for
/// the identical reason (ADR 0190 D8's note). So this test can assert the **whole** path: the card,
/// the screen, the week it names, the button, and a reading with prose in it.
///
/// ### The door has to be asked for now (ADR 0211)
///
/// The Oracle is shelved: its tile is drawn hidden on Home, so a player cannot reach any of this.
/// The feature itself was not touched — which is exactly why this suite is kept rather than deleted,
/// and why it launches with `-oracleDoor`. A shelved feature whose tests still run is a feature that
/// can come back; one whose tests were deleted with its door is a rewrite.
///
/// ⚠ **A pass here is only meaningful if this class actually ran.** `-only-testing:` a class that
/// executes nothing exits 0, and the shape of this change — a suite that now depends on a launch
/// argument to find its first element — is precisely the shape that goes quietly green by running
/// zero tests. Read the count, not the exit status.
final class OracleUITests: UITestCase {

    @MainActor
    func testTheOracleOpensFromTheLearnSectionAndSaysWhereItIsInTheWeek() throws {
        let app = launchApp(extraArguments: [UITestHooks.oracleDoorArgument])

        // Matched by label prefix, like the Toolkit card beside it: the subtitle is copy and copy
        // moves. The name does not.
        let oracleCard = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Red Moon Oracle,")).firstMatch
        XCTAssertTrue(oracleCard.waitForExistence(timeout: Self.uiTimeout), """
            Oracle card missing on Home. Since ADR 0211 the tile is hidden unless the launch \
            carries \(UITestHooks.oracleDoorArgument) as well as \(UITestHooks.launchArgument) — \
            check the door before looking at the card.
            """)
        XCTAssertTrue(scrollIntoView(oracleCard, in: app), "Oracle card not reachable by scrolling")
        oracleCard.tap()

        XCTAssertTrue(app.navigationBars["Red Moon Oracle"].waitForExistence(timeout: Self.uiTimeout),
                      "Oracle screen did not appear")

        // The week it is about, always stated — "The week of 25 Aug to 31 Aug".
        let windowLabel = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "The week of")).firstMatch
        XCTAssertTrue(windowLabel.waitForExistence(timeout: Self.uiTimeout),
                      "The screen did not say which week it is reading")

        // The gate is open — the launch clears the log — so the draw path is asserted, not hedged.
        let drawButton = app.buttons["Read the week"]
        XCTAssertTrue(drawButton.waitForExistence(timeout: Self.uiTimeout),
                      "No reading offered on a cleared log; the cadence gate is stuck shut")
        drawButton.tap()

        // Drawing one must put prose on the screen and say where the words came from. In S1 that is
        // always the device — there is no proxy address in any build until S4.
        let source = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Written on your phone")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: Self.uiTimeout),
                      "The reading did not appear, or did not say it was written locally")

        // D15's other half: having spent the week, the screen must name the date the next one opens
        // rather than simply going quiet.
        let nextReading = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Your next reading opens on")).firstMatch
        XCTAssertTrue(nextReading.exists,
                      "A spent week must state when the next reading opens, not just refuse")
    }
}
