import XCTest
@testable import Pocket

/// **The owner picker's rules** (ADR 0264 D5, D6, D8): which places *Attach to…* offers, which carry a
/// lock, which can't take this source, and in what order. On values, as the share extension will hand
/// them over from its snapshot.
final class ReferenceDestinationPickerTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 86_400

    // MARK: - What is offered (D6)

    func testNeverBoughtIsOfferedSongsAndLoopsOnly() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .neverBought)
        XCTAssertEqual(rows.map(\.destination.kind), [.song, .loop])
        XCTAssertFalse(rows.contains(where: \.isLocked))
    }

    func testLapsedIsOfferedEverythingWithExercisesAndRoutinesLocked() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .lapsed)
        XCTAssertEqual(rows.map(\.destination.kind), [.exercise, .routine, .song, .loop])
        XCTAssertEqual(rows.filter(\.isLocked).map(\.destination.kind), [.exercise, .routine])
        XCTAssertTrue(rows.allSatisfy(\.isPickable), "a lock still takes the reference")
    }

    func testOnThePlanNothingIsLocked() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .onPlan)
        XCTAssertEqual(rows.count, 4)
        XCTAssertFalse(rows.contains(where: \.isLocked))
    }

    // MARK: - What can't take this source

    func testThePlacesASourceIsOnAreAlreadyHere() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .onPlan, alreadyOn: ["song:s"])
        XCTAssertEqual(rows.filter { !$0.isPickable }.map(\.id), ["song:s"])
        XCTAssertEqual(rows.first { $0.id == "song:s" }?.unavailable, "already here")
    }

    /// A full place can't take a file; and a place it's already on says so first, being the truer reason.
    func testAFullPlaceIsFullUnlessTheSourceIsAlreadyThere() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .onPlan, alreadyOn: ["song:s"],
                                                   full: ["song:s", "exercise:e"])
        XCTAssertEqual(rows.first { $0.id == "song:s" }?.unavailable, "already here")
        XCTAssertEqual(rows.first { $0.id == "exercise:e" }?.unavailable, "has 5 files")
        XCTAssertNil(rows.first { $0.id == "loop:l" }?.unavailable)
    }

    // MARK: - The row's words

    func testTheSecondLineNamesTheKindAndItsParent() {
        let rows = ReferenceDestinationPicker.rows(everyKind, for: .onPlan)
        XCTAssertEqual(rows.map(\.detail), ["Exercise", "Routine", "Song · Jack Trader", "Loop · Slow Bend"])
        let noArtist = ReferenceDestination(id: "song:x", kind: .song, name: "Demo", parent: "")
        XCTAssertEqual(noArtist.detail, "Song", "an empty artist adds nothing")
    }

    func testALockedOrUnavailableRowSaysWhyAfterItsKind() {
        let lapsed = ReferenceDestinationPicker.rows(everyKind, for: .lapsed, alreadyOn: ["song:s"])
        XCTAssertEqual(lapsed.first { $0.id == "exercise:e" }?.detail, "Exercise · opens with the plan")
        XCTAssertEqual(lapsed.first { $0.id == "song:s" }?.detail, "Song · Jack Trader · already here")
    }

    // MARK: - Recent

    func testRecentIsWhatWasPractisedNewestFirst() {
        let rows = ReferenceDestinationPicker.rows([
            place("exercise:old", .exercise, "Old", practised: now - 3 * day),
            place("exercise:never", .exercise, "Never"),
            place("song:new", .song, "New", practised: now),
            place("routine:mid", .routine, "Mid", practised: now - day)
        ], for: .onPlan)
        XCTAssertEqual(ReferenceDestinationPicker.recent(rows).map(\.id), ["song:new", "routine:mid", "exercise:old"])
    }

    func testRecentStopsAtItsLimit() {
        let many = (0..<8).map { place("exercise:\($0)", .exercise, "Drill \($0)", practised: now - Double($0) * day) }
        let recent = ReferenceDestinationPicker.recent(ReferenceDestinationPicker.rows(many, for: .onPlan))
        XCTAssertEqual(recent.count, ReferenceDestinationPicker.recentLimit)
        XCTAssertEqual(recent.first?.id, "exercise:0")
    }

    /// Practised on the same day, as a song and its loops are: by kind, then by name, so it never jitters.
    func testATieInRecencyFallsBackToKindThenName() {
        let rows = ReferenceDestinationPicker.rows([
            place("loop:b", .loop, "Bridge", parent: "Slow Bend", practised: now),
            place("song:s", .song, "Slow Bend", practised: now),
            place("loop:a", .loop, "Archive", parent: "Slow Bend", practised: now)
        ], for: .onPlan)
        XCTAssertEqual(ReferenceDestinationPicker.recent(rows).map(\.id), ["song:s", "loop:a", "loop:b"])
    }

    // MARK: - Show everything

    func testEverythingGroupsByKindInPracticeOrderAndByName() {
        let rows = ReferenceDestinationPicker.rows([
            place("song:z", .song, "Zephyr"),
            // By name these two would read Chorus, Verse; by song, Alpha's Verse comes first.
            place("loop:x", .loop, "Chorus", parent: "Bravo"),
            place("exercise:b", .exercise, "Spider"),
            place("loop:y", .loop, "Verse", parent: "Alpha"),
            place("exercise:a", .exercise, "Arpeggio"),
            place("song:a", .song, "Alpha")
        ], for: .onPlan)
        let groups = ReferenceDestinationPicker.groups(rows)
        XCTAssertEqual(groups.map(\.title), ["Exercises", "Songs", "Loops"], "no routines, so no empty section")
        XCTAssertEqual(groups.map { $0.rows.map(\.id) },
                       [["exercise:a", "exercise:b"], ["song:a", "song:z"], ["loop:y", "loop:x"]],
                       "a loop sorts under its song first")
    }

    // MARK: - Search

    func testASearchFindsANameOrAParentIgnoringCaseAndAccents() {
        let rows = ReferenceDestinationPicker.rows([
            place("song:c", .song, "Café Blues", parent: "Jack Trader"),
            place("loop:l", .loop, "Intro bend", parent: "Slow Bend"),
            place("exercise:e", .exercise, "Spider")
        ], for: .onPlan)
        XCTAssertEqual(ReferenceDestinationPicker.matching(rows, "cafe").map(\.id), ["song:c"])
        XCTAssertEqual(ReferenceDestinationPicker.matching(rows, "TRADER").map(\.id), ["song:c"])
        XCTAssertEqual(ReferenceDestinationPicker.matching(rows, "bend").map(\.id), ["loop:l"])
        XCTAssertEqual(ReferenceDestinationPicker.matching(rows, "  ").count, 3, "a blank search hides nothing")
    }

    func testSearchResultsPutWhatWasPractisedFirst() {
        let rows = ReferenceDestinationPicker.rows([
            place("exercise:a", .exercise, "Bend drill A"),
            place("exercise:b", .exercise, "Bend drill B", practised: now)
        ], for: .onPlan)
        XCTAssertEqual(ReferenceDestinationPicker.matching(rows, "bend").map(\.id), ["exercise:b", "exercise:a"])
    }

    /// The search can't find what a free player isn't offered, so its prompt doesn't name it.
    func testThePromptAndEverythingRowNameWhatTheyCanFind() {
        XCTAssertEqual(ReferenceDestinationPicker.searchPrompt(for: .neverBought), "Search songs and loops")
        XCTAssertEqual(ReferenceDestinationPicker.searchPrompt(for: .lapsed), "Search songs, loops, exercises…")
        XCTAssertEqual(ReferenceDestinationPicker.everythingTitle(for: .neverBought), "Show all songs and loops")
        XCTAssertEqual(ReferenceDestinationPicker.everythingTitle(for: .onPlan), "Show everything")
    }

    // MARK: - From the models

    /// The key a destination is built with is the key an owner is looked up by, for all four kinds:
    /// otherwise *already here* would mark nothing, and a pick would find no owner.
    func testAnOwnersKeyIsItsDestinationsId() {
        let drill = Exercise(name: "Spider")
        let routine = Routine(name: "Week 3")
        let song = Song(title: "Slow Bend", artist: "Jack Trader", duration: 180,
                        ref: SongRef(id: "song-source", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Intro bend", start: 0, end: 1, speed: 1, repeats: 4)
        XCTAssertEqual(ReferenceDestination.key(of: drill), ReferenceDestination(exercise: drill).id)
        XCTAssertEqual(ReferenceDestination.key(of: routine), ReferenceDestination(routine: routine).id)
        XCTAssertEqual(ReferenceDestination.key(of: song), ReferenceDestination(song: song).id)
        XCTAssertEqual(ReferenceDestination.key(of: loop), ReferenceDestination(loop: loop).id)
        XCTAssertEqual(ReferenceDestination(song: song).id, "song:song-source", "a song goes by its import identity")
        XCTAssertNil(ReferenceDestination.key(of: KeepForLater()), "keep for later is no place")
    }

    func testALoopTakesItsSongsNameAndDate() {
        let song = Song(title: "Slow Bend", duration: 180, lastPracticed: now,
                        ref: SongRef(id: "song-source", source: .localFile, bookmark: nil))
        let loop = Loop(name: "  ", start: 0, end: 1, speed: 1, repeats: 4)
        loop.song = song
        let destination = ReferenceDestination(loop: loop)
        XCTAssertEqual(destination.name, "Untitled")
        XCTAssertEqual(destination.parent, "Slow Bend")
        XCTAssertEqual(destination.lastPracticed, now)
        XCTAssertEqual(destination.detail, "Loop · Slow Bend")
    }

    // MARK: - Helpers

    /// One of each kind, in the order `rows` keeps them.
    private var everyKind: [ReferenceDestination] {
        [place("exercise:e", .exercise, "Triad climb"),
         place("routine:r", .routine, "Morning routine"),
         place("song:s", .song, "Slow Bend", parent: "Jack Trader"),
         place("loop:l", .loop, "Intro bend", parent: "Slow Bend")]
    }

    private func place(_ id: String, _ kind: ReferencePlaceKind, _ name: String, parent: String? = nil,
                       practised: Date? = nil) -> ReferenceDestination {
        ReferenceDestination(id: id, kind: kind, name: name, parent: parent, lastPracticed: practised)
    }
}
