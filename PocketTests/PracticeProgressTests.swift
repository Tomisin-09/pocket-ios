import XCTest
@testable import Pocket

/// The Progress screen's three horizons (ADR 0117, Slice 2). The view does no arithmetic, so
/// everything worth getting wrong is here: which window each horizon takes, what the empty cases
/// report, and the deliberate absences — no target, no denominator, no year tier.
final class PracticeProgressTests: XCTestCase {

    private let drill = UUID()

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        calendar.firstWeekday = 2      // Monday-first, so week boundaries are a fact not a locale
        return calendar
    }()

    /// Every horizon is taken as of 2026-06-10 — a Wednesday, so its Monday-first week runs
    /// 8th → 15th, inside a 30-day June with a 31-day May either side of the boundary tests.
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))
            ?? .distantPast
    }

    private func run(_ month: Int, _ day: Int, minutes: Double, bpm: Int? = nil,
                     hour: Int = 12) -> SessionRecord {
        SessionRecord(startedAt: date(month, day, hour), durationSeconds: minutes * 60,
                      kind: .exercise, unitUID: drill, tempoBPM: bpm, notesPerBeat: 4)
    }

    private let emptyInventory = PracticeStats.Summary(loops: 0, exercises: 0,
                                                       fullMasteryCount: 0, notes: 0)

    private func summarize(_ records: [SessionRecord],
                           inventory: PracticeStats.Summary? = nil) -> PracticeProgress.Summary {
        PracticeProgress.summarize(records: records,
                                   inventory: inventory ?? emptyInventory,
                                   now: date(6, 10),
                                   calendar: calendar)
    }

    // MARK: - Empty

    func testAnEmptyLogReportsNoHistoryRatherThanZeroes() {
        let summary = summarize([])
        XCTAssertTrue(summary.hasNoHistory)
        XCTAssertTrue(summary.week.isEmpty)
        XCTAssertTrue(summary.month.isEmpty)
        XCTAssertNil(summary.allTime.lifetime.since)
    }

    func testAnEmptyWeekStillYieldsSevenBucketsToDraw() {
        // History exists, but none of it this week — the chart must keep its shape rather than vanish.
        let summary = summarize([run(4, 2, minutes: 30)])
        XCTAssertFalse(summary.hasNoHistory)
        XCTAssertTrue(summary.week.isEmpty)
        XCTAssertEqual(summary.week.days.count, 7)
        XCTAssertEqual(summary.week.peakMinutes, 1, "an all-zero week must not divide by zero")
    }

    // MARK: - This week

    func testTheWeekWindowIsTheCalendarWeekContainingNow() {
        let records = [run(6, 7, minutes: 60),    // Sunday — the week before
                       run(6, 8, minutes: 20),    // Monday — in
                       run(6, 10, minutes: 25),   // Wednesday — in
                       run(6, 15, minutes: 60)]   // the following Monday — out
        let week = summarize(records).week
        XCTAssertEqual(week.minutes, 45)
        XCTAssertEqual(week.daysActive, 2)
    }

    func testDaysActiveIsABareCountWithNoDenominator() {
        // ADR 0117 holds "4 of 7" with the deferred streaks; the type must not carry a target at all.
        let week = summarize([run(6, 8, minutes: 10), run(6, 9, minutes: 10)]).week
        XCTAssertEqual(week.daysActive, 2)
        XCTAssertEqual(Mirror(reflecting: week).children.compactMap(\.label).sorted(),
                       ["days", "daysActive", "interval", "minutes"])
    }

    func testWeekPeakDrivesTheBarScale() {
        let week = summarize([run(6, 8, minutes: 10), run(6, 9, minutes: 42)]).week
        XCTAssertEqual(week.peakMinutes, 42)
    }

    func testEveryKindOfPracticeCountsTowardsTimeAndDays() {
        // Ear training and a play-along are practice: they earn their minutes and their day, even
        // though neither carries a tempo. This is what the ear/song write seams exist for.
        let records = [run(6, 8, minutes: 20),
                       SessionRecord(startedAt: date(6, 9), durationSeconds: 15 * 60, kind: .earLoop),
                       SessionRecord(startedAt: date(6, 10), durationSeconds: 25 * 60, kind: .song)]
        let week = summarize(records).week
        XCTAssertEqual(week.minutes, 60)
        XCTAssertEqual(week.daysActive, 3)
    }

    func testEarAndSongRunsNeverEnterTheTempoCount() {
        // They carry no tempo, so they can neither set a new one nor mask an exercise's.
        let records = [SessionRecord(startedAt: date(6, 8), durationSeconds: 600, kind: .earLoop,
                                     unitUID: drill, tempoBPM: 200, notesPerBeat: 4),
                       SessionRecord(startedAt: date(6, 9), durationSeconds: 600, kind: .song,
                                     tempoBPM: 300, notesPerBeat: 4),
                       run(6, 10, minutes: 10, bpm: 76),
                       run(6, 11, minutes: 10, bpm: 84)]
        XCTAssertEqual(summarize(records).month.newTempos, 1, "only the exercise pair can set one")
    }

    // MARK: - This month

    func testTheMonthWindowIsTheCalendarMonthContainingNow() {
        let records = [run(5, 31, minutes: 60), run(6, 1, minutes: 20), run(6, 30, minutes: 25)]
        let month = summarize(records).month
        XCTAssertEqual(month.minutes, 45)
        XCTAssertEqual(month.days.count, 30, "June has 30 days")
    }

    func testMonthReportsItsLongestDay() {
        let records = [run(6, 3, minutes: 20), run(6, 12, minutes: 55), run(6, 20, minutes: 30)]
        XCTAssertEqual(summarize(records).month.bestDay?.minutes, 55)
    }

    func testNewTemposThisMonthAreCountedAgainstAllHistory() {
        // May already reached 120, so June's 100 is not new — only the 124 is.
        let records = [run(5, 1, minutes: 10, bpm: 90),
                       run(5, 2, minutes: 10, bpm: 120),
                       run(6, 3, minutes: 10, bpm: 100),
                       run(6, 4, minutes: 10, bpm: 124)]
        XCTAssertEqual(summarize(records).month.newTempos, 1)
    }

    // MARK: - All-time

    func testAllTimeRollsUpHoursSessionsAndStartDate() {
        let records = [run(5, 1, minutes: 40, hour: 9),
                       run(5, 1, minutes: 35, hour: 10),   // same sit
                       run(6, 3, minutes: 50, hour: 9)]
        let allTime = summarize(records).allTime
        XCTAssertEqual(allTime.lifetime.sittingCount, 2)
        XCTAssertEqual(allTime.lifetime.minutes, 125)
        XCTAssertEqual(allTime.lifetime.hours, 2)
        XCTAssertEqual(allTime.lifetime.since, date(5, 1, 9))
    }

    /// The invariant the three horizons have to satisfy *as displayed*, not just internally: all-time
    /// contains the month, so the time it prints can never be less. This failed on a first month made
    /// of one 1h59m50s total — the month rounded to "120 minutes" and all-time floored to "1 hour".
    func testAllTimeNeverPrintsLessTimeThanTheMonthInsideIt() {
        let records = [run(6, 3, minutes: 60), run(6, 5, minutes: 40), run(6, 9, minutes: 19 + 50.0 / 60)]
        let summary = summarize(records)
        let lifetime = summary.allTime.lifetime
        XCTAssertEqual(summary.month.minutes, 120)
        XCTAssertEqual(lifetime.hours * 60 + lifetime.remainingMinutes, summary.month.minutes)
        XCTAssertGreaterThanOrEqual(lifetime.minutes, summary.month.minutes)
        XCTAssertGreaterThanOrEqual(summary.month.minutes, summary.week.minutes)
    }

    func testInventoryCountsArePassedThroughNotRecomputed() {
        let inventory = PracticeStats.Summary(loops: 12, exercises: 5, fullMasteryCount: 3, notes: 8)
        let allTime = summarize([run(6, 3, minutes: 10)], inventory: inventory).allTime
        XCTAssertEqual(allTime.inventory, inventory)
    }

    // MARK: - Milestones

    func testEveryMilestoneIsAlwaysPresentSoTheWallDoesNotRearrange() {
        let milestones = PracticeProgress.milestones(forHours: 0)
        XCTAssertEqual(milestones.map(\.hours), PracticeProgress.hourMilestones)
        XCTAssertTrue(milestones.allSatisfy { !$0.isReached })
    }

    func testAMilestoneIsReachedAtItsExactHour() {
        XCTAssertEqual(PracticeProgress.milestones(forHours: 10).filter(\.isReached).map(\.hours), [10])
        XCTAssertEqual(PracticeProgress.milestones(forHours: 9).filter(\.isReached), [])
    }

    func testNextMilestoneIsNilOnceEveryOneIsBehindYou() {
        let allTime = PracticeProgress.AllTime(
            lifetime: .init(totalSeconds: 600 * 3600, sittingCount: 400, runCount: 900, since: .now),
            inventory: emptyInventory,
            milestones: PracticeProgress.milestones(forHours: 600))
        XCTAssertNil(allTime.nextMilestone)
    }

    func testNextMilestoneIsTheNearestOneAhead() {
        let allTime = PracticeProgress.allTime(records: [run(6, 3, minutes: 60 * 12)],
                                               inventory: emptyInventory)
        XCTAssertEqual(allTime.lifetime.hours, 12)
        XCTAssertEqual(allTime.nextMilestone, 50)
    }
}
