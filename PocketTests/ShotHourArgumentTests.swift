import XCTest
@testable import Pocket

/// `-shotHour`, the launch argument that lets the user manual's shoot name the hour Home's greeting
/// is computed from (ADR 0165 Phase 5).
///
/// Parsing launch arguments is normally untestable — they are fixed for the life of the process —
/// which is why `UITestRuntime.parseShotHour(in:)` takes the array instead of reading
/// `CommandLine.arguments` directly. It is worth the seam: this argument's failure mode is a figure
/// that looks right and says the wrong time of day, and the run stays green either way.
final class ShotHourArgumentTests: XCTestCase {

    private let uiTesting = UITestHooks.launchArgument
    private let shotHour = UITestHooks.shotHourArgument

    // MARK: - Accepted

    func testReadsTheHourAfterTheFlag() {
        XCTAssertEqual(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "19"]), 19)
    }

    func testAcceptsBothEndsOfTheClock() {
        XCTAssertEqual(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "0"]), 0)
        XCTAssertEqual(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "23"]), 23)
    }

    func testIgnoresSurroundingArguments() {
        let arguments = ["/path/to/Pocket.app", uiTesting, "-seedScreenshots",
                         shotHour, "9", "-seedHistory"]
        XCTAssertEqual(UITestRuntime.parseShotHour(in: arguments), 9)
    }

    // MARK: - Refused

    /// The override changes what the app displays, so it stays behind the flag that already means
    /// "a test is driving this" rather than being reachable on a build a player is holding.
    func testRequiresUITestingToo() {
        XCTAssertNil(UITestRuntime.parseShotHour(in: [shotHour, "19"]))
    }

    func testNilWhenAbsent() {
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, "-seedHistory"]))
        XCTAssertNil(UITestRuntime.parseShotHour(in: []))
    }

    /// Every malformed case returns `nil` and falls back to the real clock, rather than defaulting
    /// to an hour. A shoot that asked for 19:00 and silently got 09:00 photographs a wrong figure
    /// that looks entirely right; falling back reproduces the clock/status-bar disagreement the
    /// harness already knows how to catch by eye.
    func testRefusesMalformedValues() {
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour]),
                     "flag with nothing after it")
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "evening"]))
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "9.5"]))
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, ""]))
    }

    /// Out of range is refused rather than folded. `HomeFeed.TimeOfDay.at(hour:)` deliberately wraps
    /// so a stray value still buckets sanely, but that leniency is for the *app*; here a 25 means
    /// the shoot asked for something impossible and should get the real clock and a visible
    /// disagreement, not a quiet 1am.
    func testRefusesHoursOutsideTheClock() {
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "24"]))
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "-1"]))
        XCTAssertNil(UITestRuntime.parseShotHour(in: [uiTesting, shotHour, "99"]))
    }

    // MARK: - The hour the shoot actually uses

    /// The default is 9 because `shoot-manual.sh` overrides the status bar to 09:41. If either
    /// moves, the frame contains two clocks that disagree — so they are pinned together here.
    func testDefaultShotHourIsMorningAndMatchesTheFakedStatusBar() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 9), .morning)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 9).greeting, "Good morning")
    }

    /// `getting-started/home` asks for an evening greeting, which is the figure the retired
    /// 05:00–11:59 wall-clock gate made unshootable at any time of day.
    func testEveningFigureGetsAnEveningGreeting() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 19), .evening)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 19).greeting, "Good evening")
    }
}
