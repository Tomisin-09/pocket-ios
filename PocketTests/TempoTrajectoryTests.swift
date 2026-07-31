import XCTest
@testable import Pocket

/// The per-exercise tempo trajectory (ADR 0117) — the unit-level read that per-unit-run logging
/// exists to make possible. The rhythm-grouping rule (ADR 0121) is the part that fails silently if
/// wrong: it would plot a rhythm change as progress that never happened.
final class TempoTrajectoryTests: XCTestCase {

    private let drill = UUID()
    private let otherDrill = UUID()

    private func date(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        return calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 12))
            ?? .distantPast
    }

    private func run(_ day: Int, unit: UUID, bpm: Int? = nil, perBeat: Int? = 4,
                     kind: PracticeRunKind = .exercise) -> SessionRecord {
        SessionRecord(startedAt: date(day), durationSeconds: 300, kind: kind,
                      unitUID: unit, tempoBPM: bpm, notesPerBeat: perBeat)
    }

    func testTracesOneDrillsTemposInTimeOrder() {
        let records = [run(3, unit: drill, bpm: 76),
                       run(10, unit: drill, bpm: 88),
                       run(17, unit: drill, bpm: 104)]
        let reading = TempoTrajectory.reading(for: drill, in: records.reversed())
        XCTAssertEqual(reading?.points.map(\.bpm), [76, 88, 104])
        XCTAssertEqual(reading?.first.bpm, 76)
        XCTAssertEqual(reading?.latest.bpm, 104)
        XCTAssertEqual(reading?.change, 28)
    }

    func testIgnoresOtherDrillsRuns() {
        let records = [run(3, unit: drill, bpm: 76),
                       run(4, unit: otherDrill, bpm: 200),
                       run(10, unit: drill, bpm: 88)]
        XCTAssertEqual(TempoTrajectory.reading(for: drill, in: records)?.points.map(\.bpm), [76, 88])
    }

    func testOnlyTheMostRecentRhythmIsPlotted() {
        // Three runs at eighths, then two at sixteenths. Plotting all five would read the rhythm
        // change from 120 → 80 as a collapse (ADR 0121).
        let records = [run(1, unit: drill, bpm: 100, perBeat: 2),
                       run(2, unit: drill, bpm: 110, perBeat: 2),
                       run(3, unit: drill, bpm: 120, perBeat: 2),
                       run(4, unit: drill, bpm: 80, perBeat: 4),
                       run(5, unit: drill, bpm: 88, perBeat: 4)]
        let reading = TempoTrajectory.reading(for: drill, in: records)
        XCTAssertEqual(reading?.points.map(\.bpm), [80, 88])
        XCTAssertEqual(reading?.noteRate, .sixteenths)
        XCTAssertEqual(reading?.otherRhythmRuns, 3, "the set-aside runs are admitted, not hidden")
    }

    func testAnUnstatedRhythmIsItsOwnGroupNotQuarters() {
        // A chord-changing drill states no rate; it must not be compared against a run that declared
        // quarters, because "unstated" is not a claim of one note per beat.
        let records = [run(1, unit: drill, bpm: 60, perBeat: 1),
                       run(2, unit: drill, bpm: 70, perBeat: nil),
                       run(3, unit: drill, bpm: 76, perBeat: nil)]
        let reading = TempoTrajectory.reading(for: drill, in: records)
        XCTAssertEqual(reading?.points.map(\.bpm), [70, 76])
        XCTAssertNil(reading?.noteRate)
        XCTAssertEqual(reading?.otherRhythmRuns, 1)
    }

    func testASingleRunIsNotATrajectory() {
        XCTAssertNil(TempoTrajectory.reading(for: drill, in: [run(1, unit: drill, bpm: 76)]),
                     "one point implies a direction it hasn't earned")
    }

    func testRunsWithNoLoggedTempoAreNotPlotted() {
        let records = [run(1, unit: drill, bpm: nil), run(2, unit: drill, bpm: nil)]
        XCTAssertNil(TempoTrajectory.reading(for: drill, in: records))
    }

    func testLoopRunsNeverEnterAnExercisesTempoLine() {
        // A loop's tempo is a percent of original, not a BPM (ADR 0082) — different axis entirely.
        let records = [run(1, unit: drill, bpm: 76),
                       run(2, unit: drill, bpm: 88, kind: .loop),
                       run(3, unit: drill, bpm: 92)]
        XCTAssertEqual(TempoTrajectory.reading(for: drill, in: records)?.points.map(\.bpm), [76, 92])
    }

    func testADownwardTrajectoryIsReportedPlainly() {
        // ADR 0070: a slower day is a fact, not a regression the app names.
        let records = [run(1, unit: drill, bpm: 104), run(2, unit: drill, bpm: 92)]
        let reading = TempoTrajectory.reading(for: drill, in: records)
        XCTAssertEqual(reading?.change, -12)
        XCTAssertEqual(reading?.lowest, 92)
        XCTAssertEqual(reading?.highest, 104)
    }

    func testRunCountIncludesRunsWithNoTempo() {
        let records = [run(1, unit: drill, bpm: 76),
                       run(2, unit: drill, bpm: nil),
                       run(3, unit: otherDrill, bpm: 90)]
        XCTAssertEqual(TempoTrajectory.runCount(for: drill, in: records), 2,
                       "showing up counts even when no tempo was stated")
    }
}
