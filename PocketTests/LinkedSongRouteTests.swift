import SwiftData
import XCTest
@testable import Pocket

/// The stage-then-push stepping behind a linked song row (ADR 0172). Pure and view-free: the whole
/// point of the type is that the ordering rule — nothing is pushed until the sheet has *finished*
/// dismissing — is testable without a sheet.
final class LinkedSongRouteTests: XCTestCase {

    /// `Song` is a `@Model`, but the route never touches the store — so these stay **uninserted**,
    /// which is both sufficient and the way round the XCTest-host insert traps.
    private func makeSong(_ title: String) -> Song {
        Song(title: title, duration: 180,
             ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    func testStagingDoesNotOpenAnything() {
        var route = LinkedSongRoute()
        route.stage(makeSong("Little Wing"))

        XCTAssertNil(route.opening, "nothing may push while the sheet is still on screen")
    }

    func testPromoteAfterTheSheetLeavesOpensTheStagedSong() {
        let song = makeSong("Little Wing")
        var route = LinkedSongRoute()

        route.stage(song)
        route.promote()

        XCTAssertIdentical(route.opening, song)
        XCTAssertNil(route.pending, "the staging slot is emptied once it has been handed over")
    }

    /// The sheet is dismissed far more often by Done or a swipe than by a song tap. Those
    /// dismissals must not navigate anywhere.
    func testPromoteWithNothingStagedIsANoOp() {
        var route = LinkedSongRoute()
        route.promote()

        XCTAssertNil(route.opening)
        XCTAssertNil(route.pending)
    }

    /// A second dismissal — the player being popped, then the sheet opened and closed again —
    /// must not re-open the song that was already visited.
    func testPromoteDoesNotRepeatAPreviousSong() {
        let song = makeSong("Little Wing")
        var route = LinkedSongRoute()

        route.stage(song)
        route.promote()
        route.clear()
        route.promote()

        XCTAssertNil(route.opening, "an ordinary dismissal after a visit must not push again")
    }

    func testClearEndsThePush() {
        var route = LinkedSongRoute()
        route.stage(makeSong("Little Wing"))
        route.promote()

        route.clear()

        XCTAssertNil(route.opening)
    }

    /// Staging twice before the sheet leaves keeps the last tap, not the first.
    func testTheLastTapWins() {
        let first = makeSong("Little Wing")
        let second = makeSong("Voodoo Child")
        var route = LinkedSongRoute()

        route.stage(first)
        route.stage(second)
        route.promote()

        XCTAssertIdentical(route.opening, second)
    }
}
