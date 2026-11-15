import XCTest
@testable import Pocket

/// *What you played* **by goal** (ADR 0298): which row a run lands in, what a goal and *Free play*
/// open onto, and which goals are listed with nothing against them. The claims are written by hand
/// here; `GoalAttributionTests` covers how the planner's resolution builds them.
final class PracticeBreakdownGoalTests: XCTestCase {

    private let picking = UUID()
    private let scales = UUID()
    private let soloStart = UUID()
    private let backing = UUID()
    private let slowBend = "slow-bend-source"
    private let sunday = "sunday-source"

    private let songGoal = UUID()
    private let improvGoal = UUID()
    private let speedGoal = UUID()

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func run(_ kind: PracticeRunKind, unit: UUID? = nil, minutes: Double, after offset: Double = 0,
                     song: String? = nil) -> SessionRecord {
        SessionRecord(startedAt: start.addingTimeInterval(offset * 60), durationSeconds: minutes * 60,
                      kind: kind, unitUID: unit, songSourceID: song)
    }

    private func claim(_ id: UUID, _ title: String, song: String? = nil, met: Bool = false,
                       units: [(UUID, PracticeRunKind)] = []) -> PracticeBreakdown.GoalClaim {
        PracticeBreakdown.GoalClaim(id: id, title: title, isMet: met, songSourceIDs: Set([song].compactMap { $0 }),
                                    units: Set(units.map { PracticeBreakdown.UnitClaim(uid: $0.0, kind: $0.1) }))
    }

    /// Slow Bend is a goal's song; the improvising goal claims a backing loop to solo over and the
    /// scale exercise; the speed goal claims the picking exercise. Sunday Morning is no goal's.
    private var names: PracticeBreakdown.Names {
        var names = PracticeBreakdown.Names(
            exercises: [picking: "Alternate Picking", scales: "Scale Runs"],
            loops: [soloStart: .init(name: "Solo start", songSourceID: slowBend),
                    backing: .init(name: "Groove bed", songSourceID: sunday)],
            songs: [slowBend: "Slow Bend", sunday: "Sunday Morning"])
        names.goals = [
            claim(songGoal, "Play Slow Bend", song: slowBend),
            claim(improvGoal, "Improvise in a style", units: [(backing, .improvise), (scales, .exercise)]),
            claim(speedGoal, "Build speed", units: [(picking, .exercise)])
        ]
        return names
    }

    func testATargetSongCountsWholeWhateverTheWork() {
        let rows = PracticeBreakdown.goalRows([
            run(.earLoop, unit: soloStart, minutes: 40, song: slowBend),
            run(.loop, unit: soloStart, minutes: 20, after: 50, song: slowBend),
            run(.song, minutes: 12, after: 100, song: slowBend)
        ], names: names)

        let goal = rows.first { $0.title == "Play Slow Bend" }
        XCTAssertEqual(goal?.minutes, 72, "learning a song by ear is learning the song")
        XCTAssertEqual(goal?.items.map(\.name), ["Active listening", "Loops", "Play-alongs"],
                       "a goal opens onto kinds of work, as a song does")
    }

    func testASongGoalAgreesWithTheSongsRowBySong() {
        let records = [
            run(.earLoop, unit: soloStart, minutes: 40, song: slowBend),
            run(.song, minutes: 12, after: 50, song: slowBend),
            run(.song, minutes: 9, after: 70, song: sunday)
        ]
        let bySong = PracticeBreakdown.songRows(records, names: names).first { $0.title == "Slow Bend" }
        let byGoal = PracticeBreakdown.goalRows(records, names: names).first { $0.title == "Play Slow Bend" }
        XCTAssertEqual(byGoal?.seconds, bySong?.seconds)
        XCTAssertEqual(byGoal?.items.map(\.name), bySong?.items.map(\.name))
    }

    func testALoopCountsOnlyInTheModeTheGoalWouldRunIt() {
        // The over-count the 2026-11-13 check found: ear training on a loop that *could* be soloed
        // over, counted toward improvising.
        let rows = PracticeBreakdown.goalRows([
            run(.improvise, unit: backing, minutes: 30, song: sunday),
            run(.earLoop, unit: backing, minutes: 25, after: 40, song: sunday)
        ], names: names)

        XCTAssertEqual(rows.first { $0.title == "Improvise in a style" }?.minutes, 30)
        XCTAssertEqual(rows.first { $0.title == PracticeBreakdown.freePlayTitle }?.minutes, 25)
    }

    func testEveryRunLandsInExactlyOneRow() {
        let records = [
            run(.exercise, unit: picking, minutes: 7),
            run(.exercise, unit: scales, minutes: 9, after: 10),
            run(.loop, unit: soloStart, minutes: 11, after: 20, song: slowBend),
            run(.earLoop, unit: backing, minutes: 6, after: 32, song: sunday),
            run(.song, minutes: 13, after: 40, song: sunday),
            run(.metronome, minutes: 5, after: 60),
            run(.other, minutes: 3, after: 70)
        ]
        let rows = PracticeBreakdown.goalRows(records, names: names)
        XCTAssertEqual(rows.reduce(0) { $0 + $1.seconds }, records.reduce(0) { $0 + $1.durationSeconds },
                       "the rows add up to the period, as they do by kind and by song")
    }

