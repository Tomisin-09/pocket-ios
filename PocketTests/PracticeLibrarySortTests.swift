import XCTest
@testable import Pocket

/// Covers the pure ordering + search for the two Practice unit libraries (ADR 0056) — the sort
/// comparators and the descending flip that break silently otherwise. Works on the projection
/// field structs directly (the identity closure), so no SwiftData / model graph is involved.
final class PracticeLibrarySortTests: XCTestCase {

    // MARK: - Loops

    private func loop(_ name: String, song: String = "", command: Double = 1.0,
                      mastery: Int? = nil) -> LoopSortFields {
        LoopSortFields(name: name, songTitle: song, command: command, mastery: mastery)
    }

    private func sortedLoops(_ items: [LoopSortFields], by key: LoopSortKey,
                             ascending: Bool = true) -> [String] {
        PracticeLibrarySort.sortedLoops(items, by: key, ascending: ascending) { $0 }.map(\.name)
    }

    func testLoopsByNameAscending() {
        let loops = [loop("Chorus"), loop("Bridge"), loop("Verse")]
        XCTAssertEqual(sortedLoops(loops, by: .name), ["Bridge", "Chorus", "Verse"])
    }

    func testLoopsByNameDescendingFlipsWholeList() {
        let loops = [loop("Chorus"), loop("Bridge"), loop("Verse")]
        XCTAssertEqual(sortedLoops(loops, by: .name, ascending: false), ["Verse", "Chorus", "Bridge"])
    }

    func testLoopsBySongThenName() {
        let loops = [loop("Solo", song: "Red Moon"), loop("Intro", song: "Apex"),
                     loop("Bridge", song: "Red Moon")]
        XCTAssertEqual(sortedLoops(loops, by: .song), ["Intro", "Bridge", "Solo"])
    }

    func testLoopsByCommandTempoAscending() {
        let loops = [loop("A", command: 0.9), loop("B", command: 0.5), loop("C", command: 0.7)]
        XCTAssertEqual(sortedLoops(loops, by: .commandTempo), ["B", "C", "A"])
    }

    func testLoopsByMasteryUnratedSortsLastAscending() {
        let loops = [loop("Rated5", mastery: 5), loop("Unrated", mastery: nil),
                     loop("Rated2", mastery: 2)]
        XCTAssertEqual(sortedLoops(loops, by: .mastery), ["Rated2", "Rated5", "Unrated"])
    }

    func testLoopsByMasteryDescendingPutsUnratedFirst() {
        let loops = [loop("Rated5", mastery: 5), loop("Unrated", mastery: nil),
                     loop("Rated2", mastery: 2)]
        XCTAssertEqual(sortedLoops(loops, by: .mastery, ascending: false),
                       ["Unrated", "Rated5", "Rated2"])
    }

    func testLoopSearchMatchesNameOrSong() {
        XCTAssertTrue(PracticeLibrarySort.loopMatches(loop("Chorus", song: "Red Moon"), query: "moon"))
        XCTAssertTrue(PracticeLibrarySort.loopMatches(loop("Chorus", song: "Red Moon"), query: "cho"))
        XCTAssertFalse(PracticeLibrarySort.loopMatches(loop("Chorus", song: "Red Moon"), query: "verse"))
        XCTAssertTrue(PracticeLibrarySort.loopMatches(loop("Chorus"), query: "   "))
    }

    // MARK: - Exercises

    private func exercise(_ name: String, command: Int = 100,
                          dateAdded: Date = Date(timeIntervalSince1970: 0),
                          notesPerBeat: Int = 1,
                          template: String = ExerciseTemplate.basic.displayName,
                          instrument: Instrument = .guitar) -> ExerciseSortFields {
        ExerciseSortFields(name: name, command: command, dateAdded: dateAdded,
                           notesPerBeat: notesPerBeat, templateName: template,
                           instrument: instrument)
    }

    private func sortedExercises(_ items: [ExerciseSortFields], by key: ExerciseSortKey,
                                 ascending: Bool = true) -> [String] {
        PracticeLibrarySort.sortedExercises(items, by: key, ascending: ascending) { $0 }.map(\.name)
    }

    func testExercisesByNameAscending() {
        let drills = [exercise("Spider"), exercise("Alternating"), exercise("Legato")]
        XCTAssertEqual(sortedExercises(drills, by: .name), ["Alternating", "Legato", "Spider"])
    }

    func testExercisesByCommandTempoAscending() {
        let drills = [exercise("A", command: 120), exercise("B", command: 80), exercise("C", command: 100)]
        XCTAssertEqual(sortedExercises(drills, by: .commandTempo), ["B", "C", "A"])
    }

    /// The regression the whole slice exists for: the seeded *Spider Walk* (80 @ sixteenths = 320
    /// notes/min) and *Chord Changes* (70 @ quarters = 70) are a 4.5× difference that raw BPM read as
    /// 14%, sorting them as near-neighbours in the wrong order.
    func testExercisesByCommandTempoRanksOnNotesPerMinuteNotBareBPM() {
        let drills = [exercise("Spider Walk", command: 80, notesPerBeat: 4),
                      exercise("Chord Changes", command: 70, notesPerBeat: 1),
                      exercise("Scale Runs", command: 80, notesPerBeat: 2)]
        XCTAssertEqual(sortedExercises(drills, by: .commandTempo),
                       ["Chord Changes", "Scale Runs", "Spider Walk"])
    }

    /// Equal note speed at different tempos (80 @ eighths and 40 @ sixteenths are both 160 npm) falls
    /// back to the bare BPM, so the order still matches the numbers on screen rather than being
    /// resolved alphabetically.
    func testEqualNotesPerMinuteFallsBackToBareBPM() {
        let drills = [exercise("Alpha", command: 80, notesPerBeat: 2),
                      exercise("Beta", command: 40, notesPerBeat: 4)]
        XCTAssertEqual(sortedExercises(drills, by: .commandTempo), ["Beta", "Alpha"])
    }

