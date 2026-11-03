import XCTest
@testable import Pocket

/// The Journal thread's pure half (ADR 0286): which unit an item belongs to, the counts the feed shows,
/// one unit's items, and the first-to-latest line. Models are built **uninserted**, as in
/// `JournalTimelineTests`, which is safe for property reads.
final class JournalTimelineUnitTests: XCTestCase {

    // 2023-11-14 12:00:00 GMT, plus offsets — deterministic, no force-unwraps.
    private let noon = Date(timeIntervalSince1970: 1_699_963_200)
    private let day: TimeInterval = 86_400

    private let drill = Exercise(name: "Spider", currentTempo: 80, commandTempo: 96)
    private let otherDrill = Exercise(name: "Chords", currentTempo: 80, commandTempo: 96)
    private let riff = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 1.0, repeats: 1)

    private func drillNote(_ bpm: Int?, rate: Int? = 2, at date: Date, on exercise: Exercise? = nil) -> JournalEntry {
        let entry = JournalEntry.forExercise(text: "n", kind: .note, commandBpmAtEntry: bpm,
                                             commandNotesPerBeatAtEntry: rate, createdAt: date)
        entry.exercise = exercise ?? drill
        return entry
    }

    private func riffNote(mastery: Int?, tempo: Double?, at date: Date) -> JournalEntry {
        let entry = JournalEntry.forLoop(text: "n", kind: .note, masteryAtEntry: mastery,
                                         commandTempoAtEntry: tempo, createdAt: date)
        entry.loop = riff
        return entry
    }

    private func take(at date: Date, exercise: Exercise? = nil, loop: Loop? = nil) -> Recording {
        let take = Recording(fileName: "\(UUID()).m4a", duration: 12, createdAt: date)
        take.exercise = exercise
        take.loop = loop
        return take
    }

    // MARK: - unit(for:)

    func testANoteAndATakeOnOneExerciseShareAUnit() {
        let note = JournalTimeline.Item.note(drillNote(90, at: noon))
        let recording = JournalTimeline.Item.take(take(at: noon, exercise: drill))
        let expected = JournalTimeline.UnitRef(kind: .exercise, uid: drill.uid)
        XCTAssertEqual(JournalTimeline.unit(for: note), expected)
        XCTAssertEqual(JournalTimeline.unit(for: recording), expected)
    }

    func testAPieceBelongsToItsLoop() {
        let piece = JournalPiece(loop: riff, piece: PieceTranscription(taps: [], openMidi: [], tuningLabel: ""),
                                 date: noon)
        XCTAssertEqual(JournalTimeline.unit(for: .piece(piece)),
                       JournalTimeline.UnitRef(kind: .loop, uid: riff.uid))
    }

    /// A row with no unit gets no count and no thread: an orphan, a Just me take, a song's take.
    func testRowsThatBelongToNoUnitHaveNone() {
        let orphan = JournalEntry.forExercise(text: "n", kind: .note, commandBpmAtEntry: 90, createdAt: noon)
        let standalone = take(at: noon)
        let songTake = take(at: noon)
        songTake.song = Song.sample()
        XCTAssertNil(JournalTimeline.unit(for: .note(orphan)))
        XCTAssertNil(JournalTimeline.unit(for: .take(standalone)))
        XCTAssertNil(JournalTimeline.unit(for: .take(songTake)))
    }

    func testUnitNameIsTheLoopsOrTheExercises() {
        XCTAssertEqual(JournalTimeline.unitName(for: .note(drillNote(90, at: noon))), "Spider")
        XCTAssertEqual(JournalTimeline.unitName(for: .note(riffNote(mastery: 2, tempo: 0.8, at: noon))),
                       "Verse riff")
        XCTAssertEqual(JournalTimeline.unitName(loop: Loop(name: "", start: 0, end: 1, speed: 1, repeats: 1),
                                                exercise: nil), "Loop")
    }

    // MARK: - counts and filter

    func testCountsAreOnePerItemPerUnitAndSkipRowsWithNoUnit() {
        let orphan = JournalEntry.forExercise(text: "n", kind: .note, commandBpmAtEntry: 90, createdAt: noon)
        let items = JournalTimeline.merge(
            entries: [drillNote(80, at: noon), drillNote(84, at: noon - day),
                      drillNote(70, at: noon, on: otherDrill), riffNote(mastery: 2, tempo: 0.8, at: noon), orphan],
            takes: [take(at: noon, exercise: drill)])
        let counts = JournalTimeline.unitCounts(items)
        XCTAssertEqual(counts[JournalTimeline.UnitRef(kind: .exercise, uid: drill.uid)], 3)
        XCTAssertEqual(counts[JournalTimeline.UnitRef(kind: .exercise, uid: otherDrill.uid)], 1)
        XCTAssertEqual(counts[JournalTimeline.UnitRef(kind: .loop, uid: riff.uid)], 1)
        XCTAssertEqual(counts.values.reduce(0, +), 5, "the orphan was counted against something")
    }

    /// The count follows the scope picker: the feed counts what it was given, so under Takes a unit with
    /// one take and five notes shows no count.
    func testCountsFollowTheScope() {
        let items = JournalTimeline.merge(entries: [drillNote(80, at: noon), drillNote(84, at: noon - day)],
                                          takes: [take(at: noon, exercise: drill)])
        let unit = JournalTimeline.UnitRef(kind: .exercise, uid: drill.uid)
        XCTAssertEqual(JournalTimeline.unitCounts(JournalTimeline.filter(items, scope: .notes))[unit], 2)
        XCTAssertEqual(JournalTimeline.unitCounts(JournalTimeline.filter(items, scope: .takes))[unit], 1)
    }

    func testFilterKeepsOnlyThatUnitInOrder() {
        let mine = [drillNote(80, at: noon), drillNote(84, at: noon - day)]
        let items = JournalTimeline.merge(entries: mine + [drillNote(70, at: noon, on: otherDrill)],
                                          takes: [take(at: noon - 2 * day, exercise: drill)])
        let thread = JournalTimeline.filter(items, unit: JournalTimeline.UnitRef(kind: .exercise, uid: drill.uid))
        XCTAssertEqual(thread.count, 3)
        XCTAssertEqual(thread.map(\.date), thread.map(\.date).sorted(by: >))
        XCTAssertTrue(thread.allSatisfy { JournalTimeline.unitName(for: $0) == "Spider" })
    }

    // MARK: - readingSpan

    func testSpanIsTheFirstAndLatestByDateWhateverTheOrder() throws {
        // Newest first, as the feed sorts — the span must still read oldest to newest.
        let items = JournalTimeline.merge(entries: [drillNote(96, at: noon), drillNote(88, at: noon - day),
                                                    drillNote(80, at: noon - 2 * day)], takes: [])
        let span = try XCTUnwrap(JournalTimeline.readingSpan(items))
        XCTAssertEqual(span.first, .bpm(80, notesPerBeat: 2))
        XCTAssertEqual(span.latest, .bpm(96, notesPerBeat: 2))
        XCTAssertEqual(span.since, noon - 2 * day)
        XCTAssertEqual(span.bpmText, "80 → 96 BPM · 8ths")
    }

    /// A change of rhythm shows both ends whole: 80 in sixteenths is not 80 in eighths.
    func testSpanNamesBothRhythmsWhenTheyDiffer() throws {
        let items = JournalTimeline.merge(entries: [drillNote(96, rate: 2, at: noon),
                                                    drillNote(80, rate: 4, at: noon - day)], takes: [])
        XCTAssertEqual(try XCTUnwrap(JournalTimeline.readingSpan(items)).bpmText,
                       "80 BPM · 16ths → 96 BPM · 8ths")
    }

    func testSpanIsNilWithFewerThanTwoReadingsOrEqualEnds() {
        let one = JournalTimeline.merge(entries: [drillNote(90, at: noon), drillNote(nil, at: noon - day)],
                                        takes: [take(at: noon, exercise: drill)])
        XCTAssertNil(JournalTimeline.readingSpan(one), "one reading is nothing to compare")
        let same = JournalTimeline.merge(entries: [drillNote(90, at: noon), drillNote(70, at: noon - day),
                                                   drillNote(90, at: noon - 2 * day)], takes: [])
        XCTAssertNil(JournalTimeline.readingSpan(same), "equal ends would say one fact twice")
    }

    func testALoopsSpanReadsMasteryAndPercent() throws {
        let items = JournalTimeline.merge(entries: [riffNote(mastery: 3, tempo: 0.9, at: noon),
                                                    riffNote(mastery: nil, tempo: nil, at: noon - day),
                                                    riffNote(mastery: 2, tempo: 0.75, at: noon - 2 * day)], takes: [])
        let span = try XCTUnwrap(JournalTimeline.readingSpan(items))
        XCTAssertEqual(span.first, .loop(mastery: 2, percent: 75))
        XCTAssertEqual(span.latest, .loop(mastery: 3, percent: 90))
        XCTAssertNil(span.bpmText)
    }
}
