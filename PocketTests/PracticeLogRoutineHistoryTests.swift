import XCTest
@testable import Pocket

/// What the log remembers about one **routine** (ADR 0173) — the read that `PracticeRun.routineUID`
/// waited for since ADR 0117 wrote it and nothing read it back.
///
/// Split out of `PracticeLogTests` on the file-length cap, and the split is a fair one: everything
/// here turns on a distinction the rest of that file has no stake in — the log holds one row per
/// completed *block*, so a routine's history has to recover **sittings** rather than count rows.
///
/// Same fixed UTC/Monday calendar and the same row factory, so an assertion here means the same
/// thing it would there.
final class PracticeLogRoutineHistoryTests: XCTestCase {

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

    /// **The test this whole design exists for.** The log writes one row per completed *block*, so
    /// counting rows would report a single Tuesday morning as six separate practices — not a smaller
    /// number than the truth, a different fact. Fails immediately against a naive row count.
    func testARoutineRunCountsOnceHoweverManyBlocksItHas() {
        let routine = UUID()
        var records: [SessionRecord] = []
        for index in 0..<6 {
            records.append(run(date(10, 9, index * 6), minutes: 5, routine: routine))
        }
        let history = PracticeLog.routineHistory(for: routine, in: records)
        XCTAssertEqual(history.sessionCount, 1,
                       "six blocks back to back is one practice, not six")
        XCTAssertEqual(history.lastPracticed, date(10, 9, 30))
    }

    func testTheSameRoutineRunMorningAndEveningCountsTwice() {
        // Nine hours apart is well past `sittingGap`, so these are two sits and the count is a
        // sitting count rather than a day count.
        let routine = UUID()
        let history = PracticeLog.routineHistory(for: routine, in: [
            run(date(10, 8), minutes: 15, routine: routine),
            run(date(10, 17), minutes: 15, routine: routine)
        ])
        XCTAssertEqual(history.sessionCount, 2)
        XCTAssertEqual(history.lastPracticed, date(10, 17), "the latest run is the one shown")
    }

    func testAnotherRoutinesRunsAndStandaloneRunsAreNotCounted() {
        // A `nil` routineUID is a standalone run and says nothing about any routine — the same rule
        // `lastPracticedByUnit` follows for rows that name no unit.
        let routine = UUID()
        let history = PracticeLog.routineHistory(for: routine, in: [
            run(date(9, 9), minutes: 20, routine: UUID()),
            run(date(11, 9), minutes: 20),
            run(date(10, 9), minutes: 20, routine: routine)
        ])
        XCTAssertEqual(history.sessionCount, 1, "only this routine's own rows count")
        XCTAssertEqual(history.lastPracticed, date(10, 9),
                       "a later run of a *different* routine must not become this one's date")
    }

    func testARoutineNeverRunHasNoDateAndNoCount() {
        // The state the "Not yet" copy renders — asserted against a non-empty log, so an empty
        // answer is attribution working rather than there being nothing to find.
        let history = PracticeLog.routineHistory(for: UUID(), in: [
            run(date(10, 9), minutes: 20, routine: UUID())
        ])
        XCTAssertNil(history.lastPracticed)
        XCTAssertEqual(history.sessionCount, 0)
        XCTAssertTrue(history.isEmpty)
    }

    func testTheLatestRunWinsWhateverOrderTheRowsArriveIn() {
        // `@Query` order is not a guarantee this function may lean on.
        let routine = UUID()
        let records = [run(date(10, 9), minutes: 10, routine: routine),
                       run(date(14, 9), minutes: 10, routine: routine)]
        XCTAssertEqual(PracticeLog.routineHistory(for: routine, in: records).lastPracticed,
                       PracticeLog.routineHistory(for: routine, in: records.reversed()).lastPracticed)
    }

