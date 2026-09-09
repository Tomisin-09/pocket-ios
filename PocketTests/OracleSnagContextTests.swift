import XCTest
@testable import Pocket

/// Snags and loop spans in the payload (ADR 0204) — its own class, because it is its own subject and
/// `OracleContextTests` had reached the type-body limit. The rules it checks are D6's all the same:
/// what a mark is allowed to be (a position, never a count), and what a span edit is allowed to say
/// (two numbers, never a verdict).
@MainActor
final class OracleSnagContextTests: XCTestCase {

    private let windowStart = Date(timeIntervalSince1970: 1_724_889_600) // Mon 29 Aug 2024, UTC
    private var window: DateInterval { DateInterval(start: windowStart, duration: 7 * 86_400) }

    private func day(_ offset: Int, hour: Int = 10) -> Date {
        windowStart.addingTimeInterval(Double(offset) * 86_400 + Double(hour) * 3_600)
    }

    private func run(_ unit: UUID, on offset: Int) -> SessionRecord {
        SessionRecord(startedAt: day(offset), durationSeconds: 600, kind: .loop, unitUID: unit)
    }

    private func build(_ source: OracleContextSource) -> OracleContextBuilder.Build {
        OracleContextBuilder.build(from: source,
                                  window: window,
                                  promptVersion: "test-1",
                                  now: day(7),
                                  calendar: Calendar(identifier: .gregorian))
    }

    private func makeExercise() -> Exercise {
        let exercise = Exercise(name: "Bend study")
        exercise.template = .scales
        exercise.mastery = 3
        return exercise
    }

    private func encoded(_ context: OracleContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try XCTUnwrap(String(bytes: encoder.encode(context), encoding: .utf8))
    }

    // MARK: - ADR 0204, snags and spans

