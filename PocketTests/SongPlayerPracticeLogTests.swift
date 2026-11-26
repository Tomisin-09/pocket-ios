import XCTest
import SwiftData
@testable import Pocket

/// **What the log's readers make of the song player's two kinds** (ADR 0322). A loop played on the
/// song player is that loop's time, listed with the trainer's and moving the planner's recency, but it
/// is not a trainer run: Home must not offer to reopen it in the trainer, and a goal that claims the
/// loop to train it does not count it. Exploring is time on the song, and nothing else.
@MainActor
final class SongPlayerPracticeLogTests: XCTestCase {

    private let verse = UUID()
    private let sunday = "sunday-source"
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var library: PracticeBreakdown.Names {
        PracticeBreakdown.Names(loops: [verse: .init(name: "Verse riff", songSourceID: sunday)],
                                songs: [sunday: "Sunday Morning"])
    }

    private func run(_ kind: PracticeRunKind, unit: UUID? = nil, minutes: Double, after offset: Double = 0,
                     song: String? = nil, label: String? = nil) -> SessionRecord {
        SessionRecord(startedAt: start.addingTimeInterval(offset * 60), durationSeconds: minutes * 60,
                      kind: kind, unitUID: unit, songSourceID: song, unitLabel: label)
    }

    // MARK: - The writer

    /// Both kinds keep the song player's thirty seconds, so a quick listen to check a song marks no
    /// day. The Metronome keeps its own, and every other kind still keeps one second.
    func testTheSongPlayersKindsKeepItsFloor() {
        XCTAssertEqual(PracticeLogWriter.minimumSeconds(for: .exploring), 30)
        XCTAssertEqual(PracticeLogWriter.minimumSeconds(for: .songPlayerLoop), 30)
        XCTAssertEqual(PracticeLogWriter.minimumSeconds(for: .songPlayerLoop), SongPlayerTime.floorSeconds)
    }

    /// Twenty-nine seconds of Exploring writes nothing; thirty writes one row on the song, with no unit
    /// and no tempo. Stored as raw strings, so no schema change.
    func testTheWriterDropsAShortExploreAndKeepsTheSongOnALongOne() throws {
        let context = ModelContext(try ModelContainer(
            for: PracticeRun.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))

        XCTAssertFalse(PracticeLogWriter.log(kind: .exploring, startedAt: start,
                                             endedAt: start.addingTimeInterval(29), unitUID: nil,
                                             songSourceID: sunday, unitLabel: "Sunday Morning", into: context))
        XCTAssertTrue(PracticeLogWriter.log(kind: .exploring, startedAt: start,
                                            endedAt: start.addingTimeInterval(30), unitUID: nil,
                                            songSourceID: sunday, unitLabel: "Sunday Morning", into: context))

        let rows = try context.fetch(FetchDescriptor<PracticeRun>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.kindRaw, "exploring")
        XCTAssertEqual(rows.first?.songSourceID, sunday)
        XCTAssertNil(rows.first?.unitUID)
        XCTAssertNil(rows.first?.tempoPercent)
        XCTAssertEqual(PracticeRun(startedAt: start, durationSeconds: 60, kind: .songPlayerLoop).kindRaw,
                       "songPlayerLoop")
    }

    // MARK: - What you played

    /// By kind: an hour in the trainer and twenty minutes on the song player on the same loop are one
    /// row under Loops, not two groups both called Loops. Exploring is a group of its own, by song.
    func testByKindALoopsTimeIsOneRowWhereverItWasPlayed() {
        let groups = PracticeBreakdown.groups([
            run(.loop, unit: verse, minutes: 60, song: sunday),
            run(.songPlayerLoop, unit: verse, minutes: 20, after: 90, song: sunday, label: "Verse riff"),
            run(.exploring, minutes: 15, after: 120, song: sunday, label: "Sunday Morning")
        ], names: library)

        XCTAssertEqual(groups.map(\.kind), [.loop, .exploring])
        XCTAssertEqual(groups.map(\.kind.groupLabel), ["Loops", "Exploring"])
        XCTAssertEqual(groups.first?.items.map(\.name), ["Verse riff"])
        XCTAssertEqual(groups.first?.items.map(\.minutes), [80])
        XCTAssertEqual(groups.first?.items.first?.detail, "Sunday Morning")
        XCTAssertEqual(groups.last?.items.map(\.name), ["Sunday Morning"])
        XCTAssertEqual(groups.last?.minutes, 15)
    }