    func testSessionCountsBucketEachRoutineSeparately() {
        let morning = UUID()
        let evening = UUID()
        let counts = PracticeLog.routineSessionCounts(in: [
            run(date(10, 9), minutes: 5, routine: morning),
            run(date(10, 9, 6), minutes: 5, routine: morning),   // same sit as above
            run(date(12, 9), minutes: 5, routine: morning),      // a second sit
            run(date(10, 9), minutes: 5, routine: evening)
        ])
        XCTAssertEqual(counts[morning], 2, "two sittings, four rows")
        XCTAssertEqual(counts[evening], 1)
    }

    /// A routine with no runs is **absent**, not present with a zero — the library row reads this map
    /// and omits the tally entirely at that point rather than printing "practised 0 times".
    func testSessionCountsOmitRoutinesThatWereNeverRun() {
        let counts = PracticeLog.routineSessionCounts(in: [
            run(date(10, 9), minutes: 5, routine: UUID()),
            run(date(10, 9), minutes: 5)
        ])
        XCTAssertEqual(counts.count, 1, "the standalone row must not create a key")
        XCTAssertNil(counts[UUID()])
    }

    /// The map and the single-routine read must never disagree — they are the same fact on two
    /// screens, and the list one exists only to avoid rescanning the log per row.
    func testSessionCountsAgreeWithTheSingleRoutineRead() {
        let routine = UUID()
        let records = [run(date(10, 8), minutes: 5, routine: routine),
                       run(date(10, 17), minutes: 5, routine: routine),
                       run(date(11, 9), minutes: 5, routine: UUID())]
        XCTAssertEqual(PracticeLog.routineSessionCounts(in: records)[routine],
                       PracticeLog.routineHistory(for: routine, in: records).sessionCount)
    }

    func testLastPractisedIsPerRoutineAndSkipsStandaloneRows() {
        let morning = UUID()
        let evening = UUID()
        let dates = PracticeLog.routineLastPractised(in: [
            run(date(9, 9), minutes: 5, routine: morning),
            run(date(14, 9), minutes: 5, routine: morning),
            run(date(20, 9), minutes: 5),                      // standalone — names no routine
            run(date(11, 9), minutes: 5, routine: evening)
        ])
        XCTAssertEqual(dates[morning], date(14, 9), "the latest run of *that* routine")
        XCTAssertEqual(dates[evening], date(11, 9))
        XCTAssertEqual(dates.count, 2, "a standalone row must not become a key")
    }

    /// The two list maps must agree with the single-routine read on both facts, or the library row
    /// and the detail screen state different things about the same routine.
    func testTheListMapsAgreeWithTheSingleRoutineRead() {
        let routine = UUID()
        let records = [run(date(10, 8), minutes: 5, routine: routine),
                       run(date(10, 17), minutes: 5, routine: routine)]
        let history = PracticeLog.routineHistory(for: routine, in: records)
        XCTAssertEqual(PracticeLog.routineSessionCounts(in: records)[routine], history.sessionCount)
        XCTAssertEqual(PracticeLog.routineLastPractised(in: records)[routine], history.lastPracticed)
    }

    /// The companion to `testRoutineAttributionDoesNotChangeAnyAggregate`: `routineHistory` reads
    /// `routineUID` and every shared aggregate still does not. Pins that this landed as an addition
    /// rather than a change to what the field means to the rest of the file.
    func testRoutineHistoryLeavesTheSharedAggregatesAlone() {
        let unit = UUID()
        let routine = UUID()
        let inRoutine = [run(date(10, 9), minutes: 20, unit: unit, routine: routine)]
        let standalone = [run(date(10, 9), minutes: 20, unit: unit)]

        XCTAssertEqual(PracticeLog.routineHistory(for: routine, in: inRoutine).sessionCount, 1)
        XCTAssertEqual(PracticeLog.routineHistory(for: routine, in: standalone).sessionCount, 0)

        XCTAssertEqual(PracticeLog.totalMinutes(inRoutine), PracticeLog.totalMinutes(standalone))
        XCTAssertEqual(PracticeLog.sittings(inRoutine).count, PracticeLog.sittings(standalone).count)
        XCTAssertEqual(PracticeLog.lastPracticedByUnit(inRoutine)[unit],
                       PracticeLog.lastPracticedByUnit(standalone)[unit])
    }
}
