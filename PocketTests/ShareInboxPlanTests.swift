import XCTest
@testable import Pocket

/// **Where a save from *Save to Red Moon* lands** (ADR 0264 D9): the app decides again against the
/// store, because the snapshot the extension picked from can be out of date. Nothing is dropped.
final class ShareInboxPlanTests: XCTestCase {

    private func item(to destination: String?, file: Bool = false) -> ShareInboxItem {
        ShareInboxItem(id: UUID(), savedAt: .now, url: file ? nil : "https://example.com/a",
                       fileName: file ? "shared.pdf" : nil, destination: destination)
    }

    private let drill = ShareInboxPlan.Target(kind: .exercise, canTakeFile: true)
    private let song = ShareInboxPlan.Target(kind: .song, canTakeFile: true)
    private let fullSong = ShareInboxPlan.Target(kind: .song, canTakeFile: false)

    func testKeepForLaterStaysKeptForLater() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: nil), target: nil, standing: .onPlan), .keepForLater)
    }

    func testASaveGoesWhereThePlayerPutIt() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "song:a"), target: song, standing: .neverBought),
                       .place("song:a"))
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "exercise:b"), target: drill, standing: .onPlan),
                       .place("exercise:b"))
    }

    func testAPlaceDeletedSinceIsKeptForLater() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "song:gone"), target: nil, standing: .onPlan),
                       .keepForLater)
    }

    /// D6: a lapsed player attaches to a drill they can't open; it opens again with the plan.
    func testALapsedPlayersDrillTakesIt() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "exercise:b"), target: drill, standing: .lapsed),
                       .place("exercise:b"))
    }

    /// D6: a drill is never offered to a player who hasn't bought the plan, so a save naming one is
    /// kept for later rather than filed where they can't follow it.
    func testANeverBoughtPlayersDrillIsKeptForLater() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "exercise:b"), target: drill, standing: .neverBought),
                       .keepForLater)
        let routine = ShareInboxPlan.Target(kind: .routine, canTakeFile: true)
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "routine:c"), target: routine, standing: .neverBought),
                       .keepForLater)
    }

    /// 0167 phase 2's cap: five files a place. A link never fills one.
    func testAFullPlaceTakesALinkButNotAFile() {
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "song:a", file: true), target: fullSong, standing: .onPlan),
                       .keepForLater)
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "song:a"), target: fullSong, standing: .onPlan),
                       .place("song:a"))
        XCTAssertEqual(ShareInboxPlan.filing(for: item(to: "song:a", file: true), target: song, standing: .onPlan),
                       .place("song:a"))
    }
}
