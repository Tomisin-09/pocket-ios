import XCTest
@testable import Pocket

/// The **shape** fields of the context (ADR 0187 D22) — the order units were taken in, and the runs
/// that happened inside each version of a loop's span.
///
/// Its own class for the reason `OracleSnagContextTests` is: `OracleContextTests` reached the
/// type-body limit, and this is its own subject. The question every test here asks is D22's own —
/// *does this value mean anything without a second value?* — because a field that fails it is a
/// comparison, and a comparison does not cross.
@MainActor
final class OracleShapeContextTests: XCTestCase {

    private let windowStart = Date(timeIntervalSince1970: 1_724_889_600) // Mon 29 Aug 2024, UTC

    private var window: DateInterval { DateInterval(start: windowStart, duration: 7 * 86_400) }

    private func at(_ dayOffset: Int, _ hour: Double) -> Date {
        windowStart.addingTimeInterval(Double(dayOffset) * 86_400 + hour * 3_600)
    }

    private func run(_ unit: UUID, at start: Date, minutes: Double = 10,
                     kind: PracticeRunKind = .exercise) -> SessionRecord {
        SessionRecord(startedAt: start, durationSeconds: minutes * 60, kind: kind, unitUID: unit)
    }

    private func build(_ source: OracleContextSource) -> OracleContext {
        OracleContextBuilder.build(from: source,
                                   window: window,
                                   promptVersion: "test-1",
                                   now: at(7, 0),
                                   calendar: Calendar(identifier: .gregorian)).context
    }

    private func exercise(_ name: String) -> Exercise {
        let exercise = Exercise(name: name)
        exercise.template = .scales
        return exercise
    }

    private func loop(_ name: String) -> Loop {
        let song = Song(title: "Slow Bend", artist: "Jack Trader", duration: 200,
                        ref: SongRef(id: "song-1", source: .localFile, bookmark: nil))
        let made = Loop(name: name, start: 0.25, end: 0.35, speed: 0.75, repeats: 4)
        made.song = song
        return made
    }

    // MARK: - The order units were taken in

    /// **The test that justifies the field existing.** `units` is ordered by minutes descending,
    /// because that is the order D6 R1's handles are minted from — so if a sitting's sequence were
    /// recoverable from the unit list it would be a restatement of the array index and not worth
    /// sending. Here the short drill was taken *first* and the long one second, so the two orders
    /// disagree, and only the sitting knows which one actually happened.
    func testASittingRecordsTheOrderRunsStartedNotTheOrderUnitsAreListedIn() throws {
        let brief = exercise("Warm-up")
        let long = exercise("Bend study")
        var source = OracleContextSource()
        source.exercises = [brief, long]
        source.records = [run(brief.uid, at: at(1, 9), minutes: 5),
                          run(long.uid, at: at(1, 9.25), minutes: 45)]

        let context = build(source)
        let handles = Dictionary(uniqueKeysWithValues: context.units.map { ($0.name, $0.handle) })
        let sitting = try XCTUnwrap(context.sittings.first)

        XCTAssertEqual(context.units.map(\.name), ["Bend study", "Warm-up"],
                       "Precondition: units are ordered by minutes, longest first")
        XCTAssertEqual(sitting.handles, [handles["Warm-up"], handles["Bend study"]].compactMap { $0 },
                       "The sitting reported the minutes order rather than the order it happened in")
        XCTAssertEqual(context.sittings.count, 1)
    }

    /// A gap of `PracticeLog.sittingGap` starts a new sitting, measured from the previous run's
    /// **end** — the rule `PracticeLogTests` pins, and this must not be a second implementation of
    /// it that drifts.
    func testAGapSplitsASittingAndTheCountAgreesWithTheSequences() {
        let drill = exercise("Bend study")
        var source = OracleContextSource()
        source.exercises = [drill]
        source.records = [run(drill.uid, at: at(1, 9), minutes: 20),
                          // Ends 09:20; this starts 09:40, a 20-minute gap — still one sitting.
                          run(drill.uid, at: at(1, 9.667), minutes: 10),
                          // Ends 09:50; this starts 18:00 — a second sitting.
                          run(drill.uid, at: at(1, 18), minutes: 15)]

        let context = build(source)

        XCTAssertEqual(context.sittings.count, 2)
        XCTAssertEqual(context.effort.sittings, context.sittings.count,
                       "The count and the sequences disagree about what a sitting is")
    }

    /// Consecutive runs of the same drill collapse; **coming back to it later does not.** A routine
    /// block logs one row per run, so without the collapse a warm-up run three times in a row would
    /// print as three steps — volume wearing the clothes of order. The return at the end is the
    /// shape D22 is actually after, and it survives.
    func testConsecutiveRepeatsCollapseButAReturnSurvives() throws {
        let warmUp = exercise("Warm-up")
        let study = exercise("Bend study")
        var source = OracleContextSource()
        source.exercises = [warmUp, study]
        source.records = [run(warmUp.uid, at: at(2, 9), minutes: 2),
                          run(warmUp.uid, at: at(2, 9.1), minutes: 2),
                          run(warmUp.uid, at: at(2, 9.2), minutes: 2),
                          run(study.uid, at: at(2, 9.3), minutes: 30),
                          run(warmUp.uid, at: at(2, 9.9), minutes: 2)]

        let sitting = try XCTUnwrap(build(source).sittings.first)

        XCTAssertEqual(sitting.handles.count, 3, "Expected warm-up, study, warm-up: \(sitting.handles)")
        XCTAssertEqual(sitting.handles.first, sitting.handles.last,
                       "The return to the warm-up was collapsed away with the repeats")
        XCTAssertNotEqual(sitting.handles[0], sitting.handles[1])
    }

