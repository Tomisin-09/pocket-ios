import XCTest
@testable import Pocket

/// The deterministic reading (ADR 0187, S1) and the pipeline that shows it (D12, D13).
///
/// The headline assertion is `testEveryLocalReadingPassesTheToneGuard`. It is what stops this type
/// drifting: a future edit that reaches for "you've been consistent this week" fails a test rather
/// than shipping, which is the same trick `.swiftlint.yml`'s two custom rules play on copy that
/// already shipped once.
@MainActor
final class LocalOracleTests: XCTestCase {

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
                         notes: [OracleContext.Note] = [],
                         goals: [OracleContext.GoalLine] = [],
                         effort: OracleContext.Effort = .init(),
                         sittings: [OracleContext.Sitting] = []) -> OracleContext {
        var context = OracleContext(promptVersion: "test-1",
                                    generatedAt: day(7),
                                    windowStart: window.start,
                                    windowEnd: window.end)
        context.units = units
        context.notes = notes
        context.goals = goals
        context.effort = effort
        context.sittings = sittings
        return context
    }

    private func unit(_ name: String, minutes: Int = 20, runs: Int = 2,
                      tempo: OracleContext.Tempo? = nil) -> OracleContext.Unit {
        OracleContext.Unit(handle: "u1", name: name, kind: .exercise, template: "scales",
                           mastery: 3, tempo: tempo, runs: runs, minutes: minutes,
                           lastPractisedOn: day(2))
    }

    // MARK: - The rule that stops it drifting

    /// Every shape of reading, past **both** guards — D12's verdicts and D23's instructions at the
    /// body. Including the empty week, which is the one a future author is most tempted to write an
    /// adverb into, and the span and sitting paragraphs D22 added.
    ///
    /// This is the assertion the whole type is held up by. It is why a revision as large as D22
    /// could be made to `LocalOracle` without re-arguing its guarantee: the prose changed, and the
    /// thing that says the prose is safe did not have to.
    func testEveryLocalReadingPassesBothGuards() {
        let tempo = OracleContext.Tempo(points: [.init(date: day(0), bpm: 76),
                                                 .init(date: day(2), bpm: 96),
                                                 .init(date: day(3), bpm: 80)],
                                        notesPerBeat: 4, otherRhythmRuns: 2)
        let loop = OracleContext.Unit(handle: "u2", name: "Chorus turnaround", kind: .loop,
                                      template: nil, mastery: 2, tempo: nil, runs: 4, minutes: 12,
                                      lastPractisedOn: day(3),
                                      spans: [.init(changedOn: day(2), fromSeconds: 34, toSeconds: 6,
                                                    speed: 0.6, runsInPreviousSpan: 3)],
                                      droppedSpans: 2,
                                      runsInCurrentSpan: 9)
        let shapes: [OracleContext] = [
            context(),
            context(effort: .init(runs: 1, minutes: 8, daysPractised: [day(0)], sittings: 1)),
            // A week with runs but no nameable units — the branch the opening needs a sentence for.
            context(effort: .init(runs: 3, minutes: 20, daysPractised: [day(1)], sittings: 1)),
            context(units: [unit("Bend study", tempo: tempo), loop],
                    notes: [note("The second half is finally sitting where it should, more or less.")],
                    goals: [.init(title: "Get the intro clean", rank: 1, isMet: false, horizon: .longTerm)],
                    effort: .init(runs: 6, minutes: 130, daysPractised: [day(0), day(2), day(3)], sittings: 4),
                    sittings: [.init(startedOn: day(2), handles: ["u1", "u2", "u1"])])
        ]
        for shape in shapes {
            let reading = OracleReadingText(paragraphs: oracle.paragraphs(for: shape), source: .local)
            XCTAssertNil(OracleToneGuard.check(reading.guardedText),
                         "The local reading tripped the tone guard: \(reading.guardedText)")
            XCTAssertNil(OracleFocusGuard.check(reading.guardedText),
                         "The local reading tripped the focus guard: \(reading.guardedText)")
        }
    }

    private func note(_ text: String) -> OracleContext.Note {
        OracleContext.Note(writtenOn: day(2), text: text, unitHandle: "u1",
                           kind: "note", wasTruncated: false)
    }

    // MARK: - What it says

    /// Replaces `testItStatesMinutesDaysAndSittingsWithoutComparingThem`, which asserted the
    /// opening said *"2 hours 10 min, over 4 days and 5 sittings"* — the volume mirror ADR 0187 D22
    /// exists to remove. The assertion is kept as its own inverse: the totals are still in the
    /// context and must not reach the prose.
    func testTheOpeningNamesWhatWasWorkedOnAndNeverHowMuch() {
        let effort = OracleContext.Effort(runs: 6, minutes: 130,
                                          daysPractised: [day(0), day(2), day(3), day(5)], sittings: 5)
        let opening = oracle.opening(context(units: [unit("Bend study")], effort: effort))

        XCTAssertTrue(opening.contains("Bend study"), opening)
        XCTAssertFalse(opening.contains("130"), "The minute total reached the opening: \(opening)")
        XCTAssertFalse(opening.contains("hour"), "The minute total reached the opening: \(opening)")
        XCTAssertFalse(opening.contains("sitting"), "The sitting count reached the opening: \(opening)")
        XCTAssertFalse(opening.contains("4 days"), "The day count reached the opening: \(opening)")
    }

    /// "You did not practise" is a fact. "You only practised once" is a verdict, and the adverb is
    /// the whole difference.
    func testAnEmptyWeekIsStatedWithoutAnAdverb() {
        let opening = oracle.opening(context())
        XCTAssertTrue(opening.contains("nothing logged"), opening)
        XCTAssertNil(OracleToneGuard.check(opening))
    }

    /// Two tempos are stated. A delta is not, because a delta has a direction somebody then has an
    /// opinion about (D11, ADR 0070 §2).
    func testATempoLineStatesBothNumbersAndTheirRhythmButNeverTheDifference() {
        let tempo = OracleContext.Tempo(points: [.init(date: day(0), bpm: 76),
                                                 .init(date: day(3), bpm: 96)],
                                        notesPerBeat: 4, otherRhythmRuns: 2)
        let line = try? XCTUnwrap(oracle.tempoLines(context(units: [unit("Bend study", tempo: tempo)])).first)

        XCTAssertEqual(line?.contains("76"), true)
        XCTAssertEqual(line?.contains("96"), true)
        XCTAssertEqual(line?.contains("16ths"), true, "The rate must travel with the tempo (ADR 0121)")
        XCTAssertEqual(line?.contains("2 runs"), true, "Runs at other rhythms are admitted, not dropped")
        XCTAssertEqual(line?.contains("20"), false, "The difference between the two tempos was stated")
    }

    /// The two-number form degenerates into "played at 72 on 22 Jul, and at 72 on 28 Aug" when a
    /// drill's tempo has not moved — one fact stated twice, which reads as a bug. It was caught by
    /// looking at the screen, not by a test, so it gets a test.
    func testATempoThatHasNotMovedIsStatedOnceNotTwice() {
        let steady = OracleContext.Tempo(points: [.init(date: day(0), bpm: 72),
                                                  .init(date: day(4), bpm: 72)],
                                         notesPerBeat: 2, otherRhythmRuns: 0)
        let line = try? XCTUnwrap(oracle.tempoLines(context(units: [unit("Alternate Picking", tempo: steady)])).first)

        XCTAssertEqual(line?.contains("held at 72"), true, line ?? "no line")
        XCTAssertEqual(line?.components(separatedBy: "72").count, 2,
                       "The tempo was named twice: \(line ?? "")")
        // "held" must not shade into "plateaued" — that is the word D12's tempo band exists for.
        XCTAssertNil(OracleToneGuard.check(line ?? ""))
    }

    /// Beyond three, the reading stops being prose and becomes a table.
    func testTempoLinesAreCappedSoTheReadingStaysProse() {
        let tempo = OracleContext.Tempo(points: [.init(date: day(0), bpm: 60),
                                                 .init(date: day(3), bpm: 80)],
                                        notesPerBeat: 4, otherRhythmRuns: 0)
        let many = (1...6).map { index in
            OracleContext.Unit(handle: "u\(index)", name: "Drill \(index)", kind: .exercise,
                               template: "scales", mastery: nil, tempo: tempo, runs: 2, minutes: 10,
                               lastPractisedOn: self.day(2))
        }
        XCTAssertEqual(oracle.tempoLines(context(units: many)).count, LocalOracle.maxTempoLines)
    }

    /// A trajectory is drawn from the whole log, so its dates sit outside the week the paragraph
    /// above just named. On screen that reads as a mistake unless something says so.
    func testTheReadingSaysTheTemposCoverMoreThanTheWeek() {
        let tempo = OracleContext.Tempo(points: [.init(date: day(-40), bpm: 60),
                                                 .init(date: day(3), bpm: 80)],
                                        notesPerBeat: 4, otherRhythmRuns: 0)
        let reading = oracle.paragraphs(for: context(units: [unit("Bend study", tempo: tempo)]))
        XCTAssertTrue(reading.contains { $0.text == LocalOracle.tempoLead },
                      "The tempo lines quote dates outside the window with nothing explaining why")
    }

    // MARK: - Quoting

    /// The player's own words come back marked, so the tone guard does not read them. Otherwise the
    /// app would refuse to show someone their own journal because of what they said about
    /// themselves.
    func testAQuotedNoteIsMarkedAndIsNotReadByTheGuard() {
        let harsh = note("Fell off completely this week, stalled on the bend, no excuses.")
        let reading = OracleReadingText(paragraphs: oracle.paragraphs(for: context(notes: [harsh])),
                                        source: .local)

        XCTAssertTrue(reading.paragraphs.contains { $0.isQuotedFromPlayer && $0.text == harsh.text },
                      "The note was not quoted back")
        XCTAssertNil(OracleToneGuard.check(reading.guardedText),
                     "The guard read the player's own words and rejected the reading")
        XCTAssertNotNil(OracleToneGuard.check(reading.joined),
                        "Positive control: those words would trip the guard if the Oracle wrote them")
    }

    func testATruncatedNoteIsNeverQuoted() {
        let clipped = OracleContext.Note(writtenOn: day(2),
                                         text: String(repeating: "c", count: 400),
                                         unitHandle: nil, kind: "note", wasTruncated: true)
        XCTAssertNil(oracle.quotedNote(context(notes: [clipped])),
                     "Quoting half a thought back at someone is worse than quoting none of it")
    }

    // MARK: - Determinism

    func testTwoReadingsOverTheSameContextAgree() async throws {
        let subject = context(units: [unit("Bend study")],
                              notes: [note("A long enough note to be worth handing back to me.")],
                              effort: .init(runs: 2, minutes: 30, daysPractised: [day(0)], sittings: 1))
        let first = try await oracle.reading(for: OracleReadingRequest(context: subject))
        let second = try await oracle.reading(for: OracleReadingRequest(context: subject))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.source, .local)
    }

    // MARK: - The pipeline (D12, D13)

    func testProseThatTripsTheGuardIsRejectedInFullAndTheLocalReadingShown() async {
        let judged = OracleReadingText(
            paragraphs: [.init("You've been consistent this week."), .init("The bends are cleaner.")],
            source: .model)
        let coordinator = OracleCoordinator(oracle: RecordingOracle(response: judged), local: oracle)

        let outcome = await coordinator.run(context: context(effort: .init(runs: 2, minutes: 20,
                                                                           daysPractised: [day(0)],
                                                                           sittings: 1)))

        guard case let .reading(shown, capabilities) = outcome else { return XCTFail("Expected a reading") }
        XCTAssertEqual(shown.source, .local, "A tripped reading must be replaced, not shown")
        XCTAssertFalse(shown.joined.contains("The bends are cleaner."),
                       "The reading was scrubbed rather than rejected in full")
        XCTAssertEqual(capabilities, .all)
    }

    func testDistressMeansTheModelIsNeverCalled() async {
        let recorder = RecordingOracle()
        let coordinator = OracleCoordinator(oracle: recorder, local: oracle)

        let outcome = await coordinator.run(context: context(notes: [note("I'm giving up, what's the point.")]))

        XCTAssertEqual(outcome, .distress)
        XCTAssertTrue(recorder.requests.isEmpty, "D13's distress branch must not reach the seam at all")
    }

    func testPainLeavesTheReadingStandingAndClosesTheProposalDoors() async {
        let coordinator = OracleCoordinator(oracle: RecordingOracle(), local: oracle)

        let outcome = await coordinator.run(context: context(notes: [note("Wrist is sore after the barre work.")]))

        guard case let .reading(_, capabilities) = outcome else { return XCTFail("Expected a reading") }
        XCTAssertEqual(capabilities, .readingOnly,
                       "Pain suppresses the proposals, not the reflection")
    }

    func testAFailingSeamFallsBackRatherThanThrowing() async {
        struct Unreachable: Error {}
        let coordinator = OracleCoordinator(oracle: RecordingOracle(failure: Unreachable()), local: oracle)

        let outcome = await coordinator.run(context: context())

        guard case let .reading(shown, _) = outcome else { return XCTFail("Expected a reading") }
        XCTAssertEqual(shown.source, .local,
                       "ADR 0092 §A2's fallback is the ordinary path with the network removed")
    }

    /// The request the seam is handed carries no free text — D9's structural guarantee, checked at
    /// the point it would actually leak rather than only at the type declaration.
    func testTheRequestReachingTheSeamCarriesNoPromptField() async throws {
        let recorder = RecordingOracle()
        let coordinator = OracleCoordinator(oracle: recorder, local: oracle)

        _ = await coordinator.run(context: context(notes: [note("An ordinary note about the week.")]))

        let request = try XCTUnwrap(recorder.requests.first)
        let json = try XCTUnwrap(String(bytes: JSONEncoder().encode(request), encoding: .utf8))
        XCTAssertTrue(json.contains("An ordinary note"), "Positive control: the context did encode")
        XCTAssertFalse(json.localizedCaseInsensitiveContains("\"prompt\""),
                       "OracleReadingRequest grew a text field (D9)")
    }
}
