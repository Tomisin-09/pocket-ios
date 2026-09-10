import XCTest
@testable import Pocket

/// `-oracleDoor`, the launch argument that puts the **Red Moon Oracle**'s tile back on Home
/// (ADR 0211).
///
/// The Oracle is shelved with its door closed rather than its code deleted: the screen and its
/// guards still ship, and `OracleUITests` still walks them, through this argument. Everything that
/// matters here is *what does not open it* — so the tests below are mostly refusals, and the one
/// worth the file is `testTheShootsOwnArgumentsDoNotOpenIt`.
final class OracleDoorArgumentTests: XCTestCase {

    private let uiTesting = UITestHooks.launchArgument
    private let oracleDoor = UITestHooks.oracleDoorArgument

    // MARK: - Opened

    func testOpensWhenBothArgumentsArePresent() {
        XCTAssertTrue(UITestRuntime.parseOracleDoor(in: [uiTesting, oracleDoor]))
    }

    func testIgnoresSurroundingArgumentsAndOrder() {
        let arguments = ["/path/to/Pocket.app", oracleDoor, "-seedHistory", uiTesting]
        XCTAssertTrue(UITestRuntime.parseOracleDoor(in: arguments))
    }

    // MARK: - Refused

    /// A player's build is the case this whole seam exists to keep closed.
    func testClosedWithNoArgumentsAtAll() {
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: []))
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: ["/path/to/Pocket.app"]))
    }

    /// The same rule `-shotHour` follows: a stray argument on a shipped build must not be able to
    /// surface a feature that was deliberately put away.
    func testRequiresUITestingToo() {
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: [oracleDoor]))
    }

    func testUITestingAloneIsNotEnough() {
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: [uiTesting]))
    }

    /// **The assertion this file is for.** The manual's shoot runs under `-uiTesting`, so a door
    /// gated on the test flag alone would put the Oracle's tile into `reference/home` and
    /// `getting-started/home` — figures showing a destination no released build has. That defect
    /// lives entirely in the pixels: `check-manual.py` validates markers and quoted copy and has no
    /// opinion about what is inside a PNG, and every test in the suite would still pass.
    func testTheShootsOwnArgumentsDoNotOpenIt() {
        let shoot = [UITestHooks.launchArgument, "-seedScreenshots", "-seedHistory",
                     UITestHooks.shotHourArgument, "9"]
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: shoot), """
            the shoot's launch arguments opened the Oracle's door. Home's figures would then show a \
            tile the release build does not have, and nothing outside somebody's eyes would catch it.
            """)
    }

    /// The two arguments are separate strings, not a prefix match — `-oracleDoorSomething` is not
    /// this flag, and neither is a substring of it.
    func testMatchesTheWholeArgument() {
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: [uiTesting, "-oracleDoorOpen"]))
        XCTAssertFalse(UITestRuntime.parseOracleDoor(in: [uiTesting, "oracleDoor"]))
    }
}