    /// A row that names no unit — `.other`, written by a newer build — and a unit past `maxUnits`
    /// both leave a step with no honest token to print. It is dropped rather than blanked, and a
    /// sitting with nothing left to name is dropped whole, because an empty sequence reads as a
    /// fault rather than as a quiet day.
    func testRunsWithNoNameableUnitAreDroppedAndAnEmptySittingWithThem() {
        var source = OracleContextSource()
        source.records = [SessionRecord(startedAt: at(1, 9), durationSeconds: 600, kind: .other)]

        let context = build(source)

        XCTAssertEqual(context.effort.runs, 1, "Precondition: the run is in the window")
        XCTAssertTrue(context.sittings.isEmpty)
    }

    // MARK: - Runs inside a span

    /// The join D22 needs: each edit closes an epoch, and the runs logged while the span stood at
    /// the earlier width belong to the row that closed it. The runs since the last edit have no row
    /// to sit on and are returned separately.
    func testEachSpanEditCarriesTheRunsLoggedWhileThatSpanStood() throws {
        let passage = loop("Chorus turnaround")
        for (index, changedOn) in [at(2, 12), at(4, 12)].enumerated() {
            let change = LoopSpanChange(changedAt: changedOn,
                                        start: 0.2 + Double(index) * 0.05, end: 0.4,
                                        previousStart: 0.1, previousEnd: 0.5,
                                        speed: 0.8, songDuration: 200)
            change.loop = passage
        }

        var source = OracleContextSource()
        source.loops = [passage]
        source.records = [run(passage.uid, at: at(1, 9), kind: .loop),   // before the first edit
                          run(passage.uid, at: at(3, 9), kind: .loop),   // between the two
                          run(passage.uid, at: at(3, 15), kind: .loop),  // between the two
                          run(passage.uid, at: at(5, 9), kind: .loop),   // after the last
                          run(passage.uid, at: at(6, 9), kind: .loop)]   // after the last

        let unit = try XCTUnwrap(build(source).units.first)

        XCTAssertEqual(unit.spans.map(\.runsInPreviousSpan), [1, 2])
        XCTAssertEqual(unit.runsInCurrentSpan, 2)
    }

    /// A loop nobody has edited has all of its runs in the open epoch. ADR 0199 writes no row at
    /// loop creation, so this is also every loop that predates it.
    func testALoopWithNoRecordedEditsHasAllOfItsRunsInTheCurrentSpan() throws {
        let passage = loop("Intro")
        var source = OracleContextSource()
        source.loops = [passage]
        source.records = [run(passage.uid, at: at(1, 9), kind: .loop),
                          run(passage.uid, at: at(2, 9), kind: .loop)]

        let unit = try XCTUnwrap(build(source).units.first)

        XCTAssertTrue(unit.spans.isEmpty)
        XCTAssertEqual(unit.runsInCurrentSpan, 2)
        XCTAssertEqual(unit.droppedSpans, 0)
    }

    /// An edit with no recorded `songDuration` cannot be stated in seconds and is left out — the
    /// behaviour ADR 0204 already had. What D22 adds is that it must now be **counted**: the row
    /// takes its epoch's runs with it, and a list that looked complete would pour three epochs of
    /// runs into two.
    func testADroppedEditIsCountedSoTheRunsItTookWithItAreNotSilent() throws {
        let passage = loop("Chorus turnaround")
        let unusable = LoopSpanChange(changedAt: at(2, 12), start: 0.2, end: 0.4,
                                      previousStart: 0.1, previousEnd: 0.5,
                                      speed: nil, songDuration: nil)
        unusable.loop = passage
        let usable = LoopSpanChange(changedAt: at(4, 12), start: 0.25, end: 0.35,
                                    previousStart: 0.2, previousEnd: 0.4,
                                    speed: 0.8, songDuration: 200)
        usable.loop = passage

        var source = OracleContextSource()
        source.loops = [passage]
        source.records = [run(passage.uid, at: at(1, 9), kind: .loop),
                          run(passage.uid, at: at(3, 9), kind: .loop)]

        let unit = try XCTUnwrap(build(source).units.first)

        XCTAssertEqual(unit.spans.count, 1)
        XCTAssertEqual(unit.droppedSpans, 1, "The unusable row vanished without saying so")
        XCTAssertEqual(unit.spans.first?.runsInPreviousSpan, 1,
                       "The run between the two edits belongs to the row that closed its epoch")
        XCTAssertEqual(unit.runsInCurrentSpan, 0)
    }

    /// The span history is drawn from the **whole log**, not the window — a span that has stood
    /// since March did not start standing on Monday. Same scope as the tempo trajectory and the
    /// snag map, and the counts would otherwise all be counts of this week.
    func testTheRunsInsideASpanAreCountedFromTheWholeLogNotTheWindow() throws {
        let passage = loop("Chorus turnaround")
        let change = LoopSpanChange(changedAt: at(2, 12), start: 0.2, end: 0.4,
                                    previousStart: 0.1, previousEnd: 0.5,
                                    speed: 0.8, songDuration: 200)
        change.loop = passage

        var source = OracleContextSource()
        source.loops = [passage]
        source.records = [run(passage.uid, at: at(-30, 9), kind: .loop),
                          run(passage.uid, at: at(-20, 9), kind: .loop),
                          run(passage.uid, at: at(1, 9), kind: .loop)]

        let unit = try XCTUnwrap(build(source).units.first)

        XCTAssertEqual(unit.runs, 1, "Precondition: only one run is inside the window")
        XCTAssertEqual(unit.spans.first?.runsInPreviousSpan, 3,
                       "The epoch count was clipped to the window")
    }
}
