import XCTest
@testable import Pocket

/// ADR 0216 — *which skills a unit works on*, and the one fix the goal editor offers under a skill
/// that reaches nothing. Hand-authored tables and a replace-not-patch rule drive both, so the
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

    // MARK: - What a drill works on (D1)

    func testNothingStatedMeansTheTypeDefault() {
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .picking, stated: []),
                       SkillAssociation.defaultSkills(for: .picking))
    }

    func testAStatedListReplacesTheDefaultToNarrow() {
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .picking, stated: ["pick.sweep"]),
                       ["pick.sweep"], "Alternate picking and the rest are dropped, not kept alongside")
    }

    func testAStatedListReplacesTheDefaultToExpand() {
        let looping = SkillAssociation.customID(UUID())
        let stated = SkillAssociation.defaultSkills(for: .picking) + ["rhythm.timing", looping]
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .picking, stated: stated), stated,
                       "a taxonomy skill outside the type, and one the player made, both count")
    }

    func testBasicAndFreeformWorkOnOnlyWhatTheyState() {
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .basic, stated: []), [])
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .freeform, stated: ["create.songwriting"]),
                       ["create.songwriting"])
    }

    func testWarmUpWorksOnNothingWhateverIsStored() {
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .warmup, stated: ["pick.alternate"]), [])
    }

    func testAStatedDuplicateCountsOnce() {
        XCTAssertEqual(SkillAssociation.effectiveSkills(template: .basic, stated: ["rhythm.timing", "rhythm.timing"]),
                       ["rhythm.timing"])
    }

    func testTheDefaultChoiceStoresNothingSoTheDrillKeepsFollowingItsType() {
        let defaults = Set(SkillAssociation.defaultSkills(for: .picking))
        XCTAssertEqual(SkillAssociation.storedSkills(kept: defaults, template: .picking), [])
    }

    func testAnyOtherChoiceIsStoredInCatalogueOrder() {
        let looping = SkillAssociation.customID(UUID())
        // Handed over as a Set — the order must come from the taxonomy, not from hashing.
        let kept: Set = [looping, "rhythm.timing", "pick.alternate"]
        XCTAssertEqual(SkillAssociation.storedSkills(kept: kept, template: .picking),
                       ["pick.alternate", "rhythm.timing", looping])
    }

    func testSetByPlayerOnlyWhenTheListDiffersFromTheType() {
        XCTAssertFalse(SkillAssociation.isSetByPlayer(template: .picking, stated: []))
        XCTAssertFalse(SkillAssociation.isSetByPlayer(template: .picking,
                                                      stated: SkillAssociation.defaultSkills(for: .picking).reversed()),
                       "same skills in another order is still the type's list")
        XCTAssertTrue(SkillAssociation.isSetByPlayer(template: .picking, stated: ["pick.sweep"]))
        XCTAssertTrue(SkillAssociation.isSetByPlayer(template: .freeform, stated: ["create.songwriting"]))
    }

    func testResolvableDropsIdsThatNameNothing() {
        let kept = SkillAssociation.customID(UUID())
        let deleted = SkillAssociation.customID(UUID())
        XCTAssertEqual(SkillAssociation.resolvable(["pick.alternate", deleted, "not.a.skill", kept],
                                                   customIDs: [kept]),
                       ["pick.alternate", kept])
    }

    // MARK: - Loops

    func testALoopWorksOnWhatItStatesThenWhatItsTagsCarry() {
        XCTAssertEqual(SkillAssociation.loopSkills(stated: ["fret.bend", "pick.sweep"], templates: [.arpeggios]),
                       ["fret.bend", "pick.sweep", "pick.economy"], "a union, deduplicated")
        XCTAssertEqual(SkillAssociation.loopSkills(stated: [], templates: []), [])
    }

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

    // MARK: - Skills the player made (D7)

    func testACustomIDCarriesTheUIDNotTheName() {
        let uid = UUID()
        let skillID = SkillAssociation.customID(uid)
        XCTAssertTrue(SkillAssociation.isCustom(skillID))
        XCTAssertTrue(skillID.hasSuffix(uid.uuidString))
        XCTAssertFalse(SkillAssociation.isCustom("pick.alternate"))
    }

    func testDisplayNameNeverShowsARawID() {
        let looping = SkillAssociation.customID(UUID())
        let names = [looping: "Live looping"]
        XCTAssertEqual(SkillAssociation.displayName("pick.alternate", customNames: names), "Alternate picking")
        XCTAssertEqual(SkillAssociation.displayName(looping, customNames: names), "Live looping")
        let gone = SkillAssociation.displayName(SkillAssociation.customID(UUID()), customNames: names)
        XCTAssertFalse(gone.contains(SkillAssociation.customPrefix))
        XCTAssertFalse(SkillAssociation.displayName("not.a.skill", customNames: names).contains("not.a.skill"))
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

    func testFixFallsBackToALoopModeThenATargetSong() {
        XCTAssertEqual(SkillAssociation.fix(for: "ear.transcribe"), .runLoopIn(.ear))
        XCTAssertEqual(SkillAssociation.fix(for: "rep.learn-song"), .pickTargetSong)
    }

    func testEverythingElseIsAFreeformBlockThatStatesIt() {
        XCTAssertEqual(SkillAssociation.fix(for: "know.notes"), .makeFreeform, "only retired Theory serves it")
        XCTAssertEqual(SkillAssociation.fix(for: "rhythm.syncopation"), .makeFreeform, "only retired Rhythm")
        XCTAssertEqual(SkillAssociation.fix(for: "fret.vibrato"), .makeFreeform, "no type serves it")
        XCTAssertEqual(SkillAssociation.fix(for: SkillAssociation.customID(UUID())), .makeFreeform)
    }

    func testEveryOfferedFixIsOneThePlayerCanTake() {
        XCTAssertTrue(ExerciseTemplate.creatable.contains(.freeform), "the fallback fix must be creatable")
        for skill in TechniqueTaxonomy.all {
            if case .makeExercise(let template) = SkillAssociation.fix(for: skill.id) {
                XCTAssertTrue(ExerciseTemplate.creatable.contains(template), "\(skill.id) offers \(template)")
            }
        }
    }
}
