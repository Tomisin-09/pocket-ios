import XCTest
@testable import Pocket

/// `JournalLookback` (ADR 0207 D8) — the widening ladder behind the feed's look-back card.
///
/// The ladder is the kind of logic that fails silently: a wrong rung still returns *an* entry, and
/// the card still renders, so nothing looks broken. These pin which rung fires and what it says.
final class JournalLookbackTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// Today, for every test below. A year back is 8 September 2025.
    private var now: Date { date(2026, 9, 8) }

    private func items(_ dates: [(String, Date)]) -> [(element: String, date: Date)] {
        dates.map { (element: $0.0, date: $0.1) }
    }

    // MARK: - The rungs

    func testAnExactAnniversaryReadsAsToday() {
        let found = JournalLookback.find(in: items([("bullseye", date(2025, 9, 8))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "bullseye")
        XCTAssertEqual(found?.reach, .day)
        XCTAssertEqual(found?.reach.heading(for: .oneYear), "A year ago today")
    }

    func testNothingOnTheDayWidensToTheWeek() {
        // 10 Sep 2025 is in the same week as the 8th (Sunday-first: 7–13 Sep).
        let found = JournalLookback.find(in: items([("nearby", date(2025, 9, 10))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "nearby")
        XCTAssertEqual(found?.reach, .week)
        XCTAssertEqual(found?.reach.heading(for: .oneYear), "A year ago this week")
    }

    func testNothingInTheWeekWidensToTheMonth() {
        let found = JournalLookback.find(in: items([("distant", date(2025, 9, 26))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "distant")
        XCTAssertEqual(found?.reach, .month)
        XCTAssertEqual(found?.reach.heading(for: .oneYear), "A year ago this month")
    }

    /// The card is **absent**, not empty — the `HomeStatsStrip` rule. A journal with nothing near the
    /// anniversary says nothing rather than saying so.
    func testNothingInTheMonthFindsNothing() {
        let found = JournalLookback.find(in: items([("far", date(2025, 6, 2))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertNil(found)
    }

    func testAnEmptyJournalFindsNothing() {
        XCTAssertNil(JournalLookback.find(in: items([]), now: now, period: .oneYear,
                                          calendar: calendar))
    }

    // MARK: - The narrowest rung wins

    /// A day hit must beat a week hit even when the week hit is listed first — otherwise the heading
    /// says "today" for something that wasn't, or "this week" for something that was.
    func testTheNarrowestRungWinsRegardlessOfOrder() {
        let found = JournalLookback.find(in: items([("week", date(2025, 9, 11)),
                                                    ("day", date(2025, 9, 8))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "day")
        XCTAssertEqual(found?.reach, .day)
    }

    // MARK: - How it chooses between candidates

    func testWithinARungTheNearestDateWins() {
        let found = JournalLookback.find(in: items([("far", date(2025, 9, 26)),
                                                    ("near", date(2025, 9, 20))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "near")
    }

    /// Equidistant either side of the anniversary: the tiebreak is **the more recent date**, and it
    /// has to be a date. ADR 0190 D1 forbids the app deciding which entry mattered, so nothing about
    /// the entry itself — kind, pin, length — may enter this comparison.
    func testATieIsBrokenByTheMoreRecentDateNotByTheEntry() {
        let found = JournalLookback.find(in: items([("earlier", date(2025, 9, 6)),
                                                    ("later", date(2025, 9, 10))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertEqual(found?.element, "later")
    }

    /// The same store on the same day must produce the same card, or the feed's top row changes
    /// under the reader as they scroll.
    func testTheResultIsDeterministic() {
        let candidates = items([("a", date(2025, 9, 9)), ("b", date(2025, 9, 7)),
                                ("c", date(2025, 9, 20))])
        let first = JournalLookback.find(in: candidates, now: now, period: .oneYear,
                                         calendar: calendar)
        let second = JournalLookback.find(in: candidates, now: now, period: .oneYear,
                                          calendar: calendar)
        XCTAssertEqual(first?.element, second?.element)
    }

    // MARK: - Period

    func testOffFindsNothingEvenWithAPerfectMatch() {
        let found = JournalLookback.find(in: items([("bullseye", date(2025, 9, 8))]),
                                         now: now, period: .off, calendar: calendar)
        XCTAssertNil(found)
    }

    func testSixMonthsLooksBackSixMonths() {
        let found = JournalLookback.find(in: items([("spring", date(2026, 3, 8))]),
                                         now: now, period: .sixMonths, calendar: calendar)
        XCTAssertEqual(found?.element, "spring")
        XCTAssertEqual(found?.reach, .day)
    }

    func testTwoYearsLooksBackTwoYears() {
        let found = JournalLookback.find(in: items([("old", date(2024, 9, 8))]),
                                         now: now, period: .twoYears, calendar: calendar)
        XCTAssertEqual(found?.element, "old")
    }

    /// A period only ever reaches its own window — a year-ago card must not surface a six-month-ago
    /// entry just because nothing older exists.
    func testAPeriodDoesNotReachOutsideItsOwnMonth() {
        let found = JournalLookback.find(in: items([("recent", date(2026, 3, 8))]),
                                         now: now, period: .oneYear, calendar: calendar)
        XCTAssertNil(found)
    }

    // MARK: - Period plumbing

    func testUnknownRawValuesFallBackToTheDefault() {
        XCTAssertEqual(JournalLookback.Period(raw: "fortnight"), JournalLookback.Period.default)
        XCTAssertEqual(JournalLookback.Period(raw: ""), JournalLookback.Period.default)
    }

    func testTheDefaultIsAYear() {
        XCTAssertEqual(JournalLookback.Period.default, .oneYear)
    }

    /// The heading is assembled from the period's own label, so changing one cannot leave the other
    /// saying something different about how far back the card reaches.
    func testHeadingsFollowThePeriodLabel() {
        XCTAssertEqual(JournalLookback.Reach.day.heading(for: .sixMonths), "6 months ago today")
        XCTAssertEqual(JournalLookback.Reach.month.heading(for: .twoYears), "2 years ago this month")
    }

    func testOffHasNoOffset() {
        XCTAssertNil(JournalLookback.Period.off.components)
    }
}
