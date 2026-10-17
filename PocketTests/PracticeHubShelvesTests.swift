import XCTest
@testable import Pocket

/// The Practice hub's shelf rules (ADR 0257), over plain values.
final class PracticeHubShelvesTests: XCTestCase {

    private let day: TimeInterval = 86_400
    private let base = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Routine shelf (D3)

    private struct Routine {
        let name: String
        var isFavorite = false
        var practised: Date?
        var added = Date(timeIntervalSince1970: 0)
    }

    private func shelf(_ routines: [Routine], limit: Int = 3) -> [String] {
        PracticeHubShelves.routineShelf(routines, limit: limit, placement: {
            .init(isFavorite: $0.isFavorite, lastPractised: $0.practised, dateAdded: $0.added)
        }, id: \.name).map(\.name)
    }

    func testFavouritesComeFirstEvenWhenOthersWerePlayedMoreRecently() {
        let routines = [Routine(name: "Recent", practised: base),
                        Routine(name: "Starred", isFavorite: true, practised: base - 10 * day)]
        XCTAssertEqual(shelf(routines), ["Starred", "Recent"])
    }

    func testThenMostRecentlyPractisedThenNewestAdded() {
        let routines = [Routine(name: "Never, old", added: base - 5 * day),
                        Routine(name: "Played last week", practised: base - 7 * day),
                        Routine(name: "Never, new", added: base),
                        Routine(name: "Played today", practised: base)]
        XCTAssertEqual(shelf(routines, limit: 4),
                       ["Played today", "Played last week", "Never, new", "Never, old"])
    }

    func testFavouritesAreOrderedAmongThemselvesTheSameWay() {
        let routines = [Routine(name: "Fav old", isFavorite: true, practised: base - 3 * day),
                        Routine(name: "Fav new", isFavorite: true, practised: base),
                        Routine(name: "Fav never", isFavorite: true)]
        XCTAssertEqual(shelf(routines), ["Fav new", "Fav old", "Fav never"])
    }

    func testTheShelfStopsAtItsLimit() {
        let routines = (1...5).map { Routine(name: "R\($0)", practised: base - Double($0) * day) }
        XCTAssertEqual(shelf(routines), ["R1", "R2", "R3"])
        XCTAssertEqual(shelf(routines, limit: 0), [])
    }

    func testTiesBreakOnIdSoTheShelfDoesNotReshuffle() {
        let routines = [Routine(name: "B"), Routine(name: "A"), Routine(name: "C")]
        XCTAssertEqual(shelf(routines), ["A", "B", "C"])
    }

    // MARK: - A card's third line (D3)

    func testADeliverableReminderWinsOverHistory() {
        let next = base + day
        XCTAssertEqual(PracticeHubShelves.cardLine(reminder: .next(next), sessions: 5, lastPractised: base),
                       .nextReminder(next))
    }

    /// With notifications denied the card must not name a time (ADR 0186 D7): it falls back to the
    /// routine's history.
    func testAnUndeliverableReminderFallsBackToHistory() {
        for status in [PracticeReminderPlan.Status.notDelivered, .noDays, .off] {
            XCTAssertEqual(PracticeHubShelves.cardLine(reminder: status, sessions: 2, lastPractised: base),
                           .practised(times: 2, last: base), "\(status)")
        }
    }

    func testNeverPractisedAndNoReminderSaysNothing() {
        XCTAssertEqual(PracticeHubShelves.cardLine(reminder: .off, sessions: 0, lastPractised: nil),
                       .nothing)
    }

    func testHistoryLineCountsSessions() {
        XCTAssertNil(PracticeHubShelves.historyLine(sessions: 0, last: base))
        XCTAssertEqual(PracticeHubShelves.historyLine(sessions: 1, last: nil), "Practised once")
        XCTAssertEqual(PracticeHubShelves.historyLine(sessions: 11, last: nil), "Practised 11 times")
        let dated = PracticeHubShelves.historyLine(sessions: 3, last: .now - 3 * day) ?? ""
        XCTAssertTrue(dated.hasPrefix("Practised 3 times · "), dated)
    }

    // MARK: - Category tiles (D5)

    func testTilesFollowThePickerOrderWithCounts() {
        let drills: [ExerciseTemplate] = [.freeform, .chords, .warmup, .chords, .basic, .chords]
        XCTAssertEqual(PracticeHubShelves.categoryTiles(drills),
                       [.init(template: .basic, count: 1), .init(template: .warmup, count: 1),
                        .init(template: .chords, count: 3), .init(template: .freeform, count: 1)])
    }

    func testOnlyKindsWithDrillsGetATile() {
        XCTAssertTrue(PracticeHubShelves.categoryTiles([]).isEmpty)
        XCTAssertEqual(PracticeHubShelves.categoryTiles([.legato]).map(\.template), [.legato])
    }

