import XCTest
@testable import Pocket

/// `PaywallTrigger`'s reporting axes (ADR 0120, extending ADR 0112).
///
/// The trigger gained associated values so the two gates that already knew *what* was reached for —
/// the template picker and the five routine actions — stop discarding it at the boundary. That
/// detail is the evidence behind every future free-vs-Pro decision, so it is pinned here.
final class PaywallTriggerTests: XCTestCase {

    private let coarse: [PaywallTrigger] = [
        .drawYourOwn, .newExercise(nil), .proExercise, .planner, .routine(.new), .general
    ]

    func testCoarseTriggerNamesAreFrozenAndUnique() {
        XCTAssertEqual(coarse.map(\.reportingName),
                       ["draw_your_own", "new_exercise", "pro_exercise",
                        "planner", "routine", "general"],
                       "Trigger names are a wire format — renaming breaks the dashboard series.")
        XCTAssertEqual(Set(coarse.map(\.reportingName)).count, coarse.count)
    }

    func testEveryProTemplateSurvivesToReporting() {
        for template in ExerciseTemplate.allCases where template.authoringTier == .pro {
            XCTAssertEqual(PaywallTrigger.newExercise(template).reportingDetail, template.rawValue,
                           "\(template) is Pro to author, so a gate on it must report which "
                           + "template hit the wall.")
        }
    }

    func testEveryRoutineActionReportsDistinctly() {
        let details = RoutineGate.allCases.map { PaywallTrigger.routine($0).reportingDetail }
        XCTAssertEqual(details, ["new", "play", "edit", "duplicate", "generate"])
        XCTAssertEqual(Set(details.compactMap { $0 }).count, RoutineGate.allCases.count,
                       "Five routine producers previously collapsed into one trigger; they must "
                       + "now be separable.")
    }

    func testTriggersWithoutDetailReportNone() {
        for trigger in [PaywallTrigger.drawYourOwn, .proExercise, .planner, .general] {
            XCTAssertNil(trigger.reportingDetail)
        }
        XCTAssertNil(PaywallTrigger.newExercise(nil).reportingDetail,
                     "A gate that genuinely doesn't know the template reports nothing rather than "
                     + "guessing one.")
    }

    // MARK: - Sheet identity

    func testDetailIsPartOfIdentitySoADifferentIntentRePresents() {
        XCTAssertNotEqual(PaywallTrigger.newExercise(.scales).id,
                          PaywallTrigger.newExercise(.chords).id)
        XCTAssertNotEqual(PaywallTrigger.routine(.play).id, PaywallTrigger.routine(.edit).id)
        XCTAssertEqual(PaywallTrigger.newExercise(nil).id, "new_exercise",
                       "No detail means the bare trigger name, not a trailing separator.")
    }

    // MARK: - The pitch is unchanged

    func testHeadlineIgnoresTheReportingDetail() {
        // The copy sells the capability, not the specific template — "Build your own scales
        // exercises" would be a narrower promise than Pro actually makes.
        XCTAssertEqual(PaywallTrigger.newExercise(.scales).headline,
                       PaywallTrigger.newExercise(nil).headline)
        XCTAssertEqual(PaywallTrigger.routine(.play).headline,
                       PaywallTrigger.routine(.generate).headline)
    }
}