    /// A loop with its song, its marks and its recorded narrowings, wired the way the store wires
    /// them. Uninserted throughout — the house rule for model tests in this host.
    private func makeLoopWithMarks(start: Double = 0.25, end: Double = 0.35) -> Loop {
        let song = Song(title: "Slow Bend", artist: "Jack Trader", duration: 200,
                        ref: SongRef(id: "song-1", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Post Solo Riff", start: start, end: end, speed: 0.75, repeats: 4)
        loop.song = song
        return loop
    }

    private func addSnag(_ loop: Loop, at seconds: TimeInterval, on offset: Int, speed: Double? = 0.75) {
        let snag = Snag(markedAt: day(offset), seconds: seconds, speed: speed, loopUID: loop.uid)
        snag.song = loop.song
    }

    private func loopUnit(_ loop: Loop) -> OracleContext.Unit? {
        var source = OracleContextSource()
        source.loops = [loop]
        source.records = [run(loop.uid, on: 1)]
        return build(source).context.units.first
    }

    /// Marks travel as **offsets into the loop**, in song order. Never an absolute point in a song
    /// whose title deliberately does not travel with it (D6 R2).
    func testSnagsCrossAsOffsetsIntoTheLoopInSongOrder() throws {
        let loop = makeLoopWithMarks()          // 50s–70s of a 200s song
        addSnag(loop, at: 64, on: 2)
        addSnag(loop, at: 52.5, on: 1)

        let unit = try XCTUnwrap(loopUnit(loop))

        XCTAssertEqual(unit.snags.map(\.atSeconds), [2.5, 14])
        XCTAssertEqual(unit.droppedSnags, 0)
    }

    /// The payload's set is the set the player can see lit on the canvas: position decides, not the
    /// loop that happened to be armed at the tap (ADR 0203 D1).
    func testSnagsAreFilteredByPositionNotByTheLoopTheyWereMadeUnder() throws {
        let loop = makeLoopWithMarks()
        // Inside the span, but tagged with a loop that no longer exists.
        let stray = Snag(markedAt: day(1), seconds: 60, speed: 0.8, loopUID: UUID())
        stray.song = loop.song
        // Tagged with *this* loop, but now outside its narrowed span.
        addSnag(loop, at: 120, on: 1)

        let unit = try XCTUnwrap(loopUnit(loop))

        XCTAssertEqual(unit.snags.map(\.atSeconds), [10], "Position must decide, not loopUID")
    }

    /// A drill has no timeline to mark and no span to move, so both lists stay empty for one.
    func testAnExerciseUnitCarriesNoSnagsAndNoSpans() throws {
        var source = OracleContextSource()
        let exercise = makeExercise()
        source.exercises = [exercise]
        source.records = [run(exercise.uid, on: 1)]

        let unit = try XCTUnwrap(build(source).context.units.first)

        XCTAssertTrue(unit.snags.isEmpty)
        XCTAssertTrue(unit.spans.isEmpty)
    }

    /// A capped snag set must **say** it is capped. A map trimmed in silence is read as the whole
    /// terrain — the reason `droppedNotes` exists (D6 R4).
    func testACappedSnagSetReportsWhatItDropped() throws {
        let loop = makeLoopWithMarks(start: 0, end: 1)      // the whole song, so everything is inside
        for index in 0..<(OracleContextBudget.maxSnagsPerUnit + 4) {
            addSnag(loop, at: Double(index), on: index % 5)
        }

        let unit = try XCTUnwrap(loopUnit(loop))

        XCTAssertEqual(unit.snags.count, OracleContextBudget.maxSnagsPerUnit)
        XCTAssertEqual(unit.droppedSnags, 4)
    }

    /// Span edits travel as two widths in seconds, oldest first — and **not** as `SpanHistory.Kind`,
    /// which is derived and stays this side of the wire (D6 R5).
    func testSpanEditsCrossAsWidthsInSecondsAndNeverAsAVerdict() throws {
        let loop = makeLoopWithMarks()
        for (index, pair) in [(0.2, 0.4), (0.25, 0.35)].enumerated() {
            let change = LoopSpanChange(changedAt: day(index + 1),
                                        start: pair.0, end: pair.1,
                                        previousStart: 0.1, previousEnd: 0.5,
                                        speed: 0.8, songDuration: 200)
            change.loop = loop
        }

        var source = OracleContextSource()
        source.loops = [loop]
        source.records = [run(loop.uid, on: 1)]
        let context = build(source).context
        let unit = try XCTUnwrap(context.units.first)
        let json = try encoded(context)

        XCTAssertEqual(unit.spans.count, 2, "Oldest first, in seconds")
        XCTAssertEqual(unit.spans.first?.toSeconds ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(unit.spans.last?.toSeconds ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(unit.spans.map(\.fromSeconds), [80, 80])
        XCTAssertTrue(json.contains("\"toSeconds\""), "Spans did not encode; the check below is vacuous")
        for verdict in SpanHistory.Kind.allCases {
            XCTAssertFalse(json.contains(verdict.rawValue),
                           "A derived verdict (\(verdict.rawValue)) reached the payload")
        }
    }

    /// A row that never recorded the song's duration cannot be stated in seconds, and a fraction of an
    /// unnamed song is not a fact anybody can read. It is left out rather than guessed at.
    func testASpanEditWithNoRecordedDurationIsLeftOut() throws {
        let loop = makeLoopWithMarks()
        let change = LoopSpanChange(changedAt: day(1), start: 0.2, end: 0.4,
                                    previousStart: 0.1, previousEnd: 0.5,
                                    speed: nil, songDuration: nil)
        change.loop = loop

        XCTAssertEqual(try XCTUnwrap(loopUnit(loop)).spans.count, 0)
    }

    /// Marks and spans carry no free text, so they must not eat into the notes budget — a payload that
    /// silently dropped journal entries because a passage was heavily marked would be the wrong trade.
    func testSnagsAndSpansDoNotSpendTheFreeTextBudget() throws {
        let loop = makeLoopWithMarks(start: 0, end: 1)
        for index in 0..<20 { addSnag(loop, at: Double(index), on: 1) }

        var source = OracleContextSource()
        source.loops = [loop]
        source.records = [run(loop.uid, on: 1)]
        let entry = JournalEntry.forLoop(text: String(repeating: "a", count: 200), kind: .note,
                                         masteryAtEntry: nil, commandTempoAtEntry: nil,
                                         createdAt: day(1))
        entry.loop = loop
        source.journal = [entry]

        let context = build(source).context

        XCTAssertEqual(context.droppedNotes, 0)
        XCTAssertEqual(context.notes.count, 1)
    }
}