    /// By song: the song holds both, and opens onto Loops (folded, as by kind) and Exploring.
    func testBySongTheSongHoldsItsLoopsAndExploring() {
        let rows = PracticeBreakdown.songRows([
            run(.loop, unit: verse, minutes: 10, song: sunday),
            run(.songPlayerLoop, unit: verse, minutes: 20, after: 30, song: sunday),
            run(.exploring, minutes: 25, after: 60, song: sunday, label: "Sunday Morning")
        ], names: library)

        XCTAssertEqual(rows.map(\.title), ["Sunday Morning"])
        XCTAssertEqual(rows.first?.minutes, 55)
        XCTAssertEqual(rows.first?.items.map(\.name), ["Loops", "Exploring"])
        XCTAssertEqual(rows.first?.items.map(\.minutes), [30, 25])
    }

    /// A song deleted since is still named by the title Exploring was logged under.
    func testBySongExploringNamesADeletedSong() {
        let rows = PracticeBreakdown.songRows([
            run(.exploring, minutes: 5, song: "gone-source", label: "Frontin'")
        ], names: library)
        XCTAssertEqual(rows.map(\.title), ["Frontin'"])
        XCTAssertEqual(rows.first?.detail, "Deleted")
    }

    // MARK: - The other readers

    /// A loop practised on the song player is practised: the planner sees it as recent. Exploring names
    /// no loop, so it makes no loop less due, even the one just made.
    func testTheSongPlayersLoopTimeMovesRecencyAndExploringDoesNot() {
        let map = PracticeLog.lastPracticedByUnit([
            run(.songPlayerLoop, unit: verse, minutes: 5, after: 10, song: sunday),
            run(.exploring, minutes: 5, after: 20, song: sunday)
        ])
        XCTAssertEqual(map, [verse: start.addingTimeInterval(600)])
    }

    /// Home reopens a loop in the mode its newest run names. A loop played on the song player names
    /// none, and offering it in the trainer would send a free player to a locked screen. The song player
    /// is reopened through the song, which it stamps on arrival.
    func testHomeDoesNotOfferASongPlayerLoopInTheTrainer() {
        XCTAssertNil(PracticeRunKind.songPlayerLoop.loopRunMode)
        XCTAssertNil(PracticeRunKind.exploring.loopRunMode)
        let candidates = HomeFeed.loopResumeCandidates([
            run(.loop, unit: verse, minutes: 5, song: sunday),
            run(.songPlayerLoop, unit: verse, minutes: 5, after: 60, song: sunday)
        ])
        XCTAssertEqual(candidates.map(\.startedAt), [start], "the trainer run, not the later song-player one")
    }

    /// A goal that names the song counts everything on it, Exploring included. A goal that claims the
    /// loop **to train it** counts trainer runs only (ADR 0298 D2): the song player's loop time is not
    /// claimed through the loop.
    func testAGoalsSongCountsBothKindsAndItsTrainerClaimCountsNeither() {
        let songGoal = PracticeBreakdown.GoalClaim(id: UUID(), title: "Sunday Morning", isMet: false,
                                                   songSourceIDs: [sunday], units: [])
        let trainGoal = PracticeBreakdown.GoalClaim(id: UUID(), title: "Speed", isMet: false, songSourceIDs: [],
                                                    units: [.init(uid: verse, kind: .loop)])
        let onSongPlayer = run(.songPlayerLoop, unit: verse, minutes: 5, song: sunday)
        let explored = run(.exploring, minutes: 5, song: sunday)

        XCTAssertTrue(songGoal.claims(onSongPlayer, names: library))
        XCTAssertTrue(songGoal.claims(explored, names: library))
        XCTAssertFalse(trainGoal.claims(onSongPlayer, names: library))
        XCTAssertTrue(trainGoal.claims(run(.loop, unit: verse, minutes: 5, song: sunday), names: library))
    }

    /// The labels the log shows.
    func testTheKindsLabels() {
        XCTAssertEqual(PracticeRunKind.exploring.label, "Exploring")
        XCTAssertEqual(PracticeRunKind.exploring.groupLabel, "Exploring")
        XCTAssertEqual(PracticeRunKind.songPlayerLoop.label, "Loop")
        XCTAssertEqual(PracticeRunKind.songPlayerLoop.listedAs, .loop)
        XCTAssertEqual(PracticeRunKind.exploring.listedAs, .exploring)
    }
}
