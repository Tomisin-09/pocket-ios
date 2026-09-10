import XCTest
@testable import Pocket

/// The prose ADR 0187 D22 put in place of the volume mirror — the order paragraph, the span
/// paragraph, and the step-down clause on a tempo line.
///
/// Separate from `LocalOracleTests` because that class had reached SwiftLint's type-body limit, and
/// because this is one decision's worth of behaviour: **a structural fact names what and where; an
/// evaluation names how much, relative to something else.** Every assertion below is a reading of
/// that test.
@MainActor
final class LocalOracleShapeTests: XCTestCase {

    private let windowStart = Date(timeIntervalSince1970: 1_724_889_600)
    private var window: DateInterval { DateInterval(start: windowStart, duration: 7 * 86_400) }

    private func day(_ offset: Int) -> Date {
        windowStart.addingTimeInterval(Double(offset) * 86_400 + 36_000)
    }

    private var oracle: LocalOracle {
        var oracle = LocalOracle()
        oracle.calendar = Calendar(identifier: .gregorian)
        oracle.locale = Locale(identifier: "en_GB")
        return oracle
    }

    private func context(units: [OracleContext.Unit] = [],
                         sittings: [OracleContext.Sitting] = [],
                         runs: Int = 4) -> OracleContext {
        var context = OracleContext(promptVersion: "test-1",
                                    generatedAt: day(7),
                                    windowStart: window.start,
                                    windowEnd: window.end)
        context.units = units
        context.sittings = sittings
        context.effort = OracleContext.Effort(runs: runs, minutes: 130,
                                              daysPractised: [day(0), day(2)], sittings: 2)
        return context
    }

    private func drill(_ handle: String, _ name: String,
                       tempo: OracleContext.Tempo? = nil) -> OracleContext.Unit {
        OracleContext.Unit(handle: handle, name: name, kind: .exercise, template: "scales",
                           mastery: 3, tempo: tempo, runs: 2, minutes: 20, lastPractisedOn: day(2))
    }

    private func passage(_ handle: String, _ name: String,
                         spans: [OracleContext.SpanEdit] = [],
                         droppedSpans: Int = 0,
                         runsInCurrentSpan: Int = 0) -> OracleContext.Unit {
        OracleContext.Unit(handle: handle, name: name, kind: .loop, template: nil, mastery: 2,
                           tempo: nil, runs: 3, minutes: 12, lastPractisedOn: day(3),
                           spans: spans, droppedSpans: droppedSpans,
                           runsInCurrentSpan: runsInCurrentSpan)
    }

    private func edit(from: TimeInterval, to: TimeInterval, on offset: Int,
                      runsBefore: Int = 0) -> OracleContext.SpanEdit {
        OracleContext.SpanEdit(changedOn: day(offset), fromSeconds: from, toSeconds: to,
                               speed: 0.6, runsInPreviousSpan: runsBefore)
    }

    // MARK: - The order paragraph

    /// The word this paragraph exists for. Coming back to something later in the same sitting is
    /// the shape D22 is after, and it is invisible in every other view the app has.
    func testAReturnToSomethingLaterInTheSittingIsNamedAsAReturn() throws {
        let subject = context(units: [drill("u1", "Bend study"), drill("u2", "Warm-up")],
                              sittings: [.init(startedOn: day(2), handles: ["u2", "u1", "u2"])])

        let line = try XCTUnwrap(oracle.orderTaken(subject))

        XCTAssertTrue(line.contains("Warm-up, then Bend study, then Warm-up again"), line)
        XCTAssertNil(OracleToneGuard.check(line))
        XCTAssertNil(OracleFocusGuard.check(line))
    }

    /// A sitting with one step has no order to describe, and saying so anyway would be the opening
    /// paragraph again in different words.
    func testASittingWithASingleStepGetsNoParagraph() {
        let subject = context(units: [drill("u1", "Bend study")],
                              sittings: [.init(startedOn: day(2), handles: ["u1"])])
        XCTAssertNil(oracle.orderTaken(subject))
    }

    /// `maxUnits` caps the unit list, so a sitting can name a unit that did not make the payload.
    /// The step is dropped, never printed as a gap the reader is invited to guess at.
    func testAStepWhoseUnitIsNotInThePayloadIsDropped() throws {
        let subject = context(units: [drill("u1", "Bend study"), drill("u2", "Warm-up")],
                              sittings: [.init(startedOn: day(2), handles: ["u1", "u9", "u2"])])

        let line = try XCTUnwrap(oracle.orderTaken(subject))

        XCTAssertTrue(line.contains("Bend study, then Warm-up"), line)
        XCTAssertFalse(line.contains("u9"), "A raw handle reached the prose: \(line)")
    }

    // MARK: - The span paragraph

    /// Both widths, neither subtracted, and **no adjective**. The app derives *narrowed* elsewhere
    /// (`SpanHistory.Kind`); "from 34 seconds to 6" carries the direction without the app having
    /// put an opinion on it first.
    func testASpanIsStatedAsTwoWidthsAndNeverAsAVerdict() throws {
        let loop = passage("u1", "Chorus turnaround",
                           spans: [edit(from: 34, to: 6, on: 3, runsBefore: 4)],
                           runsInCurrentSpan: 9)

        let line = try XCTUnwrap(oracle.spanLines(context(units: [loop])).first)

        XCTAssertTrue(line.contains("34 seconds"), line)
        XCTAssertTrue(line.contains("6 seconds"), line)
        XCTAssertTrue(line.contains("4 runs"), line)
        XCTAssertTrue(line.contains("9 runs"), line)
        XCTAssertFalse(line.contains("the loop"),
                       "The line names the loop and then says 'the loop' again: \(line)")
        for verdict in SpanHistory.Kind.allCases {
            XCTAssertFalse(line.localizedCaseInsensitiveContains(verdict.rawValue),
                           "A derived verdict (\(verdict.rawValue)) reached the prose: \(line)")
        }
        XCTAssertNil(OracleToneGuard.check(line))
    }

