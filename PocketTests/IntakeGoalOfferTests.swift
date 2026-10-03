import XCTest
@testable import Pocket

/// The first run's goals card (ADR 0246): what it offers, in what order, when it asks, and how a tap
/// changes the picks. Every `LongTermGoal` here is **uninserted**, like `LongTermGoalTests`.
final class IntakeGoalOfferTests: XCTestCase {

    /// What a new install's planner can see: the first-run drills, no loops, no songs.
    @MainActor
    private var firstRunLibrary: PlannerLibrary {
        PracticePlanner.library(exercises: PracticePresets.makeExercises(PracticePresets.firstRunSpecs))
    }

    // MARK: - What the card offers

    /// The rule the card stands on: **no offered goal comes to nothing on a new install.** A goal
    /// that gives Today's session nothing makes the player's first answer worthless. Adding a template
    /// to `offeredIDs`, or taking a drill out of the first-run set, has to keep this green.
    @MainActor
    func testEveryOfferedGoalGivesTodaysSessionSomethingOnANewInstall() {
        let library = firstRunLibrary
        for id in IntakeGoalOffer.offeredIDs {
            guard let template = GoalTemplateLibrary.template(id) else {
                XCTFail("offered id \(id) names no template"); continue
            }
            let candidates = CandidateDeriver.deriveCandidates(
                goals: [PlannerGoal(skillIDs: template.skillIDs)], library: library)
            XCTAssertFalse(candidates.isEmpty, "\(id) derives nothing from the first-run library")
        }
    }

    /// A new install has no song, so a goal that needs one cannot be offered — the song template is
    /// what the rule above was written to keep off the card.
    func testNoOfferedGoalNeedsASong() {
        let needingASong = IntakeGoalOffer.offeredIDs.compactMap(GoalTemplateLibrary.template)
            .filter(\.requiresTargetSong).map(\.id)
        XCTAssertEqual(needingASong, [])
    }

    func testTheCardOffersMoreThanItTakes() {
        XCTAssertGreaterThan(IntakeGoalOffer.offeredIDs.count, IntakeGoalOffer.maxPicks)
        XCTAssertEqual(Set(IntakeGoalOffer.offeredIDs).count, IntakeGoalOffer.offeredIDs.count)
    }

    // MARK: - When it asks

    func testUnwindingIsNotAskedForGoals() {
        XCTAssertFalse(IntakeGoalOffer.asksForGoals(after: .unwind))
    }

    /// Skipping the dream is not a statement about goals.
    func testEveryOtherAnswerIsAskedAndSoIsASkippedDream() {
        XCTAssertTrue(IntakeGoalOffer.asksForGoals(after: nil))
        for dream in MusicalDream.allCases where dream != .unwind {
            XCTAssertTrue(IntakeGoalOffer.asksForGoals(after: dream), "\(dream)")
        }
    }

    // MARK: - Order

    /// The dream reorders the card and never shortens it: every offered template is there exactly
    /// once whatever the answer, and the dream's closest ones lead.
    func testTheDreamLeadsAndNothingIsLost() {
        let offered = Set(IntakeGoalOffer.offeredIDs)
        for dream in [nil] + MusicalDream.allCases.map(Optional.some) {
            let ids = IntakeGoalOffer.templates(for: dream).map(\.id)
            XCTAssertEqual(ids.count, offered.count, "\(String(describing: dream))")
            XCTAssertEqual(Set(ids), offered, "\(String(describing: dream))")
            let leading = (dream.map(IntakeGoalOffer.preferredIDs) ?? []).filter(offered.contains)
            XCTAssertEqual(Array(ids.prefix(leading.count)), leading, "\(String(describing: dream))")
        }
    }

    /// A dream that leads with nothing would make the reordering invisible for that answer.
    func testEveryDreamThatAsksLeadsWithAnOfferedGoal() {
        let offered = Set(IntakeGoalOffer.offeredIDs)
        for dream in MusicalDream.allCases where IntakeGoalOffer.asksForGoals(after: dream) {
            XCTAssertFalse(IntakeGoalOffer.preferredIDs(for: dream).filter(offered.contains).isEmpty,
                           "\(dream) leads with nothing the card offers")
        }
    }

    func testASkippedDreamKeepsLibraryOrder() {
        XCTAssertEqual(IntakeGoalOffer.templates(for: nil).map(\.id), IntakeGoalOffer.offeredIDs)
    }

    // MARK: - Picking

    func testTapOrderIsRankAndATapAgainRemovesIt() {
        var picks = IntakeGoalOffer.toggling("timing", in: [])
        picks = IntakeGoalOffer.toggling("build-speed", in: picks)
        picks = IntakeGoalOffer.toggling("general", in: picks)
        XCTAssertEqual(picks, ["timing", "build-speed", "general"])
        XCTAssertEqual(IntakeGoalOffer.toggling("timing", in: picks), ["build-speed", "general"])
    }

    /// Past the cap a tap does nothing, rather than quietly replacing a pick the player made.
    func testAPickPastTheCapIsIgnored() {
        let full = ["timing", "build-speed", "general"]
        XCTAssertEqual(full.count, IntakeGoalOffer.maxPicks)
        XCTAssertEqual(IntakeGoalOffer.toggling("chord-changes", in: full), full)
    }

    // MARK: - What it makes

    func testPicksBecomeGoalsRankedAsTappedBelowAnyAlready() {
        let templates = ["build-speed", "timing"].compactMap(GoalTemplateLibrary.template)
        let goals = LongTermGoalStore.makeGoals(from: templates, below: 2)
        XCTAssertEqual(goals.map(\.order), [2, 3])
        XCTAssertEqual(goals.map(\.title), templates.map(\.title))
        XCTAssertEqual(goals.map(\.skillIDs), templates.map(\.skillIDs))
        XCTAssertTrue(goals.allSatisfy { !$0.isMet && $0.targetSong == nil })
    }
}
