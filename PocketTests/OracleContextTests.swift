import XCTest
@testable import Pocket

/// The seven rules of ADR 0187 D6, as tests rather than as care.
///
/// Every model here is built and left **uninserted** — no `ModelContainer`, no `ModelContext`.
/// That is the house rule for model tests in this host (inserting traps), and it is what the
/// builder is designed for: it reads plain models and returns a plain value, so the rules about
/// what may cross the wire are testable without a store at all.
///
/// Several assertions below run over the **encoded JSON** rather than the value tree, and follow
/// `PracticeArchiveTests.swift:44-46`'s idiom: assert a field encoded *at all* before asserting an
/// exclusion, because a privacy check that passes because it read nothing is worse than none.
@MainActor
final class OracleContextTests: XCTestCase {

    // MARK: - Fixtures

    private let windowStart = Date(timeIntervalSince1970: 1_724_889_600) // Mon 29 Aug 2024, UTC
    private var window: DateInterval { DateInterval(start: windowStart, duration: 7 * 86_400) }

    private func day(_ offset: Int, hour: Int = 10) -> Date {
        windowStart.addingTimeInterval(Double(offset) * 86_400 + Double(hour) * 3_600)
    }

    private func makeExercise(name: String = "Bend study",
                              template: ExerciseTemplate = .scales,
                              mastery: Int? = 3) -> Exercise {
        let exercise = Exercise(name: name)
        exercise.template = template
        exercise.mastery = mastery
        return exercise
    }

    private func run(_ unit: UUID, on offset: Int, minutes: Double = 10, bpm: Int? = nil,
                     perBeat: Int? = nil) -> SessionRecord {
        SessionRecord(startedAt: day(offset),
                      durationSeconds: minutes * 60,
                      kind: .exercise,
                      unitUID: unit,
                      tempoBPM: bpm,
                      notesPerBeat: perBeat)
    }

    private func build(_ source: OracleContextSource) -> OracleContextBuilder.Build {
        OracleContextBuilder.build(from: source,
                                   window: window,
                                   promptVersion: "test-1",
                                   now: day(7),
                                   calendar: Calendar(identifier: .gregorian))
    }

    private func encoded(_ context: OracleContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try XCTUnwrap(String(bytes: encoder.encode(context), encoding: .utf8))
    }

    // MARK: - R1, no uids cross

    func testUnitsCrossAsHandlesAndTheUidStaysBehind() throws {
        let exercise = makeExercise()
        var source = OracleContextSource()
        source.exercises = [exercise]
        source.records = [run(exercise.uid, on: 1)]

        let built = build(source)
        let json = try encoded(built.context)

        // Positive control: the unit made it in at all.
        XCTAssertEqual(built.context.units.count, 1)
        XCTAssertEqual(built.context.units.first?.handle, "u1")
        XCTAssertFalse(json.contains(exercise.uid.uuidString),
                       "A unit's uid reached the payload; D6 R1 says only a per-request handle crosses")
        XCTAssertEqual(built.handles["u1"], exercise.uid,
                       "The handle map is the client-side half of R1 and must resolve back")
    }

    func testHandlesAreMintedInADeterministicOrder() {
        let quiet = makeExercise(name: "Aardvark")
        let busy = makeExercise(name: "Zebra")
        var source = OracleContextSource()
        source.exercises = [quiet, busy]
        // Zebra has more minutes, so it leads regardless of its name or array position.
        source.records = [run(quiet.uid, on: 1, minutes: 5), run(busy.uid, on: 1, minutes: 40)]

        let first = build(source)
        source.exercises = [busy, quiet]
        let second = build(source)

        XCTAssertEqual(first.context.units.map(\.name), ["Zebra", "Aardvark"])
        XCTAssertEqual(first.context.units, second.context.units,
                       "Two builds over the same store must agree, or a fixture cannot be asserted")
    }

    // MARK: - R2, no song, artist or file names

    func testALoopCrossesWithoutItsSongsTitleOrArtist() throws {
        let song = Song(title: "Blue Monday",
                        artist: "Jack Trader",
                        duration: 200,
                        amplitudes: [],
                        ref: SongRef(id: "song-1", source: .localFile, bookmark: nil),
                        audioFileName: "song-1.wav")
        let loop = Loop(name: "Chorus solo", start: 0, end: 0.5, speed: 1, repeats: 1)
        loop.song = song
        var source = OracleContextSource()
        source.loops = [loop]
        source.records = [run(loop.uid, on: 2)]

        let json = try encoded(build(source).context)

        XCTAssertTrue(json.contains("Chorus solo"), "The loop did not encode; the checks below are vacuous")
        XCTAssertFalse(json.contains("Blue Monday"), "A song title crossed (D6 R2)")
        XCTAssertFalse(json.contains("Jack Trader"), "An artist name crossed (D6 R2)")
        XCTAssertFalse(json.contains("song-1.wav"), "A file name crossed (D6 R2)")
    }

    func testATakesNoteCrossesButItsTitleAndFileNameDoNot() throws {
        let take = Recording(fileName: "take-abc123.m4a", duration: 30, createdAt: day(3))
        take.title = "Attempt four"
        take.note = "The second half is the one worth keeping."
        var source = OracleContextSource()
        source.takes = [take]

        let json = try encoded(build(source).context)

        XCTAssertTrue(json.contains("worth keeping"), "The take note did not encode; the checks are vacuous")
        XCTAssertFalse(json.contains("take-abc123"), "A take's file name crossed (D6 R2)")
        XCTAssertFalse(json.contains("Attempt four"), "A take's title crossed (D6 R2)")
    }

    // MARK: - R4, caps and the budget

