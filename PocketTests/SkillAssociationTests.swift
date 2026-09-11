import XCTest
@testable import Pocket

/// ADR 0216 slice 1 — the read half of *which skills a unit works on*, and the one fix the goal
/// editor offers under a skill that reaches nothing. Hand-authored tables drive both, so the
/// invariants that keep them honest are the logic that breaks silently — unit-tested per AGENTS.md.
final class SkillAssociationTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultSkillsAreTheFamilyMapRow() {
        XCTAssertEqual(SkillAssociation.defaultSkills(for: .picking), SkillFamilyMap.skillsByTemplate[.picking])
        XCTAssertEqual(SkillAssociation.defaultSkills(for: .basic), [])
        XCTAssertEqual(SkillAssociation.defaultSkills(for: .freeform), [])
        XCTAssertEqual(SkillAssociation.defaultSkills(for: .warmup), [])
    }

    func testDefaultTemplatesFollowDisplayOrderNotDictionaryOrder() {
        // The family map is a Dictionary; reading its iteration order would reshuffle per launch.
        XCTAssertEqual(SkillAssociation.defaultTemplates(forSkill: "pick.sweep"), [.picking, .arpeggios])
        XCTAssertEqual(SkillAssociation.defaultTemplates(forSkill: "rhythm.chord-changes"),
                       [.strumming, .chords, .strumChords, .fingerstyle])
    }

    func testCreatableTemplatesLeaveOutRetiredTypes() {
        XCTAssertEqual(SkillAssociation.creatableTemplates(forSkill: "know.notes"), [], "Theory is retired")
        XCTAssertEqual(SkillAssociation.creatableTemplates(forSkill: "rhythm.chord-changes"),
                       [.strumming, .chords, .strumChords])
    }

    // MARK: - The fix

    func testFixOffersTheMostCentralCreatableType() {
        XCTAssertEqual(SkillAssociation.fix(for: "rhythm.chord-changes"), .makeExercise(.chords),
                       "leads the Chords row; follows strumming in the Strumming row")
        XCTAssertEqual(SkillAssociation.fix(for: "pick.sweep"), .makeExercise(.arpeggios))
        XCTAssertEqual(SkillAssociation.fix(for: "pick.alternate"), .makeExercise(.picking))
        XCTAssertEqual(SkillAssociation.fix(for: "improv.vocabulary"), .makeExercise(.scales))
        XCTAssertEqual(SkillAssociation.fix(for: "fret.dexterity"), .makeExercise(.legato),
                       "Fingerstyle also serves it, but can no longer be created")
    }

    func testFixFallsBackToALoopModeThenATargetSongThenATag() {
        XCTAssertEqual(SkillAssociation.fix(for: "ear.transcribe"), .runLoopIn(.ear))
        XCTAssertEqual(SkillAssociation.fix(for: "rep.learn-song"), .pickTargetSong)
        XCTAssertEqual(SkillAssociation.fix(for: "know.notes"), .tagLoop(.theory))
        XCTAssertEqual(SkillAssociation.fix(for: "rhythm.syncopation"), .tagLoop(.rhythm))
    }

    func testASkillNoTypeServesHasNoFix() {
        XCTAssertEqual(SkillAssociation.fix(for: "fret.vibrato"), .nothing)
        XCTAssertEqual(SkillAssociation.fix(for: "fret.bend"), .nothing)
    }

    func testEveryOfferedFixIsOneThePlayerCanTake() {
        for skill in TechniqueTaxonomy.all {
            switch SkillAssociation.fix(for: skill.id) {
            case .makeExercise(let template):
                XCTAssertTrue(ExerciseTemplate.creatable.contains(template), "\(skill.id) offers \(template)")
            case .tagLoop(let template):
                XCTAssertTrue(SkillFamilyMap.taggableTemplates.contains(template), "\(skill.id) offers \(template)")
            case .runLoopIn, .pickTargetSong, .nothing:
                break
            }
        }
    }

    // MARK: - Loop tags

    func testTagSkillsDedupeAndCreditTheFirstTag() {
        let skills = SkillAssociation.tagSkills(forTags: ["Arpeggios", "picking", "chorus"])
        XCTAssertEqual(skills.map(\.skillID), ["pick.sweep", "pick.economy", "pick.alternate",
                                               "pick.string-skip", "pick.tremolo", "pick.hybrid"])
        XCTAssertEqual(skills.first?.template, .arpeggios)
        XCTAssertEqual(skills.last?.template, .picking)
    }

    func testUnrecognisedTagsCarryNoSkills() {
        XCTAssertTrue(SkillAssociation.tagSkills(forTags: []).isEmpty)
        XCTAssertTrue(SkillAssociation.tagSkills(forTags: ["chorus", "Warm-up"]).isEmpty)
    }
}
