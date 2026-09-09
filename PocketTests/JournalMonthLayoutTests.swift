import XCTest
@testable import Pocket

/// `JournalMonthLayout` (ADR 0207 D5/D6) — the Journal's month rail and month grid.
///
/// Every test pins its own `Calendar` rather than reading `.current`: the whole point of this type is
/// the off-by-one-column class of bug, and a suite that inherits the machine's locale can only find
/// it on a machine already configured to show it.
final class JournalMonthLayoutTests: XCTestCase {

    /// Gregorian, UTC, Sunday-first — the layout most of these assertions are written against.
    private var sundayFirst: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 1
        return calendar
    }

    /// The same calendar with a Monday start — the case that shifts every cell one column left.
    private var mondayFirst: Calendar {
        var calendar = sundayFirst
        calendar.firstWeekday = 2
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int,
                     calendar: Calendar? = nil) -> Date {
        let usable = calendar ?? sundayFirst
        return usable.date(from: DateComponents(year: year, month: month, day: dayOfMonth)) ?? .distantPast
    }

    // MARK: - months(in:)

    func testMonthsPreserveTheOrderTheyAppearIn() {
        // Display order, newest first — what `visibleDays` hands over under the default sort.
        let days = [day(2026, 9, 8), day(2026, 9, 1), day(2026, 8, 30), day(2026, 6, 2)]
        let months = JournalMonthLayout.months(in: days, calendar: sundayFirst)
        XCTAssertEqual(months, [day(2026, 9, 1), day(2026, 8, 1), day(2026, 6, 1)])
    }

    /// The rail must read the same way as the list beneath it, so reversing the feed reverses the
    /// rail — with no sort parameter anywhere in this type.
    func testMonthsFollowAReversedFeed() {
        let days = [day(2026, 6, 2), day(2026, 8, 30), day(2026, 9, 1)]
        let months = JournalMonthLayout.months(in: days, calendar: sundayFirst)
        XCTAssertEqual(months, [day(2026, 6, 1), day(2026, 8, 1), day(2026, 9, 1)])
    }

    /// A month with no entries is simply absent — that is the rail's whole claim, and it is what
    /// keeps it navigation rather than a calendar with holes in it.
    func testAMonthWithNoDaysIsNotListed() {
        let days = [day(2026, 9, 8), day(2026, 7, 4)]
        let months = JournalMonthLayout.months(in: days, calendar: sundayFirst)
        XCTAssertFalse(months.contains(day(2026, 8, 1)))
    }

    func testMonthsOfNothingIsEmpty() {
        XCTAssertTrue(JournalMonthLayout.months(in: [], calendar: sundayFirst).isEmpty)
    }

    // MARK: - firstDay(inMonth:of:)

    /// "First" is positional. Under a newest-first feed the top of August is the 30th, not the 2nd.
    func testFirstDayInMonthIsTheFirstOnScreenNotTheEarliest() {
        let days = [day(2026, 9, 1), day(2026, 8, 30), day(2026, 8, 2)]
        XCTAssertEqual(JournalMonthLayout.firstDay(inMonth: day(2026, 8, 1), of: days,
                                                  calendar: sundayFirst),
                       day(2026, 8, 30))
    }

    /// …and under an oldest-first feed it is the 2nd, from the same function.
    func testFirstDayInMonthFollowsAReversedFeed() {
        let days = [day(2026, 8, 2), day(2026, 8, 30), day(2026, 9, 1)]
        XCTAssertEqual(JournalMonthLayout.firstDay(inMonth: day(2026, 8, 1), of: days,
                                                  calendar: sundayFirst),
                       day(2026, 8, 2))
    }

    func testFirstDayInAMonthWithNothingInItIsNil() {
        let days = [day(2026, 9, 1), day(2026, 7, 4)]
        XCTAssertNil(JournalMonthLayout.firstDay(inMonth: day(2026, 8, 1), of: days,
                                                 calendar: sundayFirst))
    }

    // MARK: - weeks(of:)

    /// August 2026 starts on a Saturday, so a Sunday-first grid needs six leading blanks.
    func testLeadingBlanksForAMonthStartingOnASaturday() {
        let weeks = JournalMonthLayout.weeks(of: day(2026, 8, 1), calendar: sundayFirst)
        let firstRow = try? XCTUnwrap(weeks.first)
        XCTAssertEqual(firstRow?.prefix(6).compactMap { $0 }.count, 0, "expected six blanks")
        XCTAssertEqual(firstRow?[6], day(2026, 8, 1))
    }

    /// The same month, Monday-first: the 1st is a Saturday, which is now column five.
    func testLeadingBlanksShiftWithFirstWeekday() {
        let weeks = JournalMonthLayout.weeks(of: day(2026, 8, 1, calendar: mondayFirst),
                                             calendar: mondayFirst)
        XCTAssertEqual(weeks.first?[5], day(2026, 8, 1, calendar: mondayFirst))
        XCTAssertNil(weeks.first?[4])
    }

    func testEveryRowIsSevenWideAndTheLastIsPadded() {
        for month in [day(2026, 2, 1), day(2026, 8, 1), day(2026, 11, 1)] {
            let weeks = JournalMonthLayout.weeks(of: month, calendar: sundayFirst)
            XCTAssertTrue(weeks.allSatisfy { $0.count == 7 },
                          "a row was not seven wide for \(month)")
        }
    }

    /// February in a leap year — the case a hand-built grid gets wrong and a `DatePicker` never did.
    func testLeapFebruaryHasTwentyNineDays() {
        let weeks = JournalMonthLayout.weeks(of: day(2028, 2, 1), calendar: sundayFirst)
        XCTAssertEqual(weeks.flatMap { $0 }.compactMap { $0 }.count, 29)
    }

    func testNonLeapFebruaryHasTwentyEightDays() {
        let weeks = JournalMonthLayout.weeks(of: day(2026, 2, 1), calendar: sundayFirst)
        XCTAssertEqual(weeks.flatMap { $0 }.compactMap { $0 }.count, 28)
    }

    /// Every cell that is not nil belongs to the month asked for — no spill from either neighbour.
    func testNoCellBelongsToANeighbouringMonth() {
        let weeks = JournalMonthLayout.weeks(of: day(2026, 8, 1), calendar: sundayFirst)
        for date in weeks.flatMap({ $0 }).compactMap({ $0 }) {
            XCTAssertEqual(sundayFirst.component(.month, from: date), 8)
        }
    }

    // MARK: - weekdayInitials

    func testWeekdayInitialsStartOnSunday() {
        XCTAssertEqual(JournalMonthLayout.weekdayInitials(calendar: sundayFirst).count, 7)
        XCTAssertEqual(JournalMonthLayout.weekdayInitials(calendar: sundayFirst).first,
                       sundayFirst.veryShortStandaloneWeekdaySymbols.first)
    }

    /// The headings must rotate with the cells, or the grid is labelled wrong rather than laid out
    /// wrong — which is harder to see and just as false.
    func testWeekdayInitialsRotateWithFirstWeekday() {
        let initials = JournalMonthLayout.weekdayInitials(calendar: mondayFirst)
        XCTAssertEqual(initials.first, mondayFirst.veryShortStandaloneWeekdaySymbols[1])
        XCTAssertEqual(initials.last, mondayFirst.veryShortStandaloneWeekdaySymbols[0])
    }

    // MARK: - month(after:by:within:)

    func testSteppingStaysInsideTheJournalsSpan() {
        let bounds = [day(2026, 6, 2), day(2026, 9, 8)]
        XCTAssertEqual(JournalMonthLayout.month(after: day(2026, 8, 1), by: 1, within: bounds,
                                                calendar: sundayFirst),
                       day(2026, 9, 1))
        XCTAssertEqual(JournalMonthLayout.month(after: day(2026, 7, 1), by: -1, within: bounds,
                                                calendar: sundayFirst),
                       day(2026, 6, 1))
    }

    /// Past either end there is nothing to step to, which is what greys the control out.
    func testSteppingPastTheEndsIsNil() {
        let bounds = [day(2026, 6, 2), day(2026, 9, 8)]
        XCTAssertNil(JournalMonthLayout.month(after: day(2026, 9, 1), by: 1, within: bounds,
                                              calendar: sundayFirst))
        XCTAssertNil(JournalMonthLayout.month(after: day(2026, 6, 1), by: -1, within: bounds,
                                              calendar: sundayFirst))
    }

    /// A month **inside** the span but with no entries is still steppable — the span is a range, not
    /// the set of months that happen to hold something. Stepping through July to reach June is how
    /// you reach June.
    func testSteppingThroughAnEmptyMonthIsAllowed() {
        let bounds = [day(2026, 6, 2), day(2026, 9, 8)]
        XCTAssertEqual(JournalMonthLayout.month(after: day(2026, 8, 1), by: -1, within: bounds,
                                                calendar: sundayFirst),
                       day(2026, 7, 1))
    }
}
