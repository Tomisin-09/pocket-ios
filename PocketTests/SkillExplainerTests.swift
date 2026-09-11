import XCTest
@testable import Pocket

/// ADR 0216 D5 — the text behind a skill's ⓘ. The one-liners are hand-written, so they are held to
/// exactly the taxonomy; the rest is derived from the planner's own tables, so it is pinned against
/// the routes the planner actually takes. A skill the player made shows their own words.
final class SkillExplainerTests: XCTestCase {

    func testEveryTaxonomySkillHasALineAndNoLineIsOrphaned() {
        XCTAssertEqual(Set(SkillExplainer.lines.keys), Set(TechniqueTaxonomy.all.map(\.id)))
    }

    func testLinesAreOneSentenceInTheAppsVoice() {
        for (skill, line) in SkillExplainer.lines {
            XCTAssertTrue(line.hasSuffix("."), skill)
            XCTAssertFalse(line.contains("\n"), skill)
            XCTAssertFalse(line.localizedCaseInsensitiveContains("pocket"),
                           "\(skill): user-facing copy says Red Moon, never Pocket")
        }
    }

    func testWorkedOnByNamesEveryDefaultRouteThePlannerTakes() {
        XCTAssertEqual(SkillExplainer.workedOnBy("pick.sweep"),
                       "By default, worked on by Picking and Arpeggios exercises, "
                       + "and loops tagged Picking or Arpeggios.")
        // Not "loops tagged Ear Training, and any loop…" — the second route already contains the first.
        XCTAssertEqual(SkillExplainer.workedOnBy("ear.transcribe"),
                       "By default, worked on by any loop you run in Train your ear.")
        XCTAssertEqual(SkillExplainer.workedOnBy("improv.vocabulary"),
                       "By default, worked on by Scales exercises, loops tagged Scales, backing tracks you run in "
                       + "Improvise, and the target song you give a goal.")
        XCTAssertEqual(SkillExplainer.workedOnBy("rep.learn-song"),
                       "By default, worked on by the target song you give a goal.")
    }

    func testASkillWithNoDefaultRouteSaysHowToGiveItOne() {
        XCTAssertEqual(SkillExplainer.workedOnBy("fret.vibrato"), SkillExplainer.noDefaultRoute)
        // The template's player-facing name: "freeform" is the code's word, never the player's.
        XCTAssertTrue(SkillExplainer.noDefaultRoute.contains("write your own practice"))
        XCTAssertFalse(SkillExplainer.noDefaultRoute.lowercased().contains("freeform"))
    }

    func testComesAfterNamesThePrerequisites() {
        XCTAssertEqual(SkillExplainer.comesAfter("pick.sweep"), "Comes after Economy picking.")
        XCTAssertEqual(SkillExplainer.comesAfter("fret.legato"), "Comes after Hammer-ons and Pull-offs.")
        XCTAssertNil(SkillExplainer.comesAfter("pick.alternate"))
    }

    func testTextIsTheLineThenTheRoutesThenWhatComesFirst() throws {
        let line = try XCTUnwrap(SkillExplainer.line(for: "pick.sweep"))
        XCTAssertEqual(SkillExplainer.text(for: "pick.sweep"),
                       [line, SkillExplainer.workedOnBy("pick.sweep"), "Comes after Economy picking."]
                        .joined(separator: "\n\n"))
        // No prerequisites ⇒ two parts, not a trailing blank one.
        XCTAssertEqual(SkillExplainer.text(for: "pick.alternate").components(separatedBy: "\n\n").count, 2)
    }

    func testASkillThePlayerMadeShowsTheirOwnWords() {
        let text = SkillExplainer.customText(info: "  Layering parts with a looper pedal. ")
        XCTAssertTrue(text.hasPrefix("Layering parts with a looper pedal.\n\n"))
    }

    func testASkillWithNoDescriptionStillSaysSomething() {
        XCTAssertTrue(SkillExplainer.customText(info: "").hasPrefix("A skill you made."))
    }

    func testTheVocabularyNamesAndExplainsBothKinds() {
        let looping = SkillAssociation.customID(UUID())
        let vocabulary = SkillVocabulary(custom: [looping: .init(name: "Live looping", info: "Pedal work.")])
        XCTAssertEqual(vocabulary.name("pick.alternate"), "Alternate picking")
        XCTAssertEqual(vocabulary.name(looping), "Live looping")
        XCTAssertEqual(vocabulary.explanation("pick.alternate"), SkillExplainer.text(for: "pick.alternate"))
        XCTAssertTrue(vocabulary.explanation(looping).hasPrefix("Pedal work."))
        XCTAssertEqual(vocabulary.resolvable(["pick.alternate", looping, SkillAssociation.customID(UUID())]),
                       ["pick.alternate", looping], "a skill that was deleted is not listed")
    }

    func testListed() {
        XCTAssertEqual(SkillExplainer.listed([], joiner: "and"), "")
        XCTAssertEqual(SkillExplainer.listed(["A"], joiner: "and"), "A")
        XCTAssertEqual(SkillExplainer.listed(["A", "B"], joiner: "or"), "A or B")
        XCTAssertEqual(SkillExplainer.listed(["A", "B", "C"], joiner: "and"), "A, B and C")
    }
}
