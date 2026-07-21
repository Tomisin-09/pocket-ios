import XCTest
@testable import Pocket

/// `JournalTimeline` merges journal notes + audio takes into one newest-first feed, filters by
/// scope, and derives an owner label for the aggregated Journal space. Pure logic — models are
/// built **uninserted** (no `ModelContext`), which is safe for property reads and avoids the
/// XCTest-host insert trap.
final class JournalTimelineTests: XCTestCase {

    // 2023-11-14 12:00:00 GMT, plus offsets — deterministic, no force-unwraps.
    private let noon = Date(timeIntervalSince1970: 1_699_963_200)
    private let hour: TimeInterval = 3_600

    private func note(at date: Date, kind: EntryKind = .note) -> JournalEntry {
        JournalEntry.forExercise(text: "n", kind: kind, commandBpmAtEntry: 90, createdAt: date)
    }

    private func take(at date: Date) -> Recording {
        Recording(fileName: "\(UUID()).m4a", duration: 12, createdAt: date)
    }

    // MARK: - merge

    func testMergeInterleavesNewestFirst() {
        let entries = [note(at: noon), note(at: noon - 2 * hour)]
        let takes = [take(at: noon - 1 * hour), take(at: noon + 1 * hour)]
        let items = JournalTimeline.merge(entries: entries, takes: takes)

        XCTAssertEqual(items.count, 4)
        // Newest → oldest: take(+1h), note(0), take(-1h), note(-2h).
        XCTAssertTrue(items[0].isTake)
        XCTAssertTrue(items[1].isNote)
        XCTAssertTrue(items[2].isTake)
        XCTAssertTrue(items[3].isNote)
        XCTAssertEqual(items.map(\.date), items.map(\.date).sorted(by: >))
    }

    func testMergeEmpty() {
        XCTAssertTrue(JournalTimeline.merge(entries: [], takes: []).isEmpty)
    }

    // MARK: - filter

    func testFilterByScope() {
        let items = JournalTimeline.merge(entries: [note(at: noon), note(at: noon - hour)],
                                          takes: [take(at: noon - 2 * hour)])
        XCTAssertEqual(JournalTimeline.filter(items, scope: .all).count, 3)
        XCTAssertEqual(JournalTimeline.filter(items, scope: .notes).count, 2)
        XCTAssertEqual(JournalTimeline.filter(items, scope: .takes).count, 1)
        XCTAssertTrue(JournalTimeline.filter(items, scope: .notes).allSatisfy(\.isNote))
        XCTAssertTrue(JournalTimeline.filter(items, scope: .takes).allSatisfy(\.isTake))
    }

    // MARK: - ownerLabel

    func testOwnerLabelLoopWithSong() {
        let loop = Loop(name: "Verse riff", start: 0.1, end: 0.3, speed: 1.0, repeats: 1)
        let song = Song.sample()
        song.title = "Little Wing"
        loop.song = song
        let entry = JournalEntry.forLoop(text: "n", kind: .note, masteryAtEntry: 2,
                                         commandTempoAtEntry: 0.95)
        entry.loop = loop
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(entry)), "Little Wing · Verse riff")
    }

    func testOwnerLabelLoopWithoutSong() {
        let loop = Loop(name: "F barre", start: 0.1, end: 0.3, speed: 1.0, repeats: 1)
        let entry = JournalEntry.forLoop(text: "n", kind: .note, masteryAtEntry: nil,
                                         commandTempoAtEntry: nil)
        entry.loop = loop
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(entry)), "F barre")
    }

    func testOwnerLabelExercise() {
        let exercise = Exercise(name: "Chords", currentTempo: 80, commandTempo: 96)
        let entry = note(at: noon)
        entry.exercise = exercise
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(entry)), "Chords · exercise")
    }

    func testOwnerLabelSongTake() {
        let song = Song.sample()
        song.title = "Apex"
        let recording = Recording(fileName: "t.m4a", duration: 5, song: song)
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .take(recording)), "Apex")
    }

    func testOwnerLabelOrphanIsNil() {
        XCTAssertNil(JournalTimeline.ownerLabel(for: .take(take(at: noon))))
    }

    // MARK: - templateLabel

    func testTemplateLabelForExercise() {
        let exercise = Exercise(name: "Box drill", currentTempo: 80, commandTempo: 96)
        exercise.templateRaw = ExerciseTemplate.scales.rawValue
        let entry = note(at: noon)
        entry.exercise = exercise
        XCTAssertEqual(JournalTimeline.templateLabel(for: .note(entry)), "Scales")
    }

    func testTemplateLabelNilForTake() {
        XCTAssertNil(JournalTimeline.templateLabel(for: .take(take(at: noon))))
    }

    // MARK: - search

    func testSearchEmptyReturnsAll() {
        let items = JournalTimeline.merge(entries: [note(at: noon)], takes: [take(at: noon)])
        XCTAssertEqual(JournalTimeline.filter(items, query: "   ").count, 2)
    }

    func testSearchByExerciseName() {
        let one = note(at: noon)
        one.exercise = Exercise(name: "Alternate picking", currentTempo: 80, commandTempo: 96)
        let two = note(at: noon)
        two.exercise = Exercise(name: "Chord changes", currentTempo: 60, commandTempo: 80)
        let items: [JournalTimeline.Item] = [.note(one), .note(two)]
        let hits = JournalTimeline.filter(items, query: "picking")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(JournalTimeline.ownerLabel(for: hits[0]), "Alternate picking · exercise")
    }

    func testSearchByTemplate() {
        let exercise = Exercise(name: "Box drill", currentTempo: 80, commandTempo: 96)
        exercise.templateRaw = ExerciseTemplate.scales.rawValue
        let entry = note(at: noon)
        entry.exercise = exercise
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "scales").count, 1)
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "chords").count, 0)
    }

    func testSearchTokensAreAndedAndDateMatches() {
        let exercise = Exercise(name: "Box drill", currentTempo: 80, commandTempo: 96)
        exercise.templateRaw = ExerciseTemplate.scales.rawValue
        let entry = note(at: noon)
        entry.exercise = exercise
        let items: [JournalTimeline.Item] = [.note(entry)]
        // A date token drawn from the same formatter the haystack uses → locale-independent.
        let dateToken = noon.formatted(date: .abbreviated, time: .omitted)
            .split(separator: " ").first.map(String.init) ?? ""
        XCTAssertEqual(JournalTimeline.filter(items, query: "scales \(dateToken)").count, 1)
        XCTAssertEqual(JournalTimeline.filter(items, query: "scales chords").count, 0)
    }
}
