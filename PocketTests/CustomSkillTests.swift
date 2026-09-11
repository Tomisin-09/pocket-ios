import XCTest
@testable import Pocket

/// A skill the player made (ADR 0216 D7) — the rules its name is held to. The name is how the player
/// tells two skills apart, so a pair that differ only in case or spacing would be one skill split
/// across two ids.
final class CustomSkillTests: XCTestCase {

    func testTheIDCarriesTheUIDSoARenameMovesNothing() {
        let skill = CustomSkill(name: "Live looping")
        let before = skill.skillID
        skill.name = "Looping live"
        XCTAssertEqual(skill.skillID, before)
        XCTAssertEqual(skill.skillID, SkillAssociation.customID(skill.uid))
    }

    func testNamesFoldCaseAndSpacing() {
        XCTAssertEqual(CustomSkill.foldedName("  Live   LOOPING "), "live looping")
        XCTAssertEqual(CustomSkill.foldedName("   "), "")
    }

    func testAnEmptyNameIsRefused() {
        XCTAssertEqual(CustomSkill.nameProblem("   ", takenNames: []), "Give it a name.")
    }

    func testANameAnotherSkillHasIsRefusedWhateverItsCase() {
        let problem = CustomSkill.nameProblem("live looping", takenNames: ["Live looping"])
        XCTAssertEqual(problem, "\u{201C}Live looping\u{201D} is already a skill.")
    }

    func testACatalogueNameIsRefusedSoItCantShadowTheRealOne() {
        let catalogue = TechniqueTaxonomy.all.map(\.name)
        XCTAssertNotNil(CustomSkill.nameProblem("alternate picking", takenNames: catalogue))
    }

    func testAFreshNameIsAccepted() {
        XCTAssertNil(CustomSkill.nameProblem("Live looping", takenNames: ["Chord melody"]))
    }

    // MARK: - What delete's confirmation says

    func testUsageIsCountedInWords() {
        XCTAssertEqual(CustomSkillStore.Usage(goals: 1, drills: 2, loops: 1).summary,
                       "Used by 1 goal, 2 drills and 1 loop.")
        XCTAssertEqual(CustomSkillStore.Usage(goals: 0, drills: 1, loops: 0).summary, "Used by 1 drill.")
    }

    func testAnUnusedSkillHasNothingToWarnAbout() {
        let unused = CustomSkillStore.Usage()
        XCTAssertTrue(unused.isEmpty)
        XCTAssertNil(unused.summary)
    }
}
