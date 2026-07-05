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
                          template: String = ExerciseTemplate.basic.displayName) -> ExerciseSortFields {
        ExerciseSortFields(name: name, command: command, dateAdded: dateAdded, templateName: template)
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
