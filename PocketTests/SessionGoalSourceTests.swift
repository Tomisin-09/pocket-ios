import XCTest
@testable import Pocket

/// Which tier of goal a generated session draws on (ADR 0171 D10), and the integrity of the goal
/// **templates** both tiers author from. Pure — no `@Model`s.
final class SessionGoalSourceTests: XCTestCase {

    // MARK: - Source resolution

    func testBothDrawsOnEitherTier() {
        let plan = SessionGoalSource.both.plan(activeShortTermCount: 2, activeLongTermCount: 3)
        XCTAssertTrue(plan.usesShortTerm)
        XCTAssertTrue(plan.usesLongTerm)
        XCTAssertFalse(plan.isQuickFallback)
    }

    func testSelectingOneTierExcludesTheOtherEvenWhenItHasGoals() {
        let today = SessionGoalSource.thisSession.plan(activeShortTermCount: 2, activeLongTermCount: 3)
        XCTAssertTrue(today.usesShortTerm)
        XCTAssertFalse(today.usesLongTerm, "picking This session must not quietly keep using the ranking")

        let standing = SessionGoalSource.longTerm.plan(activeShortTermCount: 2, activeLongTermCount: 3)
        XCTAssertFalse(standing.usesShortTerm)
        XCTAssertTrue(standing.usesLongTerm)
    }

    /// **The button always produces something to practise** (ADR 0073). Choosing a tier the player
    /// has left empty falls back to the due-ranked Quick path rather than refusing to generate.
    func testAnEmptySelectedTierFallsBackToQuickRatherThanRefusing() {
        XCTAssertTrue(SessionGoalSource.longTerm
            .plan(activeShortTermCount: 5, activeLongTermCount: 0).isQuickFallback)
        XCTAssertTrue(SessionGoalSource.thisSession
            .plan(activeShortTermCount: 0, activeLongTermCount: 5).isQuickFallback)
        XCTAssertTrue(SessionGoalSource.both
            .plan(activeShortTermCount: 0, activeLongTermCount: 0).isQuickFallback)
    }

    /// With one tier empty, `both` behaves exactly as selecting the tier that isn't — which is what
    /// lets the control stay hidden until a second tier actually exists.
    func testBothCollapsesToWhicheverTierIsPopulated() {
        XCTAssertEqual(SessionGoalSource.both.plan(activeShortTermCount: 0, activeLongTermCount: 4),
                       SessionGoalSource.longTerm.plan(activeShortTermCount: 0, activeLongTermCount: 4))
        XCTAssertEqual(SessionGoalSource.both.plan(activeShortTermCount: 4, activeLongTermCount: 0),
                       SessionGoalSource.thisSession.plan(activeShortTermCount: 4, activeLongTermCount: 0))
    }

    /// The dead end the planner's `effectiveSource` fallback exists to prevent, stated as the rule
    /// rather than as the view's `if`: **with no standing goals, every source must behave as
    /// `both`.** That is the condition under which the `Build from` control is not on screen, and a
    /// control the player cannot see must not still be steering what they can.
    ///
    /// The reachable sequence otherwise: pick `Long-term`, then mark the last standing goal met.
    /// The segment disappears, but the stored selection keeps excluding the short-term tier — a
    /// planner with no goals on it and no visible way to get them back.
    func testWithNoStandingGoalsEverySourceBehavesAsBoth() {
        for source in SessionGoalSource.allCases {
            let plan = source.plan(activeShortTermCount: 3, activeLongTermCount: 0)
            let asBoth = SessionGoalSource.both.plan(activeShortTermCount: 3, activeLongTermCount: 0)
            XCTAssertEqual(plan.usesLongTerm, asBoth.usesLongTerm,
                           "\(source.label) must not claim a standing tier that is empty")
        }
        // …and the short-term tier is the one that must survive, since it is all there is.
        XCTAssertTrue(SessionGoalSource.both
            .plan(activeShortTermCount: 3, activeLongTermCount: 0).usesShortTerm)
    }

    /// Every segment must be reachable *and* distinguishable — two labels reading the same, or a
    /// case missing from `allCases`, would make the control lie about what it offers.
    func testEverySourceIsOfferedAndDistinctlyLabelled() {
        XCTAssertEqual(SessionGoalSource.allCases.count, 3)
        let labels = SessionGoalSource.allCases.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count, "two segments read the same")
        XCTAssertTrue(labels.allSatisfy { !$0.isEmpty })
    }

    // MARK: - Template integrity

    /// **The failure this exists to catch is silent.** A template whose skill id is misspelled, or
    /// which names a real taxonomy skill that no `ExerciseTemplate` can serve, still renders as a
    /// perfectly ordinary row — it simply deals nothing when the player generates a session. The
    /// six templates added alongside ADR 0171 D5 were hand-written against the taxonomy, which is
    /// exactly the circumstance this guards.
    func testEveryTemplateSkillExistsInTheTaxonomy() {
        for template in GoalTemplateLibrary.all {
            XCTAssertFalse(template.skillIDs.isEmpty, "\(template.id) seeds no skills")
            for skillID in template.skillIDs {
                XCTAssertNotNil(TechniqueTaxonomy.info(skillID),
                                "\(template.id) names '\(skillID)', which is not in the taxonomy")
            }
        }
    }

    /// Every seeded skill must be *resolvable*: either an `ExerciseTemplate` can serve it (Path A)
    /// or it is repertoire and routes to the goal's target song (Path B). A skill in neither is a
    /// row that schedules nothing.
    func testEveryTemplateSkillCanActuallyResolveToSomething() {
        for template in GoalTemplateLibrary.all {
            for skillID in template.skillIDs {
                let isRepertoire = TechniqueTaxonomy.info(skillID)?.mode.isRepertoire == true
                let servedByAFamily = !SkillFamilyMap.templates(forSkill: skillID).isEmpty
                XCTAssertTrue(isRepertoire || servedByAFamily,
                              "\(template.id) names '\(skillID)', which no exercise family serves "
                              + "and which is not song-routed — it would schedule nothing")
            }
        }
    }

    func testTemplateIdsAreUniqueAndResolveBackToTheirTemplate() {
        let ids = GoalTemplateLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate template id")
        for id in ids { XCTAssertEqual(GoalTemplateLibrary.template(id)?.id, id) }
    }

    /// Only a template that actually seeds a repertoire skill may claim to need a target song —
    /// otherwise the editor would ask for one it has no Path-B use for.
    func testOnlyRepertoireTemplatesRequireATargetSong() {
        for template in GoalTemplateLibrary.all where template.requiresTargetSong {
            XCTAssertTrue(template.skillIDs.contains { TechniqueTaxonomy.info($0)?.mode.isRepertoire == true },
                          "\(template.id) asks for a target song but seeds no repertoire skill")
        }
    }
}
