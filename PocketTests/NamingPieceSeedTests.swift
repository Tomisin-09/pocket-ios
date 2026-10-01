import XCTest
@testable import Pocket

/// The seed `NameTheNotesUITests` opens *Name the notes* on (ADR 0235, build order 4). The launch rule is
/// what keeps the rest of the suite clean: an ordinary test launch must take the seeded song back out.
final class NamingPieceSeedTests: XCTestCase {

    private let uiTesting = UITestHooks.launchArgument
    private let seed = UITestHooks.namingPieceArgument

    func testTheNamingTestAsksForItByName() {
        XCTAssertEqual(NamingPieceSeed.action(for: [uiTesting, seed]), .seed)
        XCTAssertEqual(NamingPieceSeed.action(for: ["/path/to/Pocket.app", seed, "-seedHistory", uiTesting]), .seed)
    }

    /// The case the removal is for: every other UI test, and the shoot, clean up after a naming run.
    func testEveryOtherTestLaunchTakesItOut() {
        XCTAssertEqual(NamingPieceSeed.action(for: [uiTesting]), .remove)
        XCTAssertEqual(NamingPieceSeed.action(for: [uiTesting, "-seedScreenshots", "-seedHistory",
                                                    UITestHooks.shotHourArgument, "9"]), .remove)
    }

    /// A player's launch touches nothing, and a stray argument without `-uiTesting` can't seed a song.
    func testAPlayersLaunchLeavesTheStoreAlone() {
        XCTAssertEqual(NamingPieceSeed.action(for: []), NamingPieceSeed.Action.none)
        XCTAssertEqual(NamingPieceSeed.action(for: [seed]), NamingPieceSeed.Action.none)
    }

    func testThePieceIsSixUnnamedNotesInsideTheLoop() {
        let piece = NamingPieceSeed.piece(duration: 30, start: 0.29, end: 0.47)
        XCTAssertEqual(piece.count, NamingPieceSeed.noteCount)
        XCTAssertTrue(piece.labels.allSatisfy { $0 == nil })
        XCTAssertTrue(piece.taps.allSatisfy { (8.7...14.1).contains($0.seconds) }, "\(piece.taps.map(\.seconds))")
        XCTAssertEqual(piece.taps.map(\.seconds), piece.taps.map(\.seconds).sorted())
        XCTAssertNotNil(piece.changedAt, "dated, as a saved piece is (ADR 0229)")
        XCTAssertEqual(piece.openMidi, Instrument.guitar.standardTuning.engineOpenMidi,
                       "standard guitar, whatever the tuner says, so the test's frets read the same every run")
    }
}
