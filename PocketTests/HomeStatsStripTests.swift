import SwiftData
import XCTest
@testable import Pocket

/// Home's *This week* strip fetches only this week's rows (1.5, item 2a). What could go wrong is
/// silent: a predicate that drops a run on the week's first instant, or keeps last week's last one,
/// still draws three plausible numbers. These run the strip's own descriptors through a real store
/// and check the week they produce is the week the whole history produces.
@MainActor
final class HomeStatsStripTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        calendar.firstWeekday = 2      // Monday-first, so the boundary is a fact, not a locale
        return calendar
    }()

    /// Wednesday 2026-06-10, so the week runs Monday the 8th to Monday the 15th.
    private var now: Date { date(6, 10, hour: 12) }
    private var weekStart: Date { date(6, 8) }

    private func date(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))
            ?? .distantPast
    }

    /// Held so the store outlives the context made from it.
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: PracticeRun.self, JournalEntry.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        self.container = container
        return ModelContext(container)
    }

    private func insertRun(_ startedAt: Date, minutes: Double, in context: ModelContext) {
        context.insert(PracticeRun(startedAt: startedAt, durationSeconds: minutes * 60,
                                   kind: .exercise, unitUID: UUID()))
    }

    private func insertNote(_ createdAt: Date, in context: ModelContext) {
        context.insert(JournalEntry(text: "note", kind: .note, masteryAtEntry: nil,
                                    commandTempoAtEntry: nil, createdAt: createdAt))
    }

    func testWeekFromTheFetchMatchesTheWeekFromEveryRun() throws {
        let context = try makeContext()
        insertRun(date(1, 3, hour: 9), minutes: 40, in: context)            // months back
        insertRun(weekStart.addingTimeInterval(-1), minutes: 30, in: context) // last week's last second
        insertRun(weekStart, minutes: 10, in: context)                        // this week's first instant
        insertRun(date(6, 9, hour: 18), minutes: 25, in: context)
        insertRun(date(6, 10, hour: 8), minutes: 5, in: context)
        try context.save()

        let fetched = try context.fetch(HomeStatsStrip.weekRuns(now: now, calendar: calendar))
        let everything = try context.fetch(FetchDescriptor<PracticeRun>())

        XCTAssertEqual(fetched.count, 3, "the week's first instant is in; the second before it is out")
        XCTAssertEqual(
            PracticeProgress.week(records: fetched.map(\.record), now: now, calendar: calendar),
            PracticeProgress.week(records: everything.map(\.record), now: now, calendar: calendar))
        XCTAssertEqual(PracticeProgress.week(records: fetched.map(\.record), now: now,
                                             calendar: calendar).minutes, 40)
    }

    func testNotesFetchStartsWhereTheWeekStarts() throws {
        let context = try makeContext()
        insertNote(weekStart.addingTimeInterval(-1), in: context)
        insertNote(weekStart, in: context)
        insertNote(date(6, 10, hour: 9), in: context)
        try context.save()

        let fetched = try context.fetch(HomeStatsStrip.weekNotes(now: now, calendar: calendar))
        let interval = PracticeLog.weekInterval(containing: now, calendar: calendar)

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(PracticeLog.count(fetched.map(\.createdAt), in: interval), 2)
    }

    /// The fetch has no upper bound on purpose: if Home stays open into a new week, the strip's
    /// predicate is still last week's, and the new week's runs have to be in what it fetched.
    func testAStripBuiltLastWeekStillHoldsThisWeeksRuns() throws {
        let context = try makeContext()
        insertRun(date(6, 16, hour: 7), minutes: 15, in: context)   // the following Tuesday
        try context.save()

        let builtLastWeek = try context.fetch(HomeStatsStrip.weekRuns(now: now, calendar: calendar))
        let nextWeek = PracticeProgress.week(records: builtLastWeek.map(\.record),
                                             now: date(6, 16, hour: 20), calendar: calendar)

        XCTAssertEqual(nextWeek.minutes, 15)
    }

    /// A quiet week after earlier practice still shows the strip: its guard is lifetime emptiness,
    /// which this week's fetch can't answer, so it asks for one row of any date.
    func testTheGuardSeesAnOldRunWhenTheWeekIsEmpty() throws {
        let context = try makeContext()
        XCTAssertTrue(try context.fetch(HomeStatsStrip.anyRunDescriptor).isEmpty)

        insertRun(date(1, 3, hour: 9), minutes: 40, in: context)
        try context.save()

        XCTAssertTrue(try context.fetch(HomeStatsStrip.weekRuns(now: now, calendar: calendar)).isEmpty)
        XCTAssertEqual(try context.fetch(HomeStatsStrip.anyRunDescriptor).count, 1)
    }
}
