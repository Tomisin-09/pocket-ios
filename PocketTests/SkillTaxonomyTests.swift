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

    // MARK: - Loop skill tags (Slice 4, Decision 8)

    func testTaggableTemplatesAreExactlyTheSkillCarryingOnes() {
        // The taggable buckets are precisely the family-map keys (skill-carrying templates), so
        // Basic/Warm-up are never offered as loop skill tags.
        XCTAssertEqual(Set(SkillFamilyMap.taggableTemplates),
                       Set(SkillFamilyMap.skillsByTemplate.keys))
        XCTAssertFalse(SkillFamilyMap.taggableTemplates.contains(.basic))
        XCTAssertFalse(SkillFamilyMap.taggableTemplates.contains(.warmup))
    }

    func testEverySuggestedTagRecognisesBackToItsTemplate() {
        // Round-trip: each suggested tag string resolves to a taggable template.
        for template in SkillFamilyMap.taggableTemplates {
            XCTAssertEqual(SkillFamilyMap.recognizedTemplate(for: template.displayName), template)
        }
        XCTAssertEqual(SkillFamilyMap.suggestedLoopTags.count, SkillFamilyMap.taggableTemplates.count)
    }

    func testRecognitionIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(SkillFamilyMap.recognizedTemplate(for: "picking"), .picking)
        XCTAssertEqual(SkillFamilyMap.recognizedTemplate(for: "  Picking  "), .picking)
        XCTAssertEqual(SkillFamilyMap.recognizedTemplate(for: "EAR TRAINING"), .earTraining)
    }

    func testArbitraryTagsAreNotRecognised() {
        XCTAssertNil(SkillFamilyMap.recognizedTemplate(for: "chorus"))
        XCTAssertNil(SkillFamilyMap.recognizedTemplate(for: "needs-work"))
        XCTAssertNil(SkillFamilyMap.recognizedTemplate(for: ""))
        // Structural templates aren't taggable, so their names don't recognise either.
        XCTAssertNil(SkillFamilyMap.recognizedTemplate(for: "Warm-up"))
        XCTAssertNil(SkillFamilyMap.recognizedTemplate(for: "Basic"))
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

    // MARK: - Skill catalog search (R2)

    func testEverySkillMapsToADisplayFamily() {
        // The picker groups the whole catalog — an unfamilied skill would silently vanish from it.
        for skill in TechniqueTaxonomy.all {
            XCTAssertNotNil(SkillCatalog.family(of: skill.id), "\(skill.id) has no display family")
        }
    }

    func testFamilyDerivationByPrefix() {
        XCTAssertEqual(SkillCatalog.family(of: "pick.sweep"), .picking)
        XCTAssertEqual(SkillCatalog.family(of: "improv.vocabulary"), .scales)
        XCTAssertEqual(SkillCatalog.family(of: "create.songwriting"), .repertoire)
        XCTAssertNil(SkillCatalog.family(of: "nope.not-real"))
    }

    func testGroupedCoversEverySkillWithoutDuplicates() {
        let grouped = SkillCatalog.grouped()
        let flattened = grouped.flatMap { $0.skills.map(\.id) }
        XCTAssertEqual(Set(flattened), allSkillIDs, "grouping must cover every skill exactly once")
        XCTAssertEqual(flattened.count, allSkillIDs.count, "a skill appears in two families")
    }

    func testGroupedFamiliesFollowAllCasesOrder() {
        let order = SkillCatalog.grouped().map(\.family)
        XCTAssertEqual(order, SkillFamily.allCases.filter { family in order.contains(family) })
    }

    func testEmptyQueryReturnsWholeCatalog() {
        XCTAssertEqual(SkillCatalog.search("   ").flatMap { $0.skills }.count, TechniqueTaxonomy.all.count)
        XCTAssertEqual(SkillCatalog.search("").flatMap { $0.skills }.count, TechniqueTaxonomy.all.count)
    }

    func testSearchIsCaseInsensitiveAndMatchesNames() {
        let hits = SkillCatalog.search("SWEEP").flatMap { $0.skills.map(\.id) }
        XCTAssertEqual(hits, ["pick.sweep"])
    }

    func testSearchNarrowsToMatchingFamiliesOnly() {
        // "scale" hits only the scale rows, so only the Scales family survives.
        let groups = SkillCatalog.search("scale")
        XCTAssertEqual(groups.map(\.family), [.scales])
        XCTAssertTrue(groups.first?.skills.allSatisfy { $0.id.hasPrefix("scale.") } ?? false)
    }

    func testSearchNeverMatchesRawID() {
        // "pick." is an id prefix, not a word in any name — searching it finds nothing.
        XCTAssertTrue(SkillCatalog.search("pick.").isEmpty)
    }

    func testSearchWithNoMatchIsEmpty() {
        XCTAssertTrue(SkillCatalog.search("zzzznotaskill").isEmpty)
    }
}
