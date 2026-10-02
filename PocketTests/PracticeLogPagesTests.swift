import XCTest
@testable import Pocket

/// The weeks and months the Practice log pages through (ADR 0241). Pure calendar walking — where the
/// first page is, that the last is always now, and that nothing drifts off a boundary — plus the
/// stepping the two section headers share.
final class PracticeLogPagesTests: XCTestCase {

    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        calendar.firstWeekday = 2      // Monday-first, so a week boundary is a fact, not a locale
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12,
                      in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    /// Started Saturday 1 August 2026; today is Friday 2 October.
    private lazy var utc = calendar()
    private lazy var started = date(2026, 8, 1, in: utc)
    private lazy var today = date(2026, 10, 2, in: utc)

    // MARK: - Weeks

    func testWeeksRunFromTheWeekYouStartedInToThisOneOldestFirst() {
        let starts = PracticeLogPages.weekStarts(since: started, now: today, calendar: utc)
        XCTAssertEqual(starts.count, 10)
        XCTAssertEqual(starts.first, date(2026, 7, 27, 0, in: utc),
                       "1 August is a Saturday, so its week began on Monday 27 July")
        XCTAssertEqual(starts.last, date(2026, 9, 28, 0, in: utc), "the current week is the last page")
    }

    func testEveryWeekPageStartsOnTheCalendarsFirstWeekday() {
        let starts = PracticeLogPages.weekStarts(since: started, now: today, calendar: utc)
        for start in starts {
            XCTAssertEqual(utc.component(.weekday, from: start), 2, "\(start) is not a Monday")
            XCTAssertEqual(utc.component(.hour, from: start), 0)
        }
        XCTAssertEqual(Set(starts).count, starts.count, "no week appears twice")
    }

    func testAnEmptyLogStillHasTheCurrentWeekToShow() {
        XCTAssertEqual(PracticeLogPages.weekStarts(since: nil, now: today, calendar: utc),
                       [date(2026, 9, 28, 0, in: utc)])
    }

    func testAFirstRunThisWeekGivesOnePage() {
        let starts = PracticeLogPages.weekStarts(since: date(2026, 9, 29, in: utc), now: today, calendar: utc)
        XCTAssertEqual(starts, [date(2026, 9, 28, 0, in: utc)])
    }

    func testAFirstRunAfterNowYieldsTheCurrentWeekAlone() {
        // A clock set backwards after practising. Nothing to page to, and nothing to crash on.
        let starts = PracticeLogPages.weekStarts(since: date(2026, 12, 1, in: utc), now: today, calendar: utc)
        XCTAssertEqual(starts, [date(2026, 9, 28, 0, in: utc)])
    }

    func testWeeksDoNotDriftAcrossAClockChange() {
        // The UK falls back on Sunday 25 October 2026: that week has a 25-hour day. Adding seven
        // days of seconds would land at 23:00 on the Sunday; the walk must still land on Mondays.
        let london = calendar("Europe/London")
        let starts = PracticeLogPages.weekStarts(since: date(2026, 10, 5, in: london),
                                                 now: date(2026, 11, 18, in: london), calendar: london)
        XCTAssertEqual(starts.count, 7)
        for start in starts {
            XCTAssertEqual(london.component(.weekday, from: start), 2)
            XCTAssertEqual(london.component(.hour, from: start), 0, "\(start) drifted off midnight")
        }
    }

    // MARK: - Months

    func testMonthsRunFromTheMonthYouStartedInToThisOne() {
        XCTAssertEqual(PracticeLogPages.monthStarts(since: started, now: today, calendar: utc),
                       [date(2026, 8, 1, 0, in: utc), date(2026, 9, 1, 0, in: utc), date(2026, 10, 1, 0, in: utc)])
    }

    func testMonthsCrossAYearBoundary() {
        let starts = PracticeLogPages.monthStarts(since: date(2025, 11, 20, in: utc),
                                                  now: date(2026, 2, 3, in: utc), calendar: utc)
        XCTAssertEqual(starts, [date(2025, 11, 1, 0, in: utc), date(2025, 12, 1, 0, in: utc),
                                date(2026, 1, 1, 0, in: utc), date(2026, 2, 1, 0, in: utc)])
    }

    // MARK: - Position

    private lazy var months = [date(2026, 8, 1, 0, in: utc), date(2026, 9, 1, 0, in: utc),
                               date(2026, 10, 1, 0, in: utc)]

    func testAPagerThatHasNotSettledShowsTheCurrentPeriod() {
        let position = PracticeLogPages.Position(starts: months, position: nil)
        XCTAssertEqual(position.shown, months[2])
        XCTAssertTrue(position.isCurrent)
        XCTAssertEqual(position.earlier, months[1])
        XCTAssertNil(position.later, "there is nothing after now to step to")
    }

    func testThePeriodYouStartedInHasNothingBeforeIt() {
        let position = PracticeLogPages.Position(starts: months, position: months[0])
        XCTAssertEqual(position.shown, months[0])
        XCTAssertFalse(position.isCurrent)
        XCTAssertNil(position.earlier)
        XCTAssertEqual(position.later, months[1])
    }

    func testAPositionThatIsNoLongerAPageFallsBackToNow() {
        let position = PracticeLogPages.Position(starts: months, position: date(2026, 3, 1, 0, in: utc))
        XCTAssertEqual(position.shown, months[2])
        XCTAssertTrue(position.isCurrent)
    }
}
