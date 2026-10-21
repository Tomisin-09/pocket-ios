import XCTest
@testable import Pocket

/// The figures a chosen day shows above the week chart or the month grid (ADR 0269): that day's
/// minutes and new tempos, bucketed the way the chart draws it and measured against the whole log.
final class PracticeDayFiguresTests: XCTestCase {

    private let drill = UUID()

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))
            ?? .distantPast
    }

    private func run(_ startedAt: Date, minutes: Double, bpm: Int? = nil) -> SessionRecord {
        SessionRecord(startedAt: startedAt, durationSeconds: minutes * 60, kind: .exercise,
                      unitUID: drill, tempoBPM: bpm, notesPerBeat: bpm == nil ? nil : 4)
    }

    private func day(_ records: [SessionRecord], _ month: Int, _ day: Int) -> PracticeProgress.Day {
        PracticeProgress.day(records: records, containing: date(month, day), calendar: calendar)
    }

    /// Both ends of the day are in it and the days either side are not, so the figure is the day's
    /// and not the week's or the month's.
    func testTheDayCountsItsOwnRunsAndNoOthers() {
        let records = [run(date(9, 28, hour: 23, minute: 59), minutes: 10),
                       run(date(9, 29, hour: 0), minutes: 20),
                       run(date(9, 29, hour: 23, minute: 59), minutes: 5),
                       run(date(9, 30, hour: 0), minutes: 7)]
        let chosen = day(records, 9, 29)
        XCTAssertEqual(chosen.interval.start, date(9, 29, hour: 0))
        XCTAssertEqual(chosen.bucket.seconds, 25 * 60)
        XCTAssertEqual(chosen.minutesFigure, .init(seconds: 25 * 60))
        XCTAssertEqual(chosen.minutesFigure.value, "25")
    }

    /// The figure is read off the same bucket the grid shades, so the cell you tap and the number
    /// above it can't disagree.
    func testTheDayIsTheBucketTheMonthDraws() {
        let records = [run(date(9, 14), minutes: 33), run(date(9, 29), minutes: 223), run(date(9, 29), minutes: 4)]
        let month = PracticeProgress.month(records: records, now: date(9, 1), calendar: calendar)
        let drawn = month.days.first { calendar.isDate($0.day, inSameDayAs: date(9, 29)) }
        XCTAssertEqual(day(records, 9, 29).bucket, drawn)
    }

    func testANewTempoCountsOnTheDayItWasSetAndNoOther() {
        let records = [run(date(9, 1), minutes: 10, bpm: 76),
                       run(date(9, 14), minutes: 10, bpm: 80),   // new
                       run(date(9, 29), minutes: 10, bpm: 78)]   // below the ceiling
        XCTAssertEqual(day(records, 9, 1).newTempos, 0, "there was nothing to have beaten")
        XCTAssertEqual(day(records, 9, 14).newTempos, 1)
        XCTAssertEqual(day(records, 9, 29).newTempos, 0)
    }

    /// A day's run is new only if it beats everything before it, not just what came earlier that day
    /// or that month — the rule the month's own figure keeps.
    func testANewTempoIsMeasuredAgainstTheWholeLog() {
        let records = [run(date(8, 1), minutes: 10, bpm: 90),
                       run(date(9, 1), minutes: 10, bpm: 76),
                       run(date(9, 14), minutes: 10, bpm: 80)]   // faster than September, not than August
        XCTAssertEqual(day(records, 9, 14).newTempos, 0, "August already went faster")
    }

    func testPracticeThatRoundsToNothingReadsUnderAMinute() {
        let chosen = day([run(date(9, 29), minutes: 20.0 / 60)], 9, 29)
        XCTAssertEqual(chosen.minutesFigure.value, "<1")
        XCTAssertEqual(chosen.minutesFigure.unit, "minute")
    }

    func testADayWithNothingLoggedIsZero() {
        let chosen = day([run(date(9, 28), minutes: 15)], 9, 29)
        XCTAssertFalse(chosen.bucket.isActive)
        XCTAssertEqual(chosen.minutesFigure.value, "0")
        XCTAssertEqual(chosen.newTempos, 0)
    }
}