    /// A rhythm-less drill (`notesPerBeat` defaulted to 1) compares as its bare BPM rather than
    /// dropping out of the ordering.
    func testExercisesWithNoDeclaredRhythmCompareAsBareBPM() {
        let drills = [exercise("A", command: 120), exercise("B", command: 80), exercise("C", command: 100)]
        XCTAssertEqual(sortedExercises(drills, by: .commandTempo), ["B", "C", "A"])
    }

    func testExercisesByRecentlyAddedIsNewestFirst() {
        let drills = [exercise("Old", dateAdded: Date(timeIntervalSince1970: 100)),
                      exercise("New", dateAdded: Date(timeIntervalSince1970: 300)),
                      exercise("Mid", dateAdded: Date(timeIntervalSince1970: 200))]
        XCTAssertEqual(sortedExercises(drills, by: .recentlyAdded), ["New", "Mid", "Old"])
    }

    func testExercisesByRecentlyAddedDescendingIsOldestFirst() {
        let drills = [exercise("Old", dateAdded: Date(timeIntervalSince1970: 100)),
                      exercise("New", dateAdded: Date(timeIntervalSince1970: 300)),
                      exercise("Mid", dateAdded: Date(timeIntervalSince1970: 200))]
        XCTAssertEqual(sortedExercises(drills, by: .recentlyAdded, ascending: false),
                       ["Old", "Mid", "New"])
    }

    func testExerciseSearchMatchesName() {
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(exercise("Alternating picking"), query: "pick"))
        XCTAssertFalse(PracticeLibrarySort.exerciseMatches(exercise("Alternating picking"), query: "legato"))
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(exercise("Spider"), query: ""))
    }

    // MARK: - Instrument filter (ADR 0116 S4)

    func testExerciseMatchesNilInstrumentFilterMatchesEveryInstrument() {
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(exercise("Spider", instrument: .guitar),
                                                          query: "", instrument: nil))
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(exercise("Walk", instrument: .bass),
                                                          query: "", instrument: nil))
    }

    func testExerciseMatchesNarrowsToTheSelectedInstrument() {
        let bass = exercise("Walking line", instrument: .bass)
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(bass, query: "", instrument: .bass))
        XCTAssertFalse(PracticeLibrarySort.exerciseMatches(bass, query: "", instrument: .guitar))
    }

    func testExerciseMatchesRequiresBothSearchAndInstrument() {
        let bass = exercise("Walking line", instrument: .bass)
        // Right instrument, wrong search → no match; right search, wrong instrument → no match.
        XCTAssertFalse(PracticeLibrarySort.exerciseMatches(bass, query: "legato", instrument: .bass))
        XCTAssertFalse(PracticeLibrarySort.exerciseMatches(bass, query: "walk", instrument: .guitar))
        XCTAssertTrue(PracticeLibrarySort.exerciseMatches(bass, query: "walk", instrument: .bass))
    }

    func testInstrumentsPresentIsDistinctAndInCanonicalOrder() {
        // Out-of-order, with duplicates → deduped, canonical (guitar before bass).
        XCTAssertEqual(PracticeLibrarySort.instrumentsPresent([.bass, .guitar, .bass, .guitar]),
                       [.guitar, .bass])
    }

    func testInstrumentsPresentDrivesProgressiveDisclosureThreshold() {
        // Single-instrument library → count 1 → filter stays hidden.
        XCTAssertEqual(PracticeLibrarySort.instrumentsPresent([.guitar, .guitar]).count, 1)
        XCTAssertTrue(PracticeLibrarySort.instrumentsPresent([]).isEmpty)
        // Mixed → count 2 → filter appears.
        XCTAssertEqual(PracticeLibrarySort.instrumentsPresent([.guitar, .bass]).count, 2)
    }

    // MARK: - Template sections (ADR 0068, revised)

    private func sections(_ items: [ExerciseSortFields], by key: ExerciseSortKey = .name,
                          ascending: Bool = true) -> [(title: String, names: [String])] {
        PracticeLibrarySort.exerciseSections(items, sortedBy: key, ascending: ascending) { $0 }
            .map { ($0.title, $0.items.map(\.name)) }
    }

    func testSectionsGroupByTemplateAlphabeticallyWithItemsSortedWithin() {
        let drills = [exercise("Down Up", template: "Strumming"),
                      exercise("Major", template: "Scales"),
                      exercise("All Down", template: "Strumming")]
        let result = sections(drills, by: .name)
        XCTAssertEqual(result.map(\.title), ["Scales", "Strumming"])
        XCTAssertEqual(result[0].names, ["Major"])
        XCTAssertEqual(result[1].names, ["All Down", "Down Up"])   // name-sorted within
    }

    func testBasicTemplateIsAnOrdinaryAlphabeticalSection() {
        // "Basic" is a real template section (no "Uncategorized" leftover bucket), ordered
        // alphabetically with the rest — Basic < Chords < Warm-up.
        let drills = [exercise("Loose"), exercise("Chorded", template: "Chords"),
                      exercise("Warm", template: "Warm-up")]
        XCTAssertEqual(sections(drills).map(\.title), ["Basic", "Chords", "Warm-up"])
    }

    func testSectionsHonorTheChosenSortKeyWithinSection() {
        let drills = [exercise("Slow", command: 60, template: "Scales"),
                      exercise("Fast", command: 140, template: "Scales")]
        let result = sections(drills, by: .commandTempo)
        XCTAssertEqual(result[0].names, ["Slow", "Fast"])   // ascending command within the section
    }
}