    func testARunTwoGoalsClaimCountsUnderTheHigherRanked() {
        var shared = names
        shared.goals[2] = claim(speedGoal, "Build speed", units: [(picking, .exercise), (scales, .exercise)])
        let rows = PracticeBreakdown.goalRows([run(.exercise, unit: scales, minutes: 10)], names: shared)
        XCTAssertEqual(rows.first { $0.title == "Improvise in a style" }?.minutes, 10)
        XCTAssertEqual(rows.first { $0.title == "Build speed" }?.minutes, 0)
    }

    func testFreePlayOpensOntoWhatTheTimeWentOnInstead() {
        let rows = PracticeBreakdown.goalRows([
            run(.song, minutes: 30, song: sunday),
            run(.earLoop, unit: backing, minutes: 25, after: 40, song: sunday),
            run(.metronome, minutes: 5, after: 80)
        ], names: names)

        let free = rows.first { $0.id == "free-play" }
        XCTAssertEqual(free?.title, "Free play")
        XCTAssertEqual(free?.detail, "Practice no goal names")
        XCTAssertEqual(free?.items.map(\.name), ["Sunday Morning", "Metronome"],
                       "free play opens onto songs, the answer to what the time went on instead")
        XCTAssertEqual(free?.items.map(\.minutes), [55, 5])
    }

    func testAnUnmetGoalWithNoTimeIsListedLast() {
        let rows = PracticeBreakdown.goalRows([run(.song, minutes: 20, song: sunday)], names: names)
        XCTAssertEqual(rows.map(\.title),
                       ["Free play", "Play Slow Bend", "Improvise in a style", "Build speed"],
                       "ranked by minutes; goals with none follow in rank order, so the gap shows")
        XCTAssertEqual(rows.dropFirst().map(\.minutes), [0, 0, 0])
        XCTAssertTrue(rows.dropFirst().allSatisfy(\.items.isEmpty), "nothing to open on a goal with no time")
    }

    func testAMetGoalShowsOnlyWhenItHadTime() {
        var withMet = names
        withMet.goals.append(claim(UUID(), "Learn the fretboard", met: true, units: [(picking, .exercise)]))
        withMet.goals[2] = claim(speedGoal, "Build speed")

        let idle = PracticeBreakdown.goalRows([run(.song, minutes: 5, song: sunday)], names: withMet)
        XCTAssertFalse(idle.contains { $0.title == "Learn the fretboard" }, "finished, not waiting")

        let played = PracticeBreakdown.goalRows([run(.exercise, unit: picking, minutes: 8)], names: withMet)
        let met = played.first { $0.title == "Learn the fretboard" }
        XCTAssertEqual(met?.minutes, 8)
        XCTAssertEqual(met?.detail, "Met")
    }

    func testAGoalIsNotListedAtNothingForPracticeFromBeforeItWasSet() {
        var later = names
        later.goals[2] = PracticeBreakdown.GoalClaim(id: speedGoal, title: "Build speed", isMet: false,
                                                     songSourceIDs: [], units: [],
                                                     since: start.addingTimeInterval(60 * 60))
        let before = PracticeBreakdown.goalRows([run(.song, minutes: 20, song: sunday)], names: later)
        XCTAssertFalse(before.contains { $0.title == "Build speed" }, "it had nothing to get yet")

        let after = PracticeBreakdown.goalRows([run(.song, minutes: 20, song: sunday),
                                                run(.song, minutes: 5, after: 90, song: sunday)], names: later)
        XCTAssertEqual(after.first { $0.title == "Build speed" }?.minutes, 0,
                       "practice once it existed, and none of it toward it: that is the reading")
    }

    func testNothingLoggedGivesNoRows() {
        XCTAssertTrue(PracticeBreakdown.goalRows([], names: names).isEmpty,
                      "an empty day says so, rather than listing every goal at nothing")
    }

    // MARK: - The switch

    func testByGoalIsOfferedOnlyOnceAGoalExists() {
        XCTAssertEqual(PracticeBreakdown.Grouping.offered(hasGoals: false), [.kind, .song])
        XCTAssertEqual(PracticeBreakdown.Grouping.offered(hasGoals: true), [.kind, .song, .goal])
        XCTAssertEqual(PracticeBreakdown.Grouping.allCases.map(\.label), ["By kind", "By song", "By goal"])
    }

    func testAStoredByGoalFallsBackWhenTheLastGoalGoes() {
        XCTAssertEqual(PracticeBreakdown.Grouping.goal.effective(hasGoals: false), .kind)
        XCTAssertEqual(PracticeBreakdown.Grouping.goal.effective(hasGoals: true), .goal)
        XCTAssertEqual(PracticeBreakdown.Grouping.song.effective(hasGoals: false), .song)
    }
}
