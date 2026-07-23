import XCTest
@testable import Pocket

/// The ADR 0015 property list for the planner's front-half (`CandidateDeriver`, V2 planner Slice 2):
/// goals expand to a ranked candidate pool. Pure value projections only — no `@Model` inserts (the
/// test-host insert trap), which is exactly why the deriver reasons over `PlannerLibrary` values.
final class CandidateDeriverTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A picking exercise (serves the whole picking family via the coarse template map).
    private func pickingExercise(mastery: Int? = nil, lastPracticed: Date? = nil) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: .picking, mastery: mastery,
                        lastPracticed: lastPracticed, estimatedMinutes: 10)
    }

    private func goal(weight: Double = 1.0, skills: [String],
                      song: UUID? = nil, isMet: Bool = false) -> PlannerGoal {
        PlannerGoal(weight: weight, skillIDs: skills, targetSongUID: song, isMet: isMet)
    }

    // MARK: - Emptiness / affiliation (S4)

    func testEmptyGoalsYieldEmptyCandidates() {
        let library = PlannerLibrary(exercises: [pickingExercise()])
        XCTAssertTrue(CandidateDeriver.deriveCandidates(goals: [], library: library).isEmpty)
    }

    func testSkillWithNoAffiliatedExerciseYieldsNoCandidate() {
        // Goal wants alternate picking, but the only exercise is a Chords drill (serves no picking).
        let chords = PlannerExercise(uid: UUID(), template: .chords, mastery: nil,
                                     lastPracticed: nil, estimatedMinutes: 10)
        let library = PlannerLibrary(exercises: [chords])
        let candidates = CandidateDeriver.deriveCandidates(goals: [goal(skills: ["pick.alternate"])],
                                                           library: library)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testMetGoalContributesNoCandidates() {
        let library = PlannerLibrary(exercises: [pickingExercise()])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["pick.alternate"], isMet: true)], library: library)
        XCTAssertTrue(candidates.isEmpty)
    }

    // MARK: - Weighting (S5)

    func testHigherWeightYieldsHigherPriority() {
        let exercise = pickingExercise()
        let library = PlannerLibrary(exercises: [exercise])
        let light = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 1.0, skills: ["pick.alternate"])], library: library)
        let heavy = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 3.0, skills: ["pick.alternate"])], library: library)
        XCTAssertEqual(light.count, 1)
        XCTAssertEqual(heavy.count, 1)
        XCTAssertGreaterThan(heavy[0].priority, light[0].priority)
    }

    func testUnitSurfacedByTwoGoalsKeepsStrongestClaim() {
        let exercise = pickingExercise()
        let library = PlannerLibrary(exercises: [exercise])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 1.0, skills: ["pick.alternate"]),   // no prereq ⇒ no down-weight
                    goal(weight: 4.0, skills: ["pick.alternate"])],  // stronger claim on the same unit
            library: library)
        XCTAssertEqual(candidates.count, 1, "one exercise ⇒ one candidate, de-duplicated")
        XCTAssertEqual(candidates[0].priority, 4.0, accuracy: 0.0001, "keeps the stronger goal's weight")
    }

    // MARK: - Mastery composes into dueScore (not into priority)

    func testHigherMasteryRanksLowerViaDueScore() throws {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let settled = pickingExercise(mastery: 5, lastPracticed: weekAgo)
        let shaky = pickingExercise(mastery: 0, lastPracticed: weekAgo)
        let library = PlannerLibrary(exercises: [settled, shaky])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["pick.alternate"])], library: library)
        let byUID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.unit.uid, $0) })
        let settledScore = try DueScore.score(XCTUnwrap(byUID[settled.uid]), now: now)
        let shakyScore = try DueScore.score(XCTUnwrap(byUID[shaky.uid]), now: now)
        XCTAssertLessThan(settledScore, shakyScore, "settled (mastery 5) ranks below shaky for equal recency")
    }

    // MARK: - Soft prereq down-weight (Decision 6)

    func testUnmetPrereqDownWeightsButKeepsCandidate() {
        // Sweep picking's prereq (economy) is unrated ⇒ soft down-weight, but still present.
        let exercise = pickingExercise(mastery: nil)
        let library = PlannerLibrary(exercises: [exercise])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 1.0, skills: ["pick.sweep"])], library: library)
        XCTAssertEqual(candidates.count, 1, "advanced skill is never excluded, only down-weighted")
        XCTAssertLessThan(candidates[0].priority, 1.0)
        XCTAssertEqual(candidates[0].priority, CandidateDeriver.prereqPenalty, accuracy: 0.0001)
    }

    func testMetPrereqRemovesTheDownWeight() {
        // Rate the picking library high — economy is now "met", so sweep isn't down-weighted.
        let exercise = pickingExercise(mastery: 5)
        let library = PlannerLibrary(exercises: [exercise])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 1.0, skills: ["pick.sweep"])], library: library)
        XCTAssertEqual(candidates[0].priority, 1.0, accuracy: 0.0001)
    }

    func testDownWeightNeverFallsBelowFloor() {
        let info = SkillInfo(id: "x", name: "x", difficulty: .adv, mode: .speedRamp,
                             prereqs: ["a", "b", "c", "d", "e"])  // 0.6^5 ≈ 0.078, floored
        let readiness = CandidateDeriver.prereqReadiness(for: info, library: PlannerLibrary())
        XCTAssertEqual(readiness, CandidateDeriver.prereqFloor, accuracy: 0.0001)
    }

    // MARK: - Profile emphasis mix (ADR 0113 S3)

    /// A scales exercise (serves the scales family, incl. `scale.pentatonic`) for genre-lift tests.
    private func scalesExercise(mastery: Int? = nil) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: .scales, mastery: mastery,
                        lastPracticed: nil, estimatedMinutes: 10)
    }

    func testGenreEmphasisLiftsAMatchingSkillPriority() {
        // scale.pentatonic is in the blues genre map; a blues profile should lift it above neutral.
        let exercise = scalesExercise()
        let library = PlannerLibrary(exercises: [exercise])
        let goals = [goal(skills: ["scale.pentatonic"])]
        let neutral = CandidateDeriver.deriveCandidates(goals: goals, library: library)
        let blues = CandidateDeriver.deriveCandidates(
            goals: goals, library: library,
            emphasis: PracticeEmphasis(genres: [.blues], dream: nil))
        XCTAssertEqual(neutral.count, 1)
        XCTAssertEqual(blues.count, 1)
        XCTAssertGreaterThan(blues[0].priority, neutral[0].priority, "declared genre lifts its skill")
        XCTAssertEqual(blues[0].priority,
                       neutral[0].priority * PracticeEmphasis.genreLift, accuracy: 0.0001)
    }

    func testEmphasisNeverExcludesAnUnmatchedCandidate() {
        // A picking goal with a jazz profile (no picking skills in the jazz map) → present, unchanged.
        let exercise = pickingExercise()
        let library = PlannerLibrary(exercises: [exercise])
        let goals = [goal(skills: ["pick.alternate"])]
        let neutral = CandidateDeriver.deriveCandidates(goals: goals, library: library)
        let jazz = CandidateDeriver.deriveCandidates(
            goals: goals, library: library,
            emphasis: PracticeEmphasis(genres: [.jazz], dream: nil))
        XCTAssertEqual(jazz.count, 1, "emphasis re-orders, never gates")
        XCTAssertEqual(jazz[0].priority, neutral[0].priority, accuracy: 0.0001, "unmatched ⇒ no change")
    }

    func testHighGoalStillOutranksAnEmphasisedNormalGoal() throws {
        // Normal goal on a genre+dream-matched, prereq-free skill (metal → pick.alternate, getGood →
        // speedRamp) sits at the full cap; a High goal on an un-emphasised, prereq-free skill still
        // wins. Isolates the cap hierarchy — no prereq down-weight in play.
        let matched = pickingExercise()   // pick.alternate ∈ metal map, mode .speedRamp (getGood tilt)
        let plain = PlannerExercise(uid: UUID(), template: .chords, mastery: nil,
                                    lastPracticed: nil, estimatedMinutes: 10)  // rhythm.chord-changes
        let library = PlannerLibrary(exercises: [matched, plain])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: GoalPriority.normal.weight, skills: ["pick.alternate"]),
                    goal(weight: GoalPriority.high.weight, skills: ["rhythm.chord-changes"])],
            library: library,
            emphasis: PracticeEmphasis(genres: [.metal], dream: .getGood))
        let byUID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.unit.uid, $0) })
        let matchedPriority = try XCTUnwrap(byUID[matched.uid]).priority
        let plainPriority = try XCTUnwrap(byUID[plain.uid]).priority
        XCTAssertEqual(matchedPriority, GoalPriority.normal.weight * PracticeEmphasis.cap,
                       accuracy: 0.0001, "Normal goal, genre+dream matched ⇒ full cap")
        XCTAssertLessThan(matchedPriority, plainPriority,
                          "a stated High goal beats a fully-emphasised Normal one")
    }

    // MARK: - Path B: repertoire → target song's loops + song run

    func testTargetSongContributesLoopsAndSongRun() {
        let songUID = UUID()
        let loopA = PlannerLoop(uid: UUID(), songUID: songUID, mastery: nil,
                                lastPracticed: nil, estimatedMinutes: 3)
        let loopB = PlannerLoop(uid: UUID(), songUID: songUID, mastery: 2,
                                lastPracticed: nil, estimatedMinutes: 4)
        // A loop from a *different* song must not leak in.
        let otherLoop = PlannerLoop(uid: UUID(), songUID: UUID(), mastery: nil,
                                    lastPracticed: nil, estimatedMinutes: 3)
        let song = PlannerSong(uid: songUID, lastPracticed: nil, estimatedMinutes: 20)
        let library = PlannerLibrary(loops: [loopA, loopB, otherLoop], songs: [song])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["rep.learn-song"], song: songUID)], library: library)

        let loopRefs = candidates.filter { $0.unit.kind == .loop }.map(\.unit.uid)
        let songRefs = candidates.filter { $0.unit.kind == .song }.map(\.unit.uid)
        XCTAssertEqual(Set(loopRefs), [loopA.uid, loopB.uid], "only the target song's loops")
        XCTAssertEqual(songRefs, [songUID], "plus the song run itself")
    }

    func testRepertoireGoalWithoutTargetSongYieldsNothing() {
        let song = PlannerSong(uid: UUID(), lastPracticed: nil, estimatedMinutes: 20)
        let library = PlannerLibrary(songs: [song])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["rep.learn-song"], song: nil)], library: library)
        XCTAssertTrue(candidates.isEmpty)
    }

    // MARK: - Path A loop tags (Slice 4, Decision 8)

    private func taggedLoop(_ templates: [ExerciseTemplate], mastery: Int? = nil) -> PlannerLoop {
        PlannerLoop(uid: UUID(), songUID: UUID(), mastery: mastery,
                    lastPracticed: nil, estimatedMinutes: 4, templates: templates)
    }

    func testTaggedLoopSurfacesViaTechniqueGoal() {
        // A loop tagged Picking is reachable by a picking goal (Path A), as a loop candidate — no
        // target song / repertoire goal involved.
        let loop = taggedLoop([.picking])
        let library = PlannerLibrary(loops: [loop])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(weight: 2.0, skills: ["pick.alternate"])], library: library)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].unit.kind, .loop)
        XCTAssertEqual(candidates[0].unit.uid, loop.uid)
        XCTAssertEqual(candidates[0].priority, 2.0, accuracy: 0.0001, "goal weight, no prereq penalty")
    }

    func testUntaggedLoopDoesNotSurfaceViaTechniqueGoal() {
        // Same loop with no recognised template stays out of Path A (it's Path-B only).
        let loop = taggedLoop([])
        let library = PlannerLibrary(loops: [loop])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["pick.alternate"])], library: library)
        XCTAssertTrue(candidates.isEmpty, "an untagged loop needs a target-song (Path B) to appear")
    }

    func testTaggedLoopMatchesOnlyServingSkill() {
        // A Picking-tagged loop must not answer a scales goal.
        let loop = taggedLoop([.picking])
        let library = PlannerLibrary(loops: [loop])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["scale.pentatonic"])], library: library)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testTaggedLoopAndExerciseBothSurfaceForOneSkill() {
        let exercise = pickingExercise()
        let loop = taggedLoop([.picking])
        let library = PlannerLibrary(exercises: [exercise], loops: [loop])
        let candidates = CandidateDeriver.deriveCandidates(
            goals: [goal(skills: ["pick.alternate"])], library: library)
        XCTAssertEqual(Set(candidates.map(\.unit.kind)), [.exercise, .loop])
        XCTAssertEqual(candidates.count, 2)
    }
}
