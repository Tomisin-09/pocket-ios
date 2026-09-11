import XCTest
@testable import Pocket

/// ADR 0216 D1/D3/D7 — the planner reads what a drill or loop **states** it works on, not only its
/// type, and a skill the player made resolves to exactly the units that state it. Its own suite
/// because `CandidateDeriverTests` sits at its body-length cap.
final class StatedSkillsDeriverTests: XCTestCase {

    private func goal(weight: Double = 1.0, skills: [String]) -> PlannerGoal {
        PlannerGoal(weight: weight, skillIDs: skills)
    }

    private func exercise(_ template: ExerciseTemplate, mastery: Int? = nil,
                          stating skills: [String] = []) -> PlannerExercise {
        PlannerExercise(uid: UUID(), template: template, mastery: mastery,
                        lastPracticed: nil, estimatedMinutes: 10, skillIDs: skills)
    }

    private func loop(stating skills: [String] = [], tags templates: [ExerciseTemplate] = []) -> PlannerLoop {
        PlannerLoop(uid: UUID(), songUID: UUID(), mastery: nil, lastPracticed: nil,
                    estimatedMinutes: 4, templates: templates, skillIDs: skills)
    }

    private func pulled(_ skills: [String], weight: Double = 1.0, from library: PlannerLibrary) -> Set<UUID> {
        Set(CandidateDeriver.deriveCandidates(goals: [goal(weight: weight, skills: skills)], library: library)
            .map(\.unit.uid))
    }

    func testANarrowedDrillIsNotPulledForASkillItDropped() {
        let narrowed = exercise(.picking, stating: ["pick.sweep"])
        let library = PlannerLibrary(exercises: [narrowed])
        XCTAssertEqual(pulled(["pick.alternate"], from: library), [])
        XCTAssertEqual(pulled(["pick.sweep"], from: library), [narrowed.uid])
    }

    func testAnExpandedDrillIsPulledForASkillOutsideItsType() {
        let expanded = exercise(.picking, stating: ["pick.alternate", "rhythm.timing"])
        XCTAssertEqual(pulled(["rhythm.timing"], from: PlannerLibrary(exercises: [expanded])), [expanded.uid])
    }

    func testPrereqReadinessCountsWhatADrillStates() throws {
        // Sweep comes after economy. A well-rated Legato drill that states economy now counts toward
        // it; a well-rated Picking drill narrowed away from economy no longer does.
        let sweep = try XCTUnwrap(TechniqueTaxonomy.info("pick.sweep"))
        let stating = exercise(.legato, mastery: 5, stating: ["pick.economy"])
        let narrowedAway = exercise(.picking, mastery: 5, stating: ["pick.alternate"])
        XCTAssertEqual(CandidateDeriver.prereqReadiness(for: sweep, library: PlannerLibrary(exercises: [stating])),
                       1.0, accuracy: 0.0001)
        XCTAssertEqual(CandidateDeriver.prereqReadiness(for: sweep, library: PlannerLibrary(exercises: [narrowedAway])),
                       CandidateDeriver.prereqPenalty, accuracy: 0.0001)
    }

    func testAFreeformBlockIsPulledForWhatItStatesAndNothingElse() {
        let songwriting = exercise(.freeform, stating: ["create.songwriting"])
        let unstated = exercise(.freeform)
        let library = PlannerLibrary(exercises: [songwriting, unstated])
        XCTAssertEqual(pulled(["create.songwriting"], from: library), [songwriting.uid],
                       "closes the zero-candidate gap Theory's retirement left")
        XCTAssertEqual(pulled(["pick.alternate"], from: library), [])
    }

    func testALoopIsPulledForWhatItStatesAndForWhatItsTagsCarry() {
        let stated = loop(stating: ["fret.bend"])
        let both = loop(stating: ["fret.bend"], tags: [.picking])
        let library = PlannerLibrary(loops: [stated, both])
        XCTAssertEqual(pulled(["fret.bend"], from: library), [stated.uid, both.uid])
        XCTAssertEqual(pulled(["pick.alternate"], from: library), [both.uid], "a tag still counts (ADR 0074)")
    }

    func testACustomSkillPullsExactlyTheUnitsThatStateItAtTheGoalsWeight() {
        let looping = SkillAssociation.customID(UUID())
        let block = exercise(.freeform, stating: [looping])
        let drill = exercise(.picking, stating: ["pick.alternate", looping])
        let stating = loop(stating: [looping])
        let bystander = exercise(.picking)
        let library = PlannerLibrary(exercises: [block, drill, bystander], loops: [stating])
        let candidates = CandidateDeriver.deriveCandidates(goals: [goal(weight: 2.0, skills: [looping])],
                                                           library: library)
        XCTAssertEqual(Set(candidates.map(\.unit.uid)), [block.uid, drill.uid, stating.uid])
        for candidate in candidates {
            XCTAssertEqual(candidate.priority, 2.0, accuracy: 0.0001, "no prerequisites, no emphasis")
            XCTAssertEqual(candidate.skillID, looping)
        }
    }

    func testAnIDThatNamesNothingIsSkipped() {
        let library = PlannerLibrary(exercises: [exercise(.picking)])
        XCTAssertEqual(pulled(["not.a.skill"], from: library), [])
        XCTAssertEqual(pulled([SkillAssociation.customID(UUID())], from: library), [])
    }

    /// **The invariant (D1):** with nothing stated anywhere, every technique skill pulls exactly what
    /// the family map pulled before 0216 — one drill of every type and one loop per bucket tag.
    func testWithNothingStatedEveryTechniqueSkillPullsWhatTheFamilyMapDid() {
        let exercises = ExerciseTemplate.allCases.filter { $0 != .warmup }.map { exercise($0) }
        let loops = SkillFamilyMap.taggableTemplates.map { loop(tags: [$0]) }
        let library = PlannerLibrary(exercises: exercises, loops: loops)
        for skill in TechniqueTaxonomy.all where !skill.mode.isRepertoire {
            let old = exercises.filter { SkillFamilyMap.template($0.template, serves: skill.id) }.map(\.uid)
                + loops.filter { $0.templates.contains { SkillFamilyMap.template($0, serves: skill.id) } }.map(\.uid)
            XCTAssertEqual(pulled([skill.id], from: library), Set(old), skill.id)
        }
    }
}
