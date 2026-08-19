import XCTest
@testable import Pocket

/// The pure aggregation over the practice log (ADR 0117). This is the off-by-one surface — day
/// boundaries, week starts, the gap that ends a sitting — so it is tested rather than eyeballed
/// (AGENTS.md). A fixed UTC/Monday calendar keeps every assertion independent of where the test runs.
final class PracticeLogTests: XCTestCase {

    /// Monday-first, UTC — so "the week containing Wednesday" is a fact, not a locale.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day,
                                           hour: hour, minute: minute)) ?? .distantPast
    }

    private func run(_ start: Date, minutes: Double, kind: PracticeRunKind = .exercise,
                     unit: UUID? = nil, routine: UUID? = nil,
                     bpm: Int? = nil, perBeat: Int? = nil) -> SessionRecord {
        SessionRecord(startedAt: start, durationSeconds: minutes * 60, kind: kind,
                      unitUID: unit, routineUID: routine, tempoBPM: bpm, notesPerBeat: perBeat)
    }

    // MARK: - Windows

    func testWeekIntervalStartsOnTheCalendarsFirstWeekday() {
        // 2026-06-10 is a Wednesday; a Monday-first week runs Mon 8th → Mon 15th.
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        XCTAssertEqual(week.start, date(8, 0))
        XCTAssertEqual(week.end, date(15, 0))
    }

    func testWindowExcludesTheEndInstant() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        // A run starting exactly at the boundary belongs to the *next* week, never both.
        let records = [run(date(8, 0), minutes: 10), run(date(15, 0), minutes: 10)]
        let inside = PracticeLog.records(in: week, from: records)
        XCTAssertEqual(inside.count, 1)
        XCTAssertEqual(inside[0].startedAt, date(8, 0))
    }

    func testRunCrossingMidnightCountsWhollyOnTheDayItStarted() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        let buckets = PracticeLog.dailyBuckets([run(date(9, 23, 45), minutes: 30)],
                                               in: week, calendar: calendar)
        let ninth = buckets.first { $0.day == date(9, 0) }
        let tenth = buckets.first { $0.day == date(10, 0) }
        XCTAssertEqual(ninth?.minutes, 30)
        XCTAssertEqual(tenth?.minutes, 0, "a run must never be split across two days")
    }

    // MARK: - Day buckets

    func testWeekAlwaysYieldsSevenBucketsIncludingEmptyDays() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        let buckets = PracticeLog.dailyBuckets([run(date(10), minutes: 12)],
                                               in: week, calendar: calendar)
        XCTAssertEqual(buckets.count, 7, "the chart keeps its shape on a quiet week")
        XCTAssertEqual(PracticeLog.daysActive(buckets), 1)
        XCTAssertEqual(buckets.filter { !$0.isActive }.count, 6)
    }

    func testDayMinutesRoundOnceFromTheDaysTotal() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        // Three 40-second runs are two minutes — not three, which is what rounding each would give.
        let records = (0..<3).map { run(date(10, 12, $0 * 5), minutes: 40.0 / 60) }
        let buckets = PracticeLog.dailyBuckets(records, in: week, calendar: calendar)
        let day = buckets.first { $0.day == date(10, 0) }
        XCTAssertEqual(day?.runCount, 3)
        XCTAssertEqual(day?.minutes, 2)
    }

    func testBestDayBreaksTiesOnTheEarlierDay() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        let records = [run(date(9), minutes: 20), run(date(11), minutes: 20)]
        let best = PracticeLog.bestDay(PracticeLog.dailyBuckets(records, in: week, calendar: calendar))
        XCTAssertEqual(best?.day, date(9, 0), "a tie must resolve the same way on every render")
    }

    func testBestDayIsNilWhenNothingWasPractised() {
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        XCTAssertNil(PracticeLog.bestDay(PracticeLog.dailyBuckets([], in: week, calendar: calendar)))
    }

    // MARK: - Standalone runs (ADR 0117)

    /// **A run practised outside a routine counts exactly as much as one inside it.** The writer has
    /// always passed `routineUID: nil` for a standalone run and written the row anyway, and no
    /// aggregate here filters on it — but that was proven only incidentally, because every other test
    /// in this file builds rows with no routine at all. Pinned, because "standalone practice doesn't
    /// count" is a plausible-sounding claim that would be cheap to implement by accident.
    func testStandaloneRunsCountTowardStatsAlongsideRoutineRuns() {
        let routine = UUID()
        let week = PracticeLog.weekInterval(containing: date(10), calendar: calendar)
        let records = [run(date(9, 9), minutes: 20, routine: routine),
                       run(date(10, 9), minutes: 15),                       // standalone
                       run(date(11, 9), minutes: 25, kind: .earLoop),       // standalone ear training
                       run(date(12, 9), minutes: 10, kind: .improvise)]     // standalone jam

        XCTAssertEqual(PracticeLog.totalMinutes(records), 70,
                       "every minute counts, whatever container it happened in")
        let buckets = PracticeLog.dailyBuckets(records, in: week, calendar: calendar)
        XCTAssertEqual(PracticeLog.daysActive(buckets), 4,
                       "a standalone run earns its day like any other")
        XCTAssertEqual(PracticeLog.lifetime(records).runCount, 4)
    }

    /// The mirror of the above: dropping the routine rows must change the totals by exactly those
    /// rows and nothing else — so no aggregate can be quietly keying off `routineUID`.
    ///
    /// The invariant is about the **shared** aggregates, the ones every screen reads.
    /// `PracticeLog.routineHistory` (ADR 0173) is the deliberate exception and the only read in the
    /// file that *may* key off `routineUID`; see `testRoutineHistoryLeavesTheSharedAggregatesAlone`,
    /// which pins that it stays an addition rather than a change of what the field means here.
    func testRoutineAttributionDoesNotChangeAnyAggregate() {
        let unit = UUID()
        let inRoutine = [run(date(10, 9), minutes: 20, unit: unit, routine: UUID())]
        let standalone = [run(date(10, 9), minutes: 20, unit: unit)]

        XCTAssertEqual(PracticeLog.totalMinutes(inRoutine), PracticeLog.totalMinutes(standalone))
        XCTAssertEqual(PracticeLog.sittings(inRoutine).count, PracticeLog.sittings(standalone).count)
        XCTAssertEqual(PracticeLog.lastPracticedByUnit(inRoutine)[unit],
                       PracticeLog.lastPracticedByUnit(standalone)[unit])
    }

    // MARK: - Sittings

    func testRoutineBlocksBackToBackFormOneSitting() {
        // Six 5-minute blocks with a 1-minute breather each — one sit, not six.
        var records: [SessionRecord] = []
        for index in 0..<6 {
            records.append(run(date(10, 9, index * 6), minutes: 5))
        }
        let sittings = PracticeLog.sittings(records)
        XCTAssertEqual(sittings.count, 1)
        XCTAssertEqual(sittings[0].runCount, 6)
        XCTAssertEqual(sittings[0].minutes, 30, "a sit sums run time, not wall-clock")
    }

    func testMorningAndEveningPracticeAreTwoSittings() {
        let records = [run(date(10, 8), minutes: 20), run(date(10, 20), minutes: 15)]
        let sittings = PracticeLog.sittings(records)
        XCTAssertEqual(sittings.count, 2)
        XCTAssertEqual(sittings.map(\.minutes), [20, 15])
    }

    func testGapIsMeasuredFromTheEndOfThePreviousRun() {
        // A 90-minute block followed 10 minutes later: same sit, even though the *starts* are far
        // apart — which is the whole reason the gap is measured from the end.
        let records = [run(date(10, 9), minutes: 90), run(date(10, 10, 40), minutes: 10)]
        XCTAssertEqual(PracticeLog.sittings(records).count, 1)
    }

    func testSittingsAreDerivedFromUnorderedRecords() {
        let records = [run(date(10, 20), minutes: 15), run(date(10, 8), minutes: 20)]
        XCTAssertEqual(PracticeLog.sittings(records).map(\.startedAt),
                       [date(10, 8), date(10, 20)])
    }

    // MARK: - Lifetime

    func testLifetimeOnAnEmptyLogClaimsNoStartDate() {
        let lifetime = PracticeLog.lifetime([])
        XCTAssertTrue(lifetime.isEmpty)
        XCTAssertNil(lifetime.since, "a fresh install has no date practice started")
        XCTAssertEqual(lifetime.hours, 0)
    }

    func testLifetimeRollsUpRunsSittingsAndStartDate() {
        let records = [run(date(3, 9), minutes: 30), run(date(3, 9, 35), minutes: 30),
                       run(date(10, 9), minutes: 45)]
        let lifetime = PracticeLog.lifetime(records)
        XCTAssertEqual(lifetime.runCount, 3)
        XCTAssertEqual(lifetime.sittingCount, 2)
        XCTAssertEqual(lifetime.minutes, 105)
        XCTAssertEqual(lifetime.since, date(3, 9))
    }

    func testLifetimeHoursDoNotRoundUpAWholeHour() {
        // 119 minutes is one hour and 59, not two — the headline never invents an hour.
        let lifetime = PracticeLog.lifetime([run(date(10), minutes: 119)])
        XCTAssertEqual(lifetime.hours, 1)
        XCTAssertEqual(lifetime.remainingMinutes, 59)
    }

    func testLifetimeHoursAgreeWithTheMinutesTheMonthWouldShow() {
        // Ten seconds short of two hours. The month section rounds this to 120 minutes, so all-time
        // must say two hours — flooring the raw seconds said "1 hour" and read as all-time being
        // *smaller* than the month inside it.
        let records = [run(date(10), minutes: 119 + 50.0 / 60)]
        let lifetime = PracticeLog.lifetime(records)
        XCTAssertEqual(PracticeLog.totalMinutes(records), 120)
        XCTAssertEqual(lifetime.minutes, 120)
        XCTAssertEqual(lifetime.hours, 2)
        XCTAssertEqual(lifetime.remainingMinutes, 0)
    }

    func testLifetimeUnderAnHourHasNoHoursToShow() {
        let lifetime = PracticeLog.lifetime([run(date(10), minutes: 17)])
        XCTAssertEqual(lifetime.hours, 0)
        XCTAssertEqual(lifetime.remainingMinutes, 17)
    }

    func testNegativeDurationsAreClampedAtTheValueBoundary() {
        let record = SessionRecord(startedAt: date(10), durationSeconds: -60, kind: .exercise)
        XCTAssertEqual(record.durationSeconds, 0)
        XCTAssertEqual(record.endedAt, record.startedAt)
    }

    // MARK: - Recency (ADR 0137)

    func testLastPracticedByUnitTakesTheLatestRunPerUnit() {
        let unit = UUID()
        let other = UUID()
        let map = PracticeLog.lastPracticedByUnit([
            run(date(10), minutes: 5, unit: unit),
            run(date(14), minutes: 5, unit: unit),   // latest for `unit`
            run(date(12), minutes: 5, unit: unit),
            run(date(11), minutes: 5, unit: other)
        ])
        XCTAssertEqual(map[unit], date(14))
        XCTAssertEqual(map[other], date(11))
    }

    func testLastPracticedByUnitIsIndependentOfInputOrder() {
        // Built in one pass, not by sorting — so an unordered log must give the same answer.
        let unit = UUID()
        let ordered = PracticeLog.lastPracticedByUnit([
            run(date(10), minutes: 5, unit: unit), run(date(16), minutes: 5, unit: unit)
        ])
        let reversed = PracticeLog.lastPracticedByUnit([
            run(date(16), minutes: 5, unit: unit), run(date(10), minutes: 5, unit: unit)
        ])
        XCTAssertEqual(ordered[unit], date(16))
        XCTAssertEqual(reversed[unit], date(16))
    }

    func testLastPracticedByUnitCountsEveryKindOfRunOnTheSameUnit() {
        // ADR 0137 D2a — a loop sung back in ear training is not "untouched" as a trainer. The mode
        // is deliberately not distinguished; the question is when you last worked on the material.
        let loop = UUID()
        let map = PracticeLog.lastPracticedByUnit([
            run(date(10), minutes: 5, kind: .loop, unit: loop),
            run(date(15), minutes: 5, kind: .earLoop, unit: loop)
        ])
        XCTAssertEqual(map[loop], date(15))
    }

    func testLastPracticedByUnitSkipsRowsWithNoUnit() {
        // A play-along logs `unitUID: nil` — Song has no business `uid` (ADR 0117). Such a row can
        // say nothing about any unit and must not become a key.
        let unit = UUID()
        let map = PracticeLog.lastPracticedByUnit([
            run(date(10), minutes: 30, kind: .song, unit: nil),
            run(date(11), minutes: 5, unit: unit)
        ])
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map[unit], date(11))
    }

    func testLastPracticedByUnitOnAnEmptyLogIsEmpty() {
        // Which reads back as `nil` per unit — cold-start max-due, the correct answer for a fresh
        // install where nothing has been practised yet.
        XCTAssertTrue(PracticeLog.lastPracticedByUnit([]).isEmpty)
    }
}
