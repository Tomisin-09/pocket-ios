import XCTest
@testable import Pocket

/// **Prepare a set** (ADR 0299): a long-term goal holding several songs. The planner rotates through
/// them, By goal counts each one whole and opens onto them, the starting point is the long-term
/// tier's alone, and an archive from before sets still decodes.
final class PrepareSetTests: XCTestCase {

    private let sunday = "sunday-source"
    private let frontin = "frontin-source"
    private let canon = "canon-source"

    // MARK: - D4, the planner

    func testASetResolvesEverySongsLoopsAndPlayThroughUnderOneGoal() {
        let sundayUID = PlannerID.uid(from: sunday), frontinUID = PlannerID.uid(from: frontin)
        let verse = PlannerLoop(uid: UUID(), songUID: sundayUID, mastery: nil, lastPracticed: nil,
                                estimatedMinutes: 4)
        let intro = PlannerLoop(uid: UUID(), songUID: frontinUID, mastery: nil, lastPracticed: nil,
                                estimatedMinutes: 4)
        let library = PlannerLibrary(loops: [verse, intro],
                                     songs: [PlannerSong(uid: sundayUID, lastPracticed: nil, estimatedMinutes: 5),
                                             PlannerSong(uid: frontinUID, lastPracticed: nil, estimatedMinutes: 5)])
        let set = PlannerGoal(skillIDs: ["rep.learn-song"], setSongUIDs: [sundayUID, frontinUID])

        let candidates = CandidateDeriver.deriveCandidates(goals: [set], library: library)
        XCTAssertEqual(Set(candidates.map(\.unit.uid)), [verse.uid, intro.uid, sundayUID, frontinUID],
                       "each song's loops, then each song's play-through")
        XCTAssertTrue(candidates.allSatisfy { $0.goalUID == set.uid },
                      "one goal, so the session deals one of them per pass")
    }

    func testATargetSongStillWinsOverAnEmptySet() {
        let song = PlannerID.uid(from: sunday)
        let goal = PlannerGoal(skillIDs: ["rep.learn-song"], targetSongUID: song)
        XCTAssertEqual(goal.repertoireSongUIDs, [song])
        XCTAssertEqual(PlannerGoal(skillIDs: ["rep.learn-song"]).repertoireSongUIDs, [])
    }

    func testTheReachLineCountsASetsSongs() {
        XCTAssertEqual(GoalReach.summary(SkillReach(skillID: "rep.learn-song", exercises: 0, loops: 3,
                                                    songRun: true, songCount: 4)), "3 loops · 4 songs")
        XCTAssertEqual(GoalReach.summary(SkillReach(skillID: "rep.learn-song", exercises: 0, loops: 2,
                                                    songRun: true, songCount: 1)), "2 loops · the song itself")
    }

    // MARK: - D5, By goal

    private var names: PracticeBreakdown.Names {
        PracticeBreakdown.Names(songs: [sunday: "Sunday Morning", frontin: "Frontin'", canon: "Canon in D"])
    }

    private func run(_ kind: PracticeRunKind, minutes: Double, song: String?) -> SessionRecord {
        SessionRecord(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000), durationSeconds: minutes * 60,
                      kind: kind, unitUID: nil, songSourceID: song)
    }

    func testASetCountsEachOfItsSongsAndOpensOntoThem() {
        let claims = GoalAttribution.claims(
            [GoalAttribution.Source(goal: PlannerGoal(skillIDs: ["rep.learn-song"]), title: "Symposium set",
                                    songSourceID: nil, setSongIDs: [sunday, frontin, canon, "deleted-source"])],
            library: PlannerLibrary())
        var withSet = names
        withSet.goals = claims
        XCTAssertEqual(claims.first?.isSet, true)

        let rows = PracticeBreakdown.goalRows([run(.song, minutes: 30, song: sunday),
                                               run(.song, minutes: 12, song: frontin)], names: withSet)
        let set = rows.first { $0.title == "Symposium set" }
        XCTAssertEqual(set?.minutes, 42)
        XCTAssertEqual(set?.items.map(\.name), ["Sunday Morning", "Frontin'", "Canon in D"],
                       "the songs, largest first, then the one with no time: which songs have I left?")
        XCTAssertEqual(set?.items.map(\.minutes), [30, 12, 0])
        XCTAssertFalse(rows.contains { $0.id == "free-play" }, "every minute went to the set")
    }

    // MARK: - D1 / D2, the starting point

    func testPrepareASetIsOfferedToLongTermGoalsOnly() {
        XCTAssertFalse(GoalTemplateLibrary.offered(longTerm: false).contains { $0.id == "prepare-set" })
        XCTAssertEqual(GoalTemplateLibrary.offered(longTerm: true).prefix(2).map(\.id), ["play-song", "prepare-set"],
                       "beside Play a specific song")
        XCTAssertEqual(GoalTemplateLibrary.offered(longTerm: true).count, GoalTemplateLibrary.all.count + 1)
        XCTAssertTrue(GoalTemplateLibrary.prepareSet.holdsSet)
        XCTAssertTrue(GoalTemplateLibrary.prepareSet.skillIDs.allSatisfy { TechniqueTaxonomy.info($0) != nil })
    }

    func testASetIsKnownByItsSongs() {
        XCTAssertTrue(LongTermGoal(title: "Symposium set", setSongIDs: [sunday]).isSet)
        XCTAssertFalse(LongTermGoal(title: "Play a specific song").isSet)
    }

    // MARK: - D3, the archive

    func testAnArchiveFromBeforeSetsStillDecodes() throws {
        let record = LongTermGoalRecord(uid: UUID(), title: "Build speed", skillIDs: ["pick.alternate"], order: 0,
                                        targetSongID: nil, setSongIDs: nil, isMet: false,
                                        dateAdded: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let encoded = try JSONEncoder().encode(record)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["setSongIDs"], "a goal that isn't a set encodes exactly as before")

        let decoded = try JSONDecoder().decode(LongTermGoalRecord.self, from: encoded)
        XCTAssertNil(decoded.setSongIDs)
    }

    @MainActor
    func testTheBuilderWritesASetsSongsAndNothingForOtherGoals() {
        let set = LongTermGoal(title: "Symposium set", skillIDs: ["rep.learn-song"], setSongIDs: [sunday, frontin])
        XCTAssertEqual(ArchiveBuilder.longTermGoalRecord(set).setSongIDs, [frontin, sunday], "sorted, stable")
        XCTAssertNil(ArchiveBuilder.longTermGoalRecord(LongTermGoal(title: "Build speed")).setSongIDs)
    }

    func testASetsSongsRoundTripThroughTheArchive() throws {
        let record = LongTermGoalRecord(uid: UUID(), title: "Symposium set", skillIDs: ["rep.learn-song"], order: 1,
                                        targetSongID: nil, setSongIDs: [frontin, sunday], isMet: false,
                                        dateAdded: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let decoded = try JSONDecoder().decode(LongTermGoalRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.setSongIDs, [frontin, sunday])
    }
}