    /// A truncated set has to say it is truncated — the `droppedNotes` discipline (D6 R4). Without
    /// it the reading describes a loop's whole life from its last two edits.
    func testDroppedEditsAreAdmittedInTheProse() throws {
        let loop = passage("u1", "Chorus turnaround",
                           spans: [edit(from: 34, to: 6, on: 3)],
                           droppedSpans: 3, runsInCurrentSpan: 2)

        let line = try XCTUnwrap(oracle.spanLines(context(units: [loop])).first)

        XCTAssertTrue(line.contains("Earlier changes"), line)
    }

    /// An exercise has no span, and a loop nobody has edited has no edit to report. Neither gets an
    /// empty sentence.
    func testAUnitWithNoRecordedEditGetsNoSpanLine() {
        XCTAssertTrue(oracle.spanLines(context(units: [drill("u1", "Bend study")])).isEmpty)
        XCTAssertTrue(oracle.spanLines(context(units: [passage("u2", "Intro")])).isEmpty)
    }

    // MARK: - The step-down

    /// The pair, both numbers, with the date. Never a flag and never *backed off* — a step-down is
    /// relative to the tempo before it, and stating both values is what keeps D22's own exception
    /// from becoming the comparison it brushes against.
    func testAStepDownIsNamedAsThePairItIs() {
        let points: [OracleContext.TempoPoint] = [.init(date: day(0), bpm: 68),
                                                  .init(date: day(2), bpm: 76),
                                                  .init(date: day(3), bpm: 60),
                                                  .init(date: day(5), bpm: 60)]

        let clause = oracle.steppedDown(points)

        XCTAssertEqual(clause?.contains("from 76 to 60"), true, clause ?? "no clause")
        XCTAssertEqual(clause?.contains("and stayed there"), true, clause ?? "no clause")
        XCTAssertNil(OracleToneGuard.check(clause ?? ""), "The step-down phrasing tripped D12")
    }

    /// **Found by reading a drawn reading, not by a test.** The tempo sentence states the *latest*
    /// tempo, so when the step landed on that value the clause after it said 60 a second time and
    /// introduced 76 with no date — a number from nowhere, next to a fact already given. The same
    /// defect as the `held at 72` bug, and the reason a prose change gets looked at.
    func testWhenTheStepLandedOnTheTempoAlreadyStatedTheNumberIsNotSaidTwice() throws {
        let tempo = OracleContext.Tempo(points: [.init(date: day(-30), bpm: 68),
                                                 .init(date: day(0), bpm: 76),
                                                 .init(date: day(3), bpm: 60),
                                                 .init(date: day(5), bpm: 60)],
                                        notesPerBeat: 2, otherRhythmRuns: 0)

        let line = try XCTUnwrap(oracle.tempoLines(context(units: [drill("u1", "Bend study", tempo: tempo)])).first)

        XCTAssertTrue(line.contains("It was at 76 on"), line)
        XCTAssertEqual(line.components(separatedBy: "60").count, 2,
                       "The landing tempo was stated twice: \(line)")
        XCTAssertFalse(line.contains("76,"), "76 arrived without a date attached: \(line)")
        XCTAssertNil(OracleToneGuard.check(line))
    }

    /// A rising trajectory has no step to report, and inventing one from the first and last points
    /// would be the delta this type refuses to state.
    func testATrajectoryThatOnlyRisesHasNoStepDownClause() throws {
        let tempo = OracleContext.Tempo(points: [.init(date: day(0), bpm: 60),
                                                 .init(date: day(3), bpm: 76)],
                                        notesPerBeat: 4, otherRhythmRuns: 0)

        let line = try XCTUnwrap(oracle.tempoLines(context(units: [drill("u1", "Bend study", tempo: tempo)])).first)

        XCTAssertFalse(line.contains("went from"), line)
    }

    /// "and stayed there" needs a later point that agrees. With nothing after the step there is no
    /// staying to report — only a last reading that happened to be lower, which is a different fact.
    func testAStepDownAtTheVeryEndDoesNotClaimItStayed() {
        let tempo = OracleContext.Tempo(points: [.init(date: day(0), bpm: 76),
                                                 .init(date: day(3), bpm: 60)],
                                        notesPerBeat: 4, otherRhythmRuns: 0)

        let clause = oracle.steppedDown(tempo.points)

        XCTAssertEqual(clause?.contains("from 76 to 60"), true, clause ?? "no clause")
        XCTAssertEqual(clause?.contains("stayed there"), false, clause ?? "no clause")
    }

    /// The **most recent** step down, not the largest. The reading is about where the drill is now,
    /// and the biggest backward move of the summer is a different sentence.
    func testTheMostRecentStepDownWinsNotTheLargest() {
        let points: [OracleContext.TempoPoint] = [.init(date: day(-40), bpm: 120),
                                                  .init(date: day(-30), bpm: 60),
                                                  .init(date: day(0), bpm: 80),
                                                  .init(date: day(3), bpm: 74)]
        XCTAssertEqual(oracle.steppedDown(points)?.contains("from 80 to 74"), true)
    }
}
