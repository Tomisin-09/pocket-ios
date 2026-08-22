import XCTest
@testable import Pocket

/// Which take a routine block's Done screen offers (ADR 0179) — the pure half of the "did *this* run
/// record something?" question, checkable without a store.
///
/// The rule that matters is the **cutoff**. A unit practised before already holds takes, so the naive
/// "newest take" answer is a recording from some earlier day — offered on a completion beat, it tells
/// the player they just captured something they captured last week, and they have no way to know
/// otherwise. Every test here is really about that one failure.
final class RoutineTakeLookupTests: XCTestCase {

    /// A take, `seconds` after (or before, if negative) `reference`.
    private func take(_ seconds: TimeInterval, from reference: Date) -> Recording {
        Recording(fileName: "t\(seconds).m4a", duration: 5, createdAt: reference.addingTimeInterval(seconds))
    }

    func testPicksTheNewestTakeAfterTheCutoff() {
        let start = Date()
        let older = take(10, from: start)
        let newest = take(40, from: start)
        let middle = take(25, from: start)
        // Deliberately unsorted: the lookup sorts rather than trusting a caller's order.
        let found = RoutineTakeLookup.take(from: [older, newest, middle], since: start)
        XCTAssertEqual(found?.uid, newest.uid)
    }

    /// The whole point of the cutoff. Before it, these are last week's takes.
    func testIgnoresTakesRecordedBeforeTheBlockBegan() {
        let start = Date()
        let lastWeek = take(-604_800, from: start)
        let earlierToday = take(-60, from: start)
        XCTAssertNil(RoutineTakeLookup.take(from: [lastWeek, earlierToday], since: start))
    }

    /// A take captured at the very instant the block began still belongs to it — the cutoff is
    /// inclusive, because the stamp and the arm happen in the same `.onAppear`.
    func testATakeAtTheCutoffCounts() {
        let start = Date()
        XCTAssertNotNil(RoutineTakeLookup.take(from: [take(0, from: start)], since: start))
    }

    func testNoTakesMeansNothingToOffer() {
        XCTAssertNil(RoutineTakeLookup.take(from: [], since: Date()))
    }

    /// **No cutoff is not a licence to guess.** With nothing to measure against there is no way to
    /// tell this run's take from any other, so the honest answer is `nil` — falling back on the newest
    /// take here is exactly the bug the cutoff exists to prevent, reintroduced by a convenience.
    func testAMissingCutoffOffersNothingRatherThanTheNewest() {
        let recent = Recording(fileName: "recent.m4a", duration: 5, createdAt: Date())
        XCTAssertNil(RoutineTakeLookup.take(from: [recent], since: nil))
    }
}
