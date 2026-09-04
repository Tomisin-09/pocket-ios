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
        XCTAssertNil(JournalTimeline.ownerLabel(for: .take(take(at: noon))),
                     "a take with neither a live owner nor a snapshot — a pre-0151 row — reads nil")
    }

    // MARK: - Surviving the owner (ADR 0151)

    func testAnOrphanedTakeFallsBackToItsSnapshottedCaption() {
        let orphan = take(at: noon)
        orphan.ownerLabelAtTake = "Little Wing · Verse riff"
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .take(orphan)), "Little Wing · Verse riff")
    }

    func testAnOrphanedNoteFallsBackToItsSnapshottedCaption() {
        let orphan = note(at: noon)
        orphan.ownerLabelAtEntry = "Spider · exercise"
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(orphan)), "Spider · exercise")
    }

    // MARK: - Belonging to nothing (ADR 0155)

    /// A standalone note renders with **no caption** — it was never about a unit, so there is nothing
    /// to attribute it to.
    func testAStandaloneNoteHasNoOwnerCaption() {
        let entry = JournalEntry.forStandalone(text: "strings are dead", kind: .note)
        XCTAssertNil(JournalTimeline.ownerLabel(for: .note(entry)))
    }

    /// The guarantee, stated as the failure it prevents: a standalone note must not pick up a caption
    /// even if one were somehow stamped on it. The orphan fallback above is deliberately *not*
    /// reached here — that fallback is what makes a deleted unit's note still say what it was about,
    /// and applying it to a note that never had an owner would invent the subject ADR 0155 exists to
    /// stop being invented.
    func testAStandaloneNoteIgnoresAStrayCaptionSnapshot() {
        let entry = JournalEntry.forStandalone(text: "wrist tightens after work", kind: .struggle)
        entry.ownerLabelAtEntry = "Spider · exercise"

        XCTAssertNil(JournalTimeline.ownerLabel(for: .note(entry)),
                     "the standalone branch must be read before the orphan fallback")
    }

    /// The live owner wins while it exists, so renaming a loop still moves its takes' captions —
    /// the snapshot is a fallback, not a freeze. (A *session* note is the deliberate exception: its
    /// snapshot always wins, because ADR 0038 says it records what the sitting was called.)
    func testALiveOwnerOutranksTheSnapshot() {
        let exercise = Exercise(name: "Renamed", currentTempo: 80, commandTempo: 96)
        let entry = note(at: noon)
        entry.exercise = exercise
        entry.ownerLabelAtEntry = "Stale · exercise"
        XCTAssertEqual(JournalTimeline.ownerLabel(for: .note(entry)), "Renamed · exercise")
    }

    /// An orphan stays findable: the caption feeds the haystack, so searching the deleted loop's
    /// song still surfaces the take made against it.
    func testAnOrphanedTakeIsStillSearchableByItsSnapshot() {
        let orphan = take(at: noon)
        orphan.ownerLabelAtTake = "Little Wing · Verse riff"
        let kept = JournalTimeline.filter([.take(orphan)], query: "little wing")
        XCTAssertEqual(kept.count, 1)
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

    /// **The feed folds diacritics, like every other search field in the app.** This was the one
    /// matcher that didn't, which is why the backlog gated the journal-review work on collapsing them
    /// — a scope picker built over an inconsistent matcher is a uniform-looking control over
    /// non-uniform behaviour.
    func testSearchIgnoresDiacritics() {
        let entry = note(at: noon)
        entry.exercise = Exercise(name: "Andalusían cadence", currentTempo: 80, commandTempo: 96)
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "andalusian").count, 1)
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "ANDALUSIAN").count, 1,
                       "and case, which it already folded")
    }

    /// Token-AND survives the collapse: the feed's own semantics stay, only the per-token substring
    /// rule was delegated.
    func testTokenAndSemanticsSurviveTheDiacriticFold() {
        let entry = note(at: noon)
        entry.exercise = Exercise(name: "Andalusían cadence", currentTempo: 80, commandTempo: 96)
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "andalusian cadence").count, 1)
        XCTAssertEqual(JournalTimeline.filter([.note(entry)], query: "andalusian arpeggio").count, 0)
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

    // MARK: - Session entries (ADR 0143)

    private func sessionNote(routineName: String, units: [SessionUnitRef]) -> JournalTimeline.Item {
        .note(JournalEntry.forSession(text: "shoulders tight today", kind: .session,
                                      routineUID: UUID(), routineName: routineName, units: units,
                                      createdAt: noon))
    }

    /// The label comes from the entry's **own snapshot**, never from a lookup through `routineUID` —
    /// that is the point of storing the name. Nothing here inserts a `Routine` at all, which is the
    /// assertion: a deleted routine still labels the entries written about it (ADR 0038).
    func testASessionNoteIsLabelledByItsSnapshottedRoutineName() {
        let item = sessionNote(routineName: "Morning warm-up", units: [])

        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Morning warm-up")
    }

    func testAnUnnamedRoutineFallsBackRatherThanShowingAnEmptyCaption() {
        XCTAssertEqual(JournalTimeline.ownerLabel(for: sessionNote(routineName: "", units: [])),
                       "Routine session")
    }

    /// A session note's text is about the *sitting*, so searching a drill's name would otherwise
    /// never surface the session you played it in.
    func testASessionIsFoundByAUnitPractisedInIt() {
        let items = [sessionNote(routineName: "Morning warm-up",
                                 units: [SessionUnitRef(uid: UUID(), title: "Spider", kind: .exercise),
                                         SessionUnitRef(uid: UUID(), title: "Verse riff", kind: .loop)])]

        XCTAssertEqual(JournalTimeline.filter(items, query: "spider").count, 1)
        XCTAssertEqual(JournalTimeline.filter(items, query: "morning spider").count, 1,
                       "the routine name and a unit name AND together")
        XCTAssertEqual(JournalTimeline.filter(items, query: "arpeggios").count, 0)
    }

    func testASessionHasNoTemplateLabel() {
        XCTAssertNil(JournalTimeline.templateLabel(for: sessionNote(routineName: "Warm-up", units: [])))
    }
}
