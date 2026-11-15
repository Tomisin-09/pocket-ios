import XCTest
@testable import Pocket

/// What counts toward a long-term goal (ADR 0298 D2), built from the planner's own resolution: each
/// loop in the mode the goal would run it in, a target song whole, and met goals after unmet ones.
final class GoalAttributionTests: XCTestCase {

    private func loop(uid: UUID = UUID(), songUID: UUID? = nil, audio: Bool = true, backing: Bool = false,
                      skills: [String] = []) -> PlannerLoop {
        PlannerLoop(uid: uid, songUID: songUID, mastery: nil, lastPracticed: nil, estimatedMinutes: 4,
                    modeFacts: .init(hasCommandTempo: true, audioResolves: audio, isBackingTrack: backing),
                    skillIDs: skills)
    }

    private func source(_ skills: [String], met: Bool = false, song: String? = nil,
                        title: String = "Goal") -> GoalAttribution.Source {
        GoalAttribution.Source(goal: PlannerGoal(weight: 1, skillIDs: skills,
                                                 targetSongUID: song.map(PlannerID.uid(from:)), isMet: met),
                               title: title, songSourceID: song)
    }

    private func kinds(_ claim: PracticeBreakdown.GoalClaim?, _ uid: UUID) -> Set<PracticeRunKind> {
        Set(claim?.units.filter { $0.uid == uid }.map(\.kind) ?? [])
    }

    func testABackingLoopCountsForImprovisingOnlyWhenSoloedOver() {
        let bed = loop(backing: true)
        let claims = GoalAttribution.claims([source(["improv.vocabulary"])],
                                            library: PlannerLibrary(loops: [bed]))
        XCTAssertEqual(kinds(claims.first, bed.uid), [.improvise],
                       "ear training on a loop you could solo over is not improvising")
    }

    func testALoopStatingAnEarSkillCountsBothWaysTheSkillClaimsIt() {
        // One skill claims the loop twice: to train (it states the skill) and by ear (it can be run
        // that way). The planner keeps one claim per unit; the log needs both.
        let stated = loop(skills: ["ear.transcribe"])
        let claims = GoalAttribution.claims([source(["ear.transcribe"])],
                                            library: PlannerLibrary(loops: [stated]))
        XCTAssertEqual(kinds(claims.first, stated.uid), [.loop, .earLoop])
    }

    func testATargetSongIsCountedThroughItsSongNotItsLoops() {
        let claims = GoalAttribution.claims([source(["rep.learn-song"], song: "sunday", title: "Play Sunday Morning")],
                                            library: PlannerLibrary())
        XCTAssertEqual(claims.first?.songSourceID, "sunday")
        XCTAssertEqual(claims.first?.title, "Play Sunday Morning")
    }

    func testMetGoalsStillClaimAndComeAfterUnmetOnes() {
        let bed = loop(backing: true)
        let claims = GoalAttribution.claims([
            source(["improv.vocabulary"], met: true, title: "Met first"),
            source(["improv.vocabulary"], title: "Open second")
        ], library: PlannerLibrary(loops: [bed]))

        XCTAssertEqual(claims.map(\.title), ["Open second", "Met first"],
                       "a run two goals share goes to the one still open")
        XCTAssertEqual(claims.map(\.isMet), [false, true])
        XCTAssertEqual(kinds(claims.last, bed.uid), [.improvise],
                       "time spent before a goal was met was time toward it")
    }

    func testResolveIsWhatTheDeriverDealsFrom() {
        // The log reads `resolve`; the planner deduplicates it. Pinned so the two cannot drift.
        let bed = loop(backing: true)
        let library = PlannerLibrary(loops: [bed, loop()])
        let goal = PlannerGoal(weight: 1, skillIDs: ["improv.vocabulary"], targetSongUID: nil)
        XCTAssertEqual(Set(CandidateDeriver.resolve("improv.vocabulary", of: goal, library: library).map(\.unit)),
                       Set(CandidateDeriver.deriveCandidates(goals: [goal], library: library).map(\.unit)))
        XCTAssertTrue(CandidateDeriver.resolve("no.such-skill", of: goal, library: library).isEmpty)
    }
}
