import XCTest
@testable import Pocket

/// Integrity of the pure planner reference data (V2 planner Slice 2): the technique taxonomy, the
/// template→skill family map, and the curated goal templates. These tables are hand-authored, so
/// the invariants that keep them internally consistent (every referenced id is real) are the logic
/// that breaks silently — unit-tested per AGENTS.md.
final class SkillTaxonomyTests: XCTestCase {

    private var allSkillIDs: Set<String> { Set(TechniqueTaxonomy.all.map(\.id)) }

    func testSkillIDsAreUnique() {
        XCTAssertEqual(TechniqueTaxonomy.all.count, allSkillIDs.count, "duplicate SkillID in taxonomy")
    }

    func testEveryPrereqReferencesARealSkill() {
        for skill in TechniqueTaxonomy.all {
            for prereq in skill.prereqs {
                XCTAssertTrue(allSkillIDs.contains(prereq),
                              "\(skill.id) lists unknown prereq \(prereq)")
            }
        }
    }

    func testInfoAndLookupsRoundTrip() {
        let sweep = TechniqueTaxonomy.info("pick.sweep")
        XCTAssertEqual(sweep?.mode, .speedRamp)
        XCTAssertEqual(sweep?.difficulty, .adv)
        XCTAssertEqual(TechniqueTaxonomy.prereqs("pick.sweep"), ["pick.economy"])
        XCTAssertEqual(TechniqueTaxonomy.mode("rep.learn-song"), .repertoire)
        XCTAssertNil(TechniqueTaxonomy.info("nope.not-real"))
        XCTAssertEqual(TechniqueTaxonomy.prereqs("nope.not-real"), [])
    }

    func testRepertoireModeDetection() {
        XCTAssertTrue(SkillMode.repertoire.isRepertoire)
        XCTAssertFalse(SkillMode.speedRamp.isRepertoire)
        XCTAssertFalse(SkillMode.loopDrill.isRepertoire)
    }

    // MARK: - Family map

    func testFamilyMapOnlyReferencesRealSkills() {
        for (template, skills) in SkillFamilyMap.skillsByTemplate {
            for skill in skills {
                XCTAssertTrue(allSkillIDs.contains(skill),
                              "\(template) maps to unknown skill \(skill)")
            }
        }
    }

    func testFamilyMapResolvesTemplatesForSkill() {
        XCTAssertTrue(SkillFamilyMap.template(.picking, serves: "pick.alternate"))
        XCTAssertFalse(SkillFamilyMap.template(.chords, serves: "pick.alternate"))
        XCTAssertTrue(SkillFamilyMap.templates(forSkill: "pick.alternate").contains(.picking))
    }

    func testStructuralTemplatesCarryNoSkills() {
        // Basic (catch-all) and Warm-up (structural, LRU-placed — Decision 3) resolve no goal.
        XCTAssertNil(SkillFamilyMap.skillsByTemplate[.basic])
        XCTAssertNil(SkillFamilyMap.skillsByTemplate[.warmup])
    }

    // MARK: - Goal templates

    func testGoalTemplateSkillsAreAllRealSkills() {
        for template in GoalTemplateLibrary.all {
            for skill in template.skillIDs {
                XCTAssertTrue(allSkillIDs.contains(skill),
                              "goal template \(template.id) seeds unknown skill \(skill)")
            }
        }
    }

    func testRepertoireGoalTemplateRequiresTargetSong() {
        let playSong = GoalTemplateLibrary.template("play-song")
        XCTAssertEqual(playSong?.requiresTargetSong, true)
        // Its skills are all repertoire-mode (they need a song to resolve).
        for skill in playSong?.skillIDs ?? [] {
            XCTAssertEqual(TechniqueTaxonomy.mode(skill), .repertoire, "\(skill) should be repertoire")
        }
    }

    func testTechniqueGoalTemplatesDoNotRequireASong() {
        for template in GoalTemplateLibrary.all where template.id != "play-song" {
            XCTAssertFalse(template.requiresTargetSong, "\(template.id) should not require a song")
        }
    }
}
