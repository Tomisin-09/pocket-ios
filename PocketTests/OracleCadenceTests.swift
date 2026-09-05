import XCTest
@testable import Pocket

/// The weekly gate (ADR 0187 D15).
///
/// A fixed Gregorian calendar with an explicit `firstWeekday` throughout: the real one is Monday in
/// most of the world and Sunday in the US, and a test that inherited the runner's locale would pass
/// or fail depending on where CI was standing.
final class OracleCadenceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// Mon 2 Sep 2024, 00:00 UTC.
    private let monday = Date(timeIntervalSince1970: 1_725_235_200)

    private func at(_ days: Double, _ hours: Double = 0) -> Date {
        monday.addingTimeInterval(days * 86_400 + hours * 3_600)
    }

    func testTheFirstReadingIsNeverMadeToWait() {
        XCTAssertTrue(OracleCadence.isAvailable(now: at(0), lastReading: nil, calendar: calendar))
        XCTAssertNil(OracleCadence.nextReading(after: nil, now: at(0), calendar: calendar),
                     "With nothing taken yet there is no date to state")
    }

    func testASecondReadingInTheSameWeekIsNotAvailable() {
        let taken = at(0, 9)
        XCTAssertFalse(OracleCadence.isAvailable(now: at(2), lastReading: taken, calendar: calendar),
                       "Running it twice on Tuesday reads the same journal twice")
    }

    func testTheNextWeekOpensTheGate() {
        let taken = at(0, 9)
        XCTAssertTrue(OracleCadence.isAvailable(now: at(7), lastReading: taken, calendar: calendar))
    }

    /// D15 requires the date to be stated plainly, always — so it must be a real Monday, not "in
    /// about a week".
    func testTheNextReadingDateIsTheStartOfTheFollowingWeek() {
        let next = OracleCadence.nextReading(after: at(0, 9), now: at(3), calendar: calendar)
        XCTAssertEqual(next, at(7))
    }

    func testNoNextDateIsOfferedWhenAReadingIsAlreadyAvailable() {
        XCTAssertNil(OracleCadence.nextReading(after: at(0), now: at(9), calendar: calendar),
                     "A caller must not be able to render 'available now' and a future date at once")
    }

    /// A reflection on a week still being lived reads one day and calls it a week.
    func testTheWindowIsTheLastCompleteWeekNotTheOneInProgress() {
        let window = OracleCadence.window(endingBefore: at(3), calendar: calendar)
        XCTAssertEqual(window.start, at(-7))
        XCTAssertEqual(window.end, at(0))
        XCTAssertEqual(window.duration, 7 * 86_400, accuracy: 1)
    }

    /// A rolling seven days would creep the boundary forward every time it was used.
    func testTheWindowIsTheSameWhicheverDayOfTheWeekItIsAskedOn() {
        let onMonday = OracleCadence.window(endingBefore: at(0, 1), calendar: calendar)
        let onSunday = OracleCadence.window(endingBefore: at(6, 23), calendar: calendar)
        XCTAssertEqual(onMonday, onSunday)
    }
}
