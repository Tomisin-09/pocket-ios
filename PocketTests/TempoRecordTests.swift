import XCTest
@testable import Pocket

/// "Faster than you'd played it before" (ADR 0117). Two rules break silently if wrong: a new tempo is
/// measured against **all** history rather than the window it's displayed in, and the ceiling is
/// **per rhythm** (ADR 0121), so a rhythm change can neither fake one nor hide one.
final class TempoRecordTests: XCTestCase {

    private let drill = UUID()
    private let otherDrill = UUID()

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        return calendar
    }()

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))
            ?? .distantPast
    }

    private func run(_ month: Int, _ day: Int, unit: UUID, bpm: Int, perBeat: Int? = 4,
                     kind: PracticeRunKind = .exercise) -> SessionRecord {
        SessionRecord(startedAt: date(month, day), durationSeconds: 300, kind: kind,
                      unitUID: unit, tempoBPM: bpm, notesPerBeat: perBeat)
    }

    func testTheFirstRunAtARhythmIsNotANewTempo() {
        let entries = TempoRecord.entries(in: [run(6, 1, unit: drill, bpm: 76)])
        XCTAssertTrue(entries.isEmpty, "there was nothing to have beaten")
    }

    func testOnlyRunsThatExceedEveryEarlierOneCount() {
        let records = [run(6, 1, unit: drill, bpm: 76),
                       run(6, 2, unit: drill, bpm: 80),   // new
                       run(6, 3, unit: drill, bpm: 78),   // not — below the ceiling
                       run(6, 4, unit: drill, bpm: 80),   // not — equal, not faster
                       run(6, 5, unit: drill, bpm: 84)]   // new
        let entries = TempoRecord.entries(in: records)
        XCTAssertEqual(entries.map(\.bpm), [80, 84])
        XCTAssertEqual(entries.map(\.previousBest), [76, 80])
    }

    func testEachDrillKeepsItsOwnCeiling() {
        let records = [run(6, 1, unit: drill, bpm: 120),
                       run(6, 2, unit: otherDrill, bpm: 60),
                       run(6, 3, unit: otherDrill, bpm: 64)]
        let entries = TempoRecord.entries(in: records)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.unitUID, otherDrill)
    }

    func testARhythmChangeNeitherFakesNorHidesANewTempo() {
        // Moving from eighths to sixteenths at a lower BPM is a harder drill, not a record — and the
        // sixteenths ceiling starts fresh rather than being compared against the eighths one.
        let records = [run(6, 1, unit: drill, bpm: 120, perBeat: 2),
                       run(6, 2, unit: drill, bpm: 80, perBeat: 4),
                       run(6, 3, unit: drill, bpm: 88, perBeat: 4),
                       run(6, 4, unit: drill, bpm: 124, perBeat: 2)]
        let entries = TempoRecord.entries(in: records)
        XCTAssertEqual(entries.map(\.bpm), [88, 124])
        XCTAssertEqual(entries.map { $0.noteRate?.perBeat }, [4, 2])
    }

    func testAnUnstatedRhythmKeepsItsOwnCeiling() {
        let records = [run(6, 1, unit: drill, bpm: 100, perBeat: 1),
                       run(6, 2, unit: drill, bpm: 70, perBeat: nil),
                       run(6, 3, unit: drill, bpm: 76, perBeat: nil)]
        XCTAssertEqual(TempoRecord.entries(in: records).map(\.bpm), [76])
    }

    func testWindowedCountIsMeasuredAgainstAllHistoryNotJustTheWindow() {
        // June tops out at 120. July's 100 is not new, even though it's the fastest run *in July* —
        // filtering before comparing would re-announce it every month.
        let records = [run(6, 1, unit: drill, bpm: 90),
                       run(6, 2, unit: drill, bpm: 120),
                       run(7, 1, unit: drill, bpm: 100),
                       run(7, 2, unit: drill, bpm: 124)]
        let july = PracticeLog.monthInterval(containing: date(7, 15), calendar: calendar)
        let entries = TempoRecord.entries(in: records, within: july)
        XCTAssertEqual(entries.map(\.bpm), [124])
    }

    func testLoopRunsAreNotOnTheExerciseTempoAxis() {
        let records = [run(6, 1, unit: drill, bpm: 76),
                       run(6, 2, unit: drill, bpm: 200, kind: .loop)]
        XCTAssertTrue(TempoRecord.entries(in: records).isEmpty)
    }

    func testEntriesAreReturnedOldestFirstRegardlessOfInputOrder() {
        let records = [run(6, 5, unit: drill, bpm: 84),
                       run(6, 1, unit: drill, bpm: 76),
                       run(6, 2, unit: drill, bpm: 80)]
        XCTAssertEqual(TempoRecord.entries(in: records).map(\.date), [date(6, 2), date(6, 5)])
    }
}