    func testALongNoteIsTruncatedToTheStatedCapAndSaysSo() {
        let entry = JournalEntry.forStandalone(text: String(repeating: "a", count: 900), kind: .note,
                                               createdAt: day(1))
        var source = OracleContextSource()
        source.journal = [entry]

        let note = build(source).context.notes.first
        XCTAssertEqual(note?.text.count, OracleContextBudget.noteTextCap)
        XCTAssertEqual(note?.wasTruncated, true,
                       "A truncated note must say so, or a cut-off sentence reads as a trailing thought")
    }

    /// R4 is specific about *how* the budget is enforced: whole notes, oldest first — never a
    /// silent extra clip on every note, which would leave the set looking complete.
    func testOverBudgetDropsWholeNotesOldestFirst() {
        let text = String(repeating: "b", count: OracleContextBudget.noteTextCap)
        let perNote = OracleContextBudget.noteTextCap
        let affordable = OracleContextBudget.totalFreeTextBudget / perNote
        let notes = (0..<(affordable + 5)).map { index in
            OracleContext.Note(writtenOn: self.day(0).addingTimeInterval(Double(index) * 60),
                               text: text, unitHandle: nil, kind: "note", wasTruncated: false)
        }

        let fitted = OracleContextBuilder.fitToBudget(notes, alreadySpent: 0)

        XCTAssertEqual(fitted.kept.count, affordable)
        XCTAssertEqual(fitted.dropped, 5)
        XCTAssertTrue(fitted.kept.allSatisfy { $0.text.count == perNote },
                      "Notes were clipped as well as dropped; R4 drops whole notes")
        let oldestKept = try? XCTUnwrap(fitted.kept.first).writtenOn
        XCTAssertEqual(oldestKept, notes[5].writtenOn, "The drop must fall on the oldest notes")
        XCTAssertEqual(fitted.kept.map(\.writtenOn), fitted.kept.map(\.writtenOn).sorted(),
                       "Kept notes are handed back oldest-first, which is reading order")
    }

    // MARK: - R6, no computed judgement

    func testEffortIsCountsMinutesAndDatesAndNothingDerived() throws {
        let exercise = makeExercise()
        var source = OracleContextSource()
        source.exercises = [exercise]
        source.records = [run(exercise.uid, on: 0, minutes: 20), run(exercise.uid, on: 2, minutes: 10)]

        let context = build(source).context
        let json = try encoded(context)

        XCTAssertEqual(context.effort.runs, 2)
        XCTAssertEqual(context.effort.minutes, 30)
        XCTAssertEqual(context.effort.daysPractised.count, 2,
                       "Days practised is a list of days, not a count of consecutive ones")
        for banned in ["streak", "consistency", "daysSince", "average", "ratio", "target"] {
            XCTAssertFalse(json.localizedCaseInsensitiveContains(banned),
                           "A derived judgement (\(banned)) reached the payload (D6 R6)")
        }
    }

    /// The trajectory type carries a computed `change`; R5 and R6 keep it on this side of the wire.
    func testATempoDeltaNeverCrossesEvenThoughTheSourceTypeComputesOne() throws {
        let exercise = makeExercise()
        var source = OracleContextSource()
        source.exercises = [exercise]
        source.records = [run(exercise.uid, on: 0, bpm: 76, perBeat: 4),
                          run(exercise.uid, on: 3, bpm: 96, perBeat: 4)]

        let context = build(source).context
        let json = try encoded(context)

        XCTAssertEqual(context.units.first?.tempo?.points.map(\.bpm), [76, 96],
                       "The points did not encode; the check below is vacuous")
        XCTAssertFalse(json.contains("\"change\""), "A computed BPM delta crossed (D6 R5/R6)")
    }

    // MARK: - R7, a tempo never travels without its note rate

    func testATempoCarriesItsNoteRateAndTheRunsItSetAside() {
        let exercise = makeExercise()
        var source = OracleContextSource()
        source.exercises = [exercise]
        source.records = [run(exercise.uid, on: 0, bpm: 60, perBeat: 2),
                          run(exercise.uid, on: 1, bpm: 88, perBeat: 4),
                          run(exercise.uid, on: 2, bpm: 96, perBeat: 4)]

        let tempo = build(source).context.units.first?.tempo

        XCTAssertEqual(tempo?.notesPerBeat, 4, "The rate most recently practised wins the line (ADR 0121)")
        XCTAssertEqual(tempo?.points.map(\.bpm), [88, 96])
        XCTAssertEqual(tempo?.otherRhythmRuns, 1,
                       "Runs at another rhythm are counted, not silently dropped")
    }

    // MARK: - Selection

    /// A drill written about but not run is exactly the drill a reflection has something to say
    /// about. Selecting on the log alone would drop it.
    func testAUnitWrittenAboutButNotRunIsStillSelected() {
        let exercise = makeExercise(name: "Barre changes")
        let entry = JournalEntry.forExercise(text: "Still buzzing on the B string.", kind: .struggle,
                                             commandBpmAtEntry: nil, createdAt: day(2))
        entry.exercise = exercise
        var source = OracleContextSource()
        source.exercises = [exercise]
        source.journal = [entry]

        let context = build(source).context

        XCTAssertEqual(context.units.map(\.name), ["Barre changes"])
        XCTAssertEqual(context.notes.first?.unitHandle, "u1",
                       "The note must resolve to the unit's handle, not carry a uid")
    }

    func testNotesOutsideTheWindowAreNotRead() {
        let entry = JournalEntry.forStandalone(text: "Written a fortnight ago.", kind: .note,
                                               createdAt: windowStart.addingTimeInterval(-14 * 86_400))
        var source = OracleContextSource()
        source.journal = [entry]

        XCTAssertTrue(build(source).context.notes.isEmpty)
    }
}
