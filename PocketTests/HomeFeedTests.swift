import XCTest
@testable import Pocket

/// Pure home-hub logic (ADR 0044 follow-on): the time-of-day greeting bucket and the
/// recently-practised selection/ordering. Tested over plain values via the `practicedAt`
/// closure, no model container needed (AGENTS.md "pure logic stays pure").
final class HomeFeedTests: XCTestCase {

    // MARK: - Time of day

    func testTimeOfDayBuckets() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 0), .night)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 4), .night)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 5), .morning)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 11), .morning)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 12), .afternoon)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 16), .afternoon)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 17), .evening)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 21), .evening)
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 22), .night)
    }

    func testTimeOfDayFoldsOutOfRangeHours() {
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 24), .night)   // wraps to 0
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: 29), .morning) // wraps to 5
        XCTAssertEqual(HomeFeed.TimeOfDay.at(hour: -1), .night)   // wraps to 23
    }

    func testGreetingCopy() {
        XCTAssertEqual(HomeFeed.TimeOfDay.morning.greeting, "Good morning")
        XCTAssertEqual(HomeFeed.TimeOfDay.evening.greeting, "Good evening")
    }

    // MARK: - Name-aware greeting (ADR 0113)

    func testNamedGreetingUsesArtistName() {
        XCTAssertEqual(HomeFeed.TimeOfDay.morning.greeting(name: "Vega"), "Morning, Vega")
        XCTAssertEqual(HomeFeed.TimeOfDay.afternoon.greeting(name: "Vega"), "Afternoon, Vega")
        XCTAssertEqual(HomeFeed.TimeOfDay.evening.greeting(name: "Vega"), "Evening, Vega")
        // Night keeps the quiet register — "Late one", no exclamation.
        XCTAssertEqual(HomeFeed.TimeOfDay.night.greeting(name: "Vega"), "Late one, Vega")
    }

    func testGreetingFallsBackToNameFreeWhenNil() {
        XCTAssertEqual(HomeFeed.TimeOfDay.morning.greeting(name: nil), "Good morning")
        XCTAssertEqual(HomeFeed.TimeOfDay.night.greeting(name: nil), "Late session")
    }

    func testGreetingTreatsBlankNameAsUnset() {
        XCTAssertEqual(HomeFeed.TimeOfDay.evening.greeting(name: ""), "Good evening")
        XCTAssertEqual(HomeFeed.TimeOfDay.evening.greeting(name: "   "), "Good evening")
    }

    func testGreetingTrimsSurroundingWhitespace() {
        XCTAssertEqual(HomeFeed.TimeOfDay.morning.greeting(name: "  Vega  "), "Morning, Vega")
    }

    // MARK: - Most recently practised

    private struct Item { let name: String; let practiced: Date? }

    func testMostRecentlyPracticedPicksLatest() {
        let now = Date()
        let items = [
            Item(name: "old", practiced: now.addingTimeInterval(-1000)),
            Item(name: "newest", practiced: now),
            Item(name: "mid", practiced: now.addingTimeInterval(-500)),
            Item(name: "never", practiced: nil)
        ]
        XCTAssertEqual(HomeFeed.mostRecentlyPracticed(items, practicedAt: \.practiced)?.name, "newest")
    }

    func testMostRecentlyPracticedIsNilWhenNonePractised() {
        let items = [Item(name: "a", practiced: nil), Item(name: "b", practiced: nil)]
        XCTAssertNil(HomeFeed.mostRecentlyPracticed(items, practicedAt: \.practiced))
    }

    // MARK: - Ordering

    func testOrderedPutsRecentFirstThenUnpractisedByTitle() {
        let now = Date()
        let items = [
            Item(name: "Zed", practiced: nil),
            Item(name: "Apex", practiced: nil),
            Item(name: "Old", practiced: now.addingTimeInterval(-1000)),
            Item(name: "New", practiced: now)
        ]
        let ordered = HomeFeed.orderedForHome(items, practicedAt: \.practiced, title: \.name)
        XCTAssertEqual(ordered.map(\.name), ["New", "Old", "Apex", "Zed"])
    }

    func testOrderedIsDeterministicForEqualDates() {
        let when = Date()
        let items = [Item(name: "Beta", practiced: when), Item(name: "alpha", practiced: when)]
        // Equal practice dates fall back to a case-insensitive title sort, so the order is stable.
        XCTAssertEqual(HomeFeed.orderedForHome(items, practicedAt: \.practiced, title: \.name).map(\.name),
                       ["alpha", "Beta"])
    }

    // MARK: - The resume card's subject (ADR 0193)

    private let day: TimeInterval = 86_400

    private func kind(_ preference: JumpBackInPreference,
                      song: Double? = nil, routine: Double? = nil,
                      exercise: Double? = nil, loop: Double? = nil) -> HomeFeed.ResumeKind? {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func at(_ daysAgo: Double?) -> Date? { daysAgo.map { base.addingTimeInterval(-$0 * day) } }
        return HomeFeed.resumeKind(preference: preference,
                                   songPracticedAt: at(song),
                                   routinePracticedAt: at(routine),
                                   exercisePracticedAt: at(exercise),
                                   loopPracticedAt: at(loop))
    }

    func testMostRecentPicksTheNewestOfAnyKind() {
        XCTAssertEqual(kind(.mostRecent, song: 3, routine: 1, exercise: 5), .routine)
        XCTAssertEqual(kind(.mostRecent, song: 3, routine: 4, exercise: 1), .exercise)
        XCTAssertEqual(kind(.mostRecent, song: 0, routine: 4, exercise: 1), .song)
    }

    func testNothingPractisedHidesTheCard() {
        XCTAssertNil(kind(.mostRecent))
        // A pin does not conjure a card out of an empty install either.
        XCTAssertNil(kind(.routine))
    }

    func testAPinWinsOverAMoreRecentOtherKind() {
        // The whole point of the setting: the song was practised today, the routine a week ago,
        // and the card still offers the routine.
        XCTAssertEqual(kind(.routine, song: 0, routine: 7, exercise: 1), .routine)
        XCTAssertEqual(kind(.exercise, song: 0, routine: 1, exercise: 30), .exercise)
        XCTAssertEqual(kind(.song, song: 30, routine: 1, exercise: 0), .song)
    }

    func testAPinWithNothingToShowFallsBackToTheMostRecent() {
        // Pinned to routines, never run one — the card shows the newest of what there is rather
        // than going blank.
        XCTAssertEqual(kind(.routine, song: 2, exercise: 1), .exercise)
        XCTAssertEqual(kind(.exercise, song: 2, routine: 9), .song)
    }

    func testTiesBreakSongThenRoutineThenExercise() {
        // Same instant on all three: the declaration order decides, matching
        // `mostRecentlyPracticed`'s first-maximal rule.
        XCTAssertEqual(kind(.mostRecent, song: 1, routine: 1, exercise: 1), .song)
        XCTAssertEqual(kind(.mostRecent, routine: 1, exercise: 1), .routine)
    }

    func testPinnedKindMapsEveryPreference() {
        XCTAssertNil(JumpBackInPreference.mostRecent.pinnedKind)
        XCTAssertEqual(JumpBackInPreference.song.pinnedKind, .song)
        XCTAssertEqual(JumpBackInPreference.routine.pinnedKind, .routine)
        XCTAssertEqual(JumpBackInPreference.exercise.pinnedKind, .exercise)
        XCTAssertEqual(JumpBackInPreference.loop.pinnedKind, .loop)
    }

    /// The `@AppStorage` trap this project has paid for seven times: an unset key must read as the
    /// default, and a raw value written by some later build must degrade rather than trap.
    ///
    /// This used `"loop"` as its stand-in for a later build's value until ADR 0267 made it a real one.
    func testResolvedPreferenceHonoursTheDefault() {
        XCTAssertEqual(AppSettings.resolvedJumpBackIn(storedValue: nil), .mostRecent)
        XCTAssertEqual(AppSettings.resolvedJumpBackIn(storedValue: "metronome"), .mostRecent)
        XCTAssertEqual(AppSettings.resolvedJumpBackIn(storedValue: "routine"), .routine)
        XCTAssertEqual(AppSettings.resolvedJumpBackIn(storedValue: "loop"), .loop)
        XCTAssertEqual(AppSettings.jumpBackInPreferenceDefault, .mostRecent)
    }

    // MARK: - A loop on the card (ADR 0267)

    func testMostRecentCanBeALoop() {
        XCTAssertEqual(kind(.mostRecent, song: 3, routine: 2, exercise: 4, loop: 1), .loop)
        // And a loop that is older than everything else doesn't take the card.
        XCTAssertEqual(kind(.mostRecent, song: 3, routine: 2, exercise: 4, loop: 9), .routine)
        // A loop is enough on its own to show the card.
        XCTAssertEqual(kind(.mostRecent, loop: 30), .loop)
    }

    func testALoopPinWinsAndFallsBack() {
        XCTAssertEqual(kind(.loop, song: 0, routine: 1, exercise: 0, loop: 30), .loop)
        // Pinned to a loop with no loop run yet: the newest of what there is.
        XCTAssertEqual(kind(.loop, song: 5, exercise: 2), .exercise)
        // Pinned elsewhere with nothing there, a loop can be the fallback.
        XCTAssertEqual(kind(.routine, song: 5, loop: 1), .loop)
    }

    func testALoopLosesEveryTie() {
        XCTAssertEqual(kind(.mostRecent, song: 1, loop: 1), .song)
        XCTAssertEqual(kind(.mostRecent, routine: 1, loop: 1), .routine)
        XCTAssertEqual(kind(.mostRecent, exercise: 1, loop: 1), .exercise)
    }

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func run(_ kind: PracticeRunKind, loop: UUID?, hoursAgo: Double,
                     routine: UUID? = nil) -> SessionRecord {
        SessionRecord(startedAt: base.addingTimeInterval(-hoursAgo * 3600), durationSeconds: 300,
                      kind: kind, unitUID: loop, routineUID: routine)
    }

    func testEachLoopKindReopensItsOwnMode() {
        let (trainer, ear, jam) = (UUID(), UUID(), UUID())
        let candidates = HomeFeed.loopResumeCandidates([
            run(.loop, loop: trainer, hoursAgo: 3),
            run(.earLoop, loop: ear, hoursAgo: 2),
            run(.improvise, loop: jam, hoursAgo: 1)
        ])
        XCTAssertEqual(candidates.map(\.loopUID), [jam, ear, trainer], "newest first")
        XCTAssertEqual(candidates.map(\.mode), [.improvise, .ear, .trainer])
        XCTAssertEqual(candidates.first?.startedAt, base.addingTimeInterval(-3600))
    }

    /// A routine's loop block is the routine's run, not the loop's: counting it would put that block
    /// on the card in place of the routine just played.
    func testARunInsideARoutineIsNotACandidate() {
        let (loop, other) = (UUID(), UUID())
        let candidates = HomeFeed.loopResumeCandidates([
            run(.earLoop, loop: loop, hoursAgo: 1, routine: UUID()),
            run(.loop, loop: other, hoursAgo: 5)
        ])
        XCTAssertEqual(candidates.map(\.loopUID), [other])
    }

    func testOnlyALoopsNewestRunCountsAndItsModeWins() {
        let loop = UUID()
        let candidates = HomeFeed.loopResumeCandidates([
            run(.loop, loop: loop, hoursAgo: 6),
            run(.earLoop, loop: loop, hoursAgo: 1),
            run(.improvise, loop: loop, hoursAgo: 4)
        ])
        XCTAssertEqual(candidates, [HomeFeed.LoopResume(loopUID: loop, mode: .ear,
                                                        startedAt: base.addingTimeInterval(-3600))])
    }

    func testRowsThatAreNotLoopRunsAreSkipped() {
        let unit = UUID()
        XCTAssertEqual(HomeFeed.loopResumeCandidates([
            run(.exercise, loop: unit, hoursAgo: 1),
            run(.song, loop: nil, hoursAgo: 1),
            run(.metronome, loop: nil, hoursAgo: 1),
            run(.other, loop: unit, hoursAgo: 1),
            // A loop kind with no unit can't be reopened.
            run(.loop, loop: nil, hoursAgo: 1)
        ]), [])
    }

    func testEveryKindSaysWhetherItIsALoopMode() {
        XCTAssertEqual(PracticeRunKind.loop.loopRunMode, .trainer)
        XCTAssertEqual(PracticeRunKind.earLoop.loopRunMode, .ear)
        XCTAssertEqual(PracticeRunKind.improvise.loopRunMode, .improvise)
        for kind in [PracticeRunKind.exercise, .song, .metronome, .other] {
            XCTAssertNil(kind.loopRunMode, "\(kind) is not a loop mode")
        }
    }

    // MARK: - The starter-track card (ADR 0219)

    /// An untouched library offers the card; adopting the track keeps it, because it is now the way
    /// back to the only song the player has.
    func testTheCardIsOfferedUntilTheLibraryHasSomethingElse() {
        XCTAssertTrue(HomeFeed.shouldOfferStarterTrack(totalSongs: 0, hasStarterTrack: false))
        XCTAssertTrue(HomeFeed.shouldOfferStarterTrack(totalSongs: 1, hasStarterTrack: true))
    }

    /// One real import retires it. The starter track exists to be outgrown, and `resumeCard` is
    /// what takes the slot.
    func testTheCardRetiresOnceARealSongLands() {
        XCTAssertFalse(HomeFeed.shouldOfferStarterTrack(totalSongs: 1, hasStarterTrack: false))
        XCTAssertFalse(HomeFeed.shouldOfferStarterTrack(totalSongs: 2, hasStarterTrack: true))
        XCTAssertFalse(HomeFeed.shouldOfferStarterTrack(totalSongs: 7, hasStarterTrack: true))
        XCTAssertFalse(HomeFeed.shouldOfferStarterTrack(totalSongs: 7, hasStarterTrack: false))
    }
}
