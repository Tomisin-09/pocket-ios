import XCTest
@testable import Pocket

/// How the month grid shades a day (ADR 0268): against the month's **typical** practised day — its
/// upper quartile — rather than its longest, so one long day can't turn every ordinary day pale.
final class MonthShadingTests: XCTestCase {

    /// A month from per-day minutes, oldest first. `nil` is a day with nothing logged.
    private func makeMonth(_ minutes: [Double?]) -> PracticeProgress.Month {
        let start = Date(timeIntervalSince1970: 0)
        let days = minutes.enumerated().map { index, dayMinutes in
            PracticeLog.DayBucket(day: start.addingTimeInterval(Double(index) * 86_400),
                                  seconds: (dayMinutes ?? 0) * 60,
                                  runCount: dayMinutes == nil ? 0 : 1)
        }
        return .init(interval: DateInterval(start: start, duration: Double(days.count) * 86_400),
                     days: days, minutes: 0, daysActive: days.filter(\.isActive).count,
                     bestDay: nil, newTempos: 0)
    }

    private func shades(_ month: PracticeProgress.Month) -> [Int?] {
        month.days.map { month.shade(of: $0) }
    }

    /// The case that asked for the change: twenty minutes on 29 days and two hours on one. Shaded
    /// against the longest day, every one of the 29 was the palest shade.
    func testOneLongDayNoLongerWashesOutAMonthOfOrdinaryDays() {
        let month = makeMonth(Array(repeating: 20, count: 29) + [120])
        XCTAssertEqual(month.shadeScaleSeconds, 20 * 60)
        XCTAssertEqual(Set(shades(month)), [3], "every day reached the month's typical day")
    }

    func testTheScaleIsTheUpperQuartileNotTheLongestDay() {
        let month = makeMonth([10, 20, 30, 40, 50, 60, 70, 80])
        XCTAssertEqual(month.shadeScaleSeconds, 60 * 60, "the 6th of 8, by nearest rank")
        XCTAssertEqual(shades(month), [0, 1, 1, 2, 3, 3, 3, 3])
    }

    func testWithThreeDaysOrFewerTheScaleIsTheLongestDay() {
        // Three days have no "typical" to find, and nearest rank lands on the longest by itself.
        XCTAssertEqual(makeMonth([10, 20, 60]).shadeScaleSeconds, 60 * 60)
        XCTAssertEqual(makeMonth([10, 60]).shadeScaleSeconds, 60 * 60)
        XCTAssertEqual(makeMonth([45]).shadeScaleSeconds, 45 * 60)
        XCTAssertEqual(shades(makeMonth([10, 20, 60])), [0, 1, 3])
    }

    func testDaysWithNothingLoggedTakeNoShadeAndDoNotMoveTheScale() {
        let month = makeMonth([nil, 20, nil, 40, nil, nil, 60, 80])
        XCTAssertEqual(month.shadeScaleSeconds, 60 * 60, "the quartile of the four practised days")
        XCTAssertEqual(shades(month), [nil, 1, nil, 2, nil, nil, 3, 3])
    }

    func testAnyPracticeAtAllReachesThePalestShade() {
        // Twenty seconds beside hour-long days still reads as a day practised, not a day off.
        let month = makeMonth([20.0 / 60, 60, 60, 60, 60])
        XCTAssertEqual(month.shade(of: month.days[0]), 0)
        // A run logged with no length at all is still a practised day.
        let zero = makeMonth([0])
        XCTAssertEqual(zero.shadeScaleSeconds, 1)
        XCTAssertEqual(zero.shade(of: zero.days[0]), 0)
    }

    func testAnEmptyMonthHasAScaleAndNoShades() {
        let month = makeMonth(Array(repeating: nil, count: 30))
        XCTAssertEqual(month.shadeScaleSeconds, 1, "never zero, so nothing divides by it")
        XCTAssertEqual(Set(shades(month)), [nil])
    }

    /// The four shades split the scale into quarters, each boundary belonging to the shade below it.
    func testEachShadeIsAQuarterOfTheScale() {
        let month = makeMonth([10, 20, 30, 40, 40, 40, 40, 40])
        XCTAssertEqual(month.shadeScaleSeconds, 40 * 60)
        XCTAssertEqual(shades(month), [0, 1, 2, 3, 3, 3, 3, 3])
        let justOver = makeMonth([10.5, 40, 40, 40])
        XCTAssertEqual(justOver.shade(of: justOver.days[0]), 1)
    }
}