    /// A drill made under a retired template keeps a tile, so it stays reachable from the hub.
    func testARetiredTemplateStillGetsATile() {
        XCTAssertEqual(PracticeHubShelves.categoryTiles([.fingerstyle, .freeform]).map(\.template),
                       [.fingerstyle, .freeform])
    }

    func testNewIsOfferedOnlyForTemplatesThePickerOffers() {
        XCTAssertTrue(PracticeHubShelves.offersNew(.chords))
        XCTAssertTrue(PracticeHubShelves.offersNew(.freeform))
        XCTAssertFalse(PracticeHubShelves.offersNew(.fingerstyle))
        XCTAssertFalse(PracticeHubShelves.offersNew(.rhythm))
    }

    func testNewUsesThePreferredInstrumentUnlessTheTemplateCannotBeMadeOnIt() {
        XCTAssertEqual(PracticeHubShelves.newDrillInstrument(for: .scales, preferred: .bass), .bass)
        XCTAssertEqual(PracticeHubShelves.newDrillInstrument(for: .chords, preferred: .bass), .bass)
        XCTAssertEqual(PracticeHubShelves.newDrillInstrument(for: .strumming, preferred: .bass), .guitar)
        XCTAssertEqual(PracticeHubShelves.newDrillInstrument(for: .strumChords, preferred: .bass), .guitar)
        XCTAssertEqual(PracticeHubShelves.newDrillInstrument(for: .strumming, preferred: .guitar), .guitar)
    }

    // MARK: - Song groups (D6)

    private struct Song {
        let title: String
        var practised: Date?
    }

    private struct Loop {
        let song: Song?
    }

    private func groups(_ loops: [Loop]) -> [(String, Int)] {
        PracticeHubShelves.songGroups(loops, song: \.song, id: \.title, title: \.title,
                                      lastPractised: \.practised)
            .map { ($0.song.title, $0.count) }
    }

    func testLoopsGroupBySongWithCounts() {
        let bend = Song(title: "Slow Bend"), control = Song(title: "Self Control")
        let result = groups([Loop(song: bend), Loop(song: control), Loop(song: bend)])
        XCTAssertEqual(result.map(\.0), ["Self Control", "Slow Bend"])   // A→Z when neither played
        XCTAssertEqual(result.map(\.1), [1, 2])
    }

    func testTheSongPractisedMostRecentlyComesFirst() {
        let old = Song(title: "Aardvark", practised: base - 9 * day)
        let new = Song(title: "Zebra", practised: base)
        let never = Song(title: "Middle")
        XCTAssertEqual(groups([Loop(song: never), Loop(song: old), Loop(song: new)]).map(\.0),
                       ["Zebra", "Aardvark", "Middle"])
    }

    func testALoopWithNoSongHasNoTile() {
        XCTAssertEqual(groups([Loop(song: nil), Loop(song: Song(title: "One"))]).map(\.0), ["One"])
    }

    // MARK: - The unsaved session (D2)

    private struct Session {
        let name: String
        let isTemporary: Bool
        let started: Date
    }

    func testTheUnsavedSessionIsTheTemporaryOne() {
        let sessions = [Session(name: "Saved", isTemporary: false, started: base),
                        Session(name: "16 Oct Quick Session", isTemporary: true, started: base - day)]
        XCTAssertEqual(PracticeHubShelves.unsavedSession(sessions, isTemporary: \.isTemporary,
                                                         startedAt: \.started)?.name,
                       "16 Oct Quick Session")
    }

    /// A stray left by a crash between ADR 0243 D3's two writes: the newest is the one offered.
    func testWithAStrayTheNewestTemporaryIsOffered() {
        let sessions = [Session(name: "Stray", isTemporary: true, started: base - 2 * day),
                        Session(name: "Latest", isTemporary: true, started: base)]
        XCTAssertEqual(PracticeHubShelves.unsavedSession(sessions, isTemporary: \.isTemporary,
                                                         startedAt: \.started)?.name, "Latest")
    }

    func testNoTemporaryMeansNoLine() {
        let sessions = [Session(name: "Saved", isTemporary: false, started: base)]
        XCTAssertNil(PracticeHubShelves.unsavedSession(sessions, isTemporary: \.isTemporary,
                                                       startedAt: \.started))
    }

    func testUnsavedCaptionLeadsWithNotSavedYet() {
        let caption = PracticeHubShelves.unsavedCaption(minutes: 20, when: .now - day)
        XCTAssertTrue(caption.hasPrefix("Not saved yet · ~20 min · "), caption)
        XCTAssertFalse(PracticeHubShelves.unsavedCaption(minutes: 0, when: .now).contains("min"))
    }
}
