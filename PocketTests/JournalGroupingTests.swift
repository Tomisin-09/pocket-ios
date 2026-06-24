import XCTest
@testable import Pocket

/// `JournalGrouping.byDay` buckets loop-journal entries into day-sections (ADR 0038),
/// newest day first and newest entry first within a day. Pure logic — tested with a
/// fixed UTC calendar and plain `Date`s so it needs no SwiftData container.
final class JournalGroupingTests: XCTestCase {

    /// Fixed-offset calendar so `startOfDay` boundaries are deterministic regardless of
    /// the machine's timezone.
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Fixed reference noon-GMT day, plus offsets, so dates are built without force-unwraps.
    /// 2023-11-14 12:00:00 GMT.
    private let noon = Date(timeIntervalSince1970: 1_699_963_200)
    private let day: TimeInterval = 86_400
    private let hour: TimeInterval = 3_600

    func testEmptyInputGivesNoSections() {
        let sections = JournalGrouping.byDay([Date]()) { $0 }
        XCTAssertTrue(sections.isEmpty)
    }

    func testGroupsByCalendarDay() {
        let dates = [
            noon - 3 * hour,      // same day, morning
            noon + 6 * hour,      // same day, evening
            noon - 2 * day        // two days earlier
        ]
        let sections = JournalGrouping.byDay(dates, calendar: utc) { $0 }
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].entries.count, 2)   // the two same-day entries
        XCTAssertEqual(sections[1].entries.count, 1)   // the earlier day
    }

    func testDaysSortNewestFirst() {
        let dates = [noon - 2 * day, noon, noon - 1 * day]
        let sections = JournalGrouping.byDay(dates, calendar: utc) { $0 }
        let days = sections.map { utc.startOfDay(for: $0.day) }
        XCTAssertEqual(days, [utc.startOfDay(for: noon),
                              utc.startOfDay(for: noon - 1 * day),
                              utc.startOfDay(for: noon - 2 * day)])
    }

    func testEntriesWithinADaySortNewestFirst() {
        let morning = noon - 3 * hour
        let evening = noon + 9 * hour
        let sections = JournalGrouping.byDay([morning, evening], calendar: utc) { $0 }
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].entries, [evening, morning])
    }

    func testSectionDayIsStartOfDay() {
        let sections = JournalGrouping.byDay([noon + 3 * hour], calendar: utc) { $0 }
        XCTAssertEqual(sections[0].day, utc.startOfDay(for: noon + 3 * hour))
    }
}
