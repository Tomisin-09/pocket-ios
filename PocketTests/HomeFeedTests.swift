import XCTest
@testable import Pocket

/// Pure home-hub logic (ADR 0044 follow-on): the time-of-day greeting bucket and the
/// recently-practised selection/ordering. Tested over plain values via the `practicedAt`
/// closure, no model container needed (AGENTS.md "pure logic stays pure").
final class HomeFeedTests: XCTestCase {

    // MARK: - Time of day

    func testTimeOfDayBuckets() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 0), .night)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 4), .night)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 5), .morning)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 11), .morning)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 12), .afternoon)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 16), .afternoon)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 17), .evening)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 21), .evening)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 22), .night)
    }

    func testTimeOfDayFoldsOutOfRangeHours() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 24), .night)   // wraps to 0
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 29), .morning) // wraps to 5
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: -1), .night)   // wraps to 23
    }

    func testGreetingCopy() {
        XCTAssertEqual(HomeFeed.TimeOfDay.morning.greeting, "Good morning")
        XCTAssertEqual(HomeFeed.TimeOfDay.evening.greeting, "Good evening")
    }

    // MARK: - Most recently practised

    private struct Item { let name: String; let practiced: Date? }

    func testMostRecentlyPracticedPicksLatest() {
        let now = Date()
        let items = [
            Item(name: "old", practiced: now.addingTimeInterval(-1000)),
            Item(name: "newest", practiced: now),
            Item(name: "mid", practiced: now.addingTimeInterval(-500)),
            Item(name: "never", practiced: nil)
        ]
        XCTAssertEqual(HomeFeed.mostRecentlyPracticed(items, practicedAt: \.practiced)?.name, "newest")
    }

    func testMostRecentlyPracticedIsNilWhenNonePractised() {
        let items = [Item(name: "a", practiced: nil), Item(name: "b", practiced: nil)]
        XCTAssertNil(HomeFeed.mostRecentlyPracticed(items, practicedAt: \.practiced))
    }

    // MARK: - Ordering

    func testOrderedPutsRecentFirstThenUnpractisedByTitle() {
        let now = Date()
        let items = [
            Item(name: "Zed", practiced: nil),
            Item(name: "Apex", practiced: nil),
            Item(name: "Old", practiced: now.addingTimeInterval(-1000)),
            Item(name: "New", practiced: now)
        ]
        let ordered = HomeFeed.orderedForHome(items, practicedAt: \.practiced, title: \.name)
        XCTAssertEqual(ordered.map(\.name), ["New", "Old", "Apex", "Zed"])
    }

    func testOrderedIsDeterministicForEqualDates() {
        let when = Date()
        let items = [Item(name: "Beta", practiced: when), Item(name: "alpha", practiced: when)]
        // Equal practice dates fall back to a case-insensitive title sort, so the order is stable.
        XCTAssertEqual(HomeFeed.orderedForHome(items, practicedAt: \.practiced, title: \.name).map(\.name),
                       ["alpha", "Beta"])
    }
}
