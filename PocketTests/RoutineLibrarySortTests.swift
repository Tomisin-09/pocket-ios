import XCTest
@testable import Pocket

/// The **Routines** library's pure ordering and search (ADR 0178) — the four sort keys, the
/// descending flip, and what a query is matched against.
///
/// Its own file rather than a fourth section of `PracticeLibrarySortTests`, which is already at
/// SwiftLint's 250-line type-body cap. The split is along the same seam the source uses, so the
/// tests for one library's ordering sit together.
final class RoutineLibrarySortTests: XCTestCase {

    private func routine(_ name: String, added: TimeInterval = 0, notes: String = "",
                         practised: TimeInterval? = nil, minutes: Int = 0) -> RoutineSortFields {
        RoutineSortFields(name: name, dateAdded: Date(timeIntervalSince1970: added), notes: notes,
                          lastPractised: practised.map { Date(timeIntervalSince1970: $0) },
                          estimatedMinutes: minutes)
    }

    private func sortedRoutines(_ items: [RoutineSortFields], by key: RoutineSortKey,
                                ascending: Bool = true) -> [String] {
        PracticeLibrarySort.sortedRoutines(items, by: key, ascending: ascending) { $0 }.map(\.name)
    }

    func testRoutinesByRecentlyAddedPutsTheNewestFirst() {
        let routines = [routine("Old", added: 10), routine("New", added: 300),
                        routine("Middle", added: 100)]
        XCTAssertEqual(sortedRoutines(routines, by: .recentlyAdded), ["New", "Middle", "Old"])
    }

    /// The default key and direction, so the list a player already had is the list they still have.
    func testRecentlyAddedAscendingIsTheOrderTheLibraryHadBefore() {
        let routines = [routine("Old", added: 10), routine("New", added: 300)]
        XCTAssertEqual(sortedRoutines(routines, by: .recentlyAdded),
                       routines.sorted { $0.dateAdded > $1.dateAdded }.map(\.name))
    }

    func testRoutinesByNameAscending() {
        let routines = [routine("Warm-up"), routine("Alt picking"), routine("Scales")]
        XCTAssertEqual(sortedRoutines(routines, by: .name), ["Alt picking", "Scales", "Warm-up"])
    }

    func testRoutinesByLengthPutsTheShortestFirst() {
        let routines = [routine("Long", minutes: 45), routine("Short", minutes: 10),
                        routine("Middle", minutes: 25)]
        XCTAssertEqual(sortedRoutines(routines, by: .length), ["Short", "Middle", "Long"])
    }

    func testRoutinesByLastPractisedPutsTheMostRecentFirst() {
        let routines = [routine("Ages ago", practised: 10), routine("Today", practised: 900),
                        routine("Last week", practised: 400)]
        XCTAssertEqual(sortedRoutines(routines, by: .lastPractised),
                       ["Today", "Last week", "Ages ago"])
    }

    /// A routine never run sorts **last ascending**, not first: `.distantPast` would have read as
    /// "practised longer ago than anything else", a claim about practice that never happened.
    func testANeverPractisedRoutineSortsLastRatherThanOldest() {
        let routines = [routine("Never"), routine("Ages ago", practised: 10),
                        routine("Today", practised: 900)]
        XCTAssertEqual(sortedRoutines(routines, by: .lastPractised),
                       ["Today", "Ages ago", "Never"])
    }

    /// And the descending flip is total — the never-practised routine leads, rather than staying
    /// pinned to the bottom (ADR 0035's rule: `false` reverses the whole list, ties included).
    func testDescendingLastPractisedFlipsTheNeverPractisedRoutineToTheTop() {
        let routines = [routine("Never"), routine("Ages ago", practised: 10),
                        routine("Today", practised: 900)]
        XCTAssertEqual(sortedRoutines(routines, by: .lastPractised, ascending: false),
                       ["Never", "Ages ago", "Today"])
    }

    func testRoutinesTieBreakByNameOnEveryKey() {
        for key in RoutineSortKey.allCases {
            let routines = [routine("Beta"), routine("Alpha")]
            XCTAssertEqual(sortedRoutines(routines, by: key), ["Alpha", "Beta"],
                           "\(key.label) did not break its tie by name")
        }
    }

    // MARK: - Routine search

    func testRoutineSearchMatchesTheName() {
        XCTAssertTrue(PracticeLibrarySort.routineMatches(routine("Morning Routine"), query: "morn"))
    }

    /// The description is searched too (ADR 0177), which is the half a name cannot carry.
    func testRoutineSearchMatchesTheDescription() {
        let fields = routine("Tuesday", notes: "The week 3 sheet, the bits that needed work.")
        XCTAssertTrue(PracticeLibrarySort.routineMatches(fields, query: "week 3"))
    }

    func testRoutineSearchIsCaseAndDiacriticInsensitive() {
        XCTAssertTrue(PracticeLibrarySort.routineMatches(routine("Échauffement"), query: "echauff"))
    }

    func testRoutineSearchRejectsAQueryInNeitherField() {
        let fields = routine("Morning Routine", notes: "Hands first.")
        XCTAssertFalse(PracticeLibrarySort.routineMatches(fields, query: "pentatonic"))
    }

    func testAnEmptyOrWhitespaceQueryMatchesEveryRoutine() {
        XCTAssertTrue(PracticeLibrarySort.routineMatches(routine("Anything"), query: ""))
        XCTAssertTrue(PracticeLibrarySort.routineMatches(routine("Anything"), query: "   "))
    }
}
