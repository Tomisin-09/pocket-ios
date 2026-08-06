import XCTest
@testable import Pocket

/// `PaywallTrigger`'s reporting axes (ADR 0120, extending ADR 0112).
///
/// The trigger gained associated values so the two gates that already knew *what* was reached for —
/// the template picker and the five routine actions — stop discarding it at the boundary. That
/// detail is the evidence behind every future free-vs-Pro decision, so it is pinned here.
final class PaywallTriggerTests: XCTestCase {

    private let coarse: [PaywallTrigger] = [
        .drawYourOwn, .newExercise(nil), .proExercise, .planner, .routine(.new),
        .home(.practice), .launch, .general
    ]

    func testCoarseTriggerNamesAreFrozenAndUnique() {
        XCTAssertEqual(coarse.map(\.reportingName),
                       ["draw_your_own", "new_exercise", "pro_exercise",
                        "planner", "routine", "home", "launch", "general"],
                       "Trigger names are a wire format — renaming breaks the dashboard series. "
                       + "ADR 0144 added `home` and `launch`; adding is allowed, renaming is not.")
        XCTAssertEqual(Set(coarse.map(\.reportingName)).count, coarse.count)
    }

    // MARK: - ADR 0144's wall

    /// With the whole app Pro, the Home wall is the highest-volume gate there is — so *which* locked
    /// destination was reached for has to survive to reporting, exactly as the five routine actions do.
    func testEveryHomeDestinationReportsDistinctly() {
        let details = HomeGate.allCases.map { PaywallTrigger.home($0).reportingDetail }
        XCTAssertEqual(details, ["practice", "library", "song", "routine"])
        XCTAssertEqual(Set(details.compactMap { $0 }).count, HomeGate.allCases.count)
    }

    /// The launch wall is **not** a `.general` presentation. It comes to the player unprompted, so a
    /// dismissal here means something different from dismissing a wall they walked into, and the two
    /// must be separable in the dashboard.
    func testLaunchWallIsItsOwnTrigger() {
        XCTAssertEqual(PaywallTrigger.launch.reportingName, "launch")
        XCTAssertNotEqual(PaywallTrigger.launch.reportingName, PaywallTrigger.general.reportingName)
        XCTAssertNil(PaywallTrigger.launch.reportingDetail)
    }

    /// Unlike the capability triggers, a Home gate's headline **does** vary by detail: the player just
    /// tapped a specific place, so the paywall names that place.
    func testHomeHeadlinesNameThePlaceAndAreDistinct() {
        let headlines = HomeGate.allCases.map { PaywallTrigger.home($0).headline }
        XCTAssertEqual(Set(headlines).count, headlines.count,
                       "Each locked Home destination names itself.")
        XCTAssertTrue(PaywallTrigger.home(.practice).headline.contains("Practice"))
    }

    /// **The free surface has no trigger at all** (ADR 0144 D2). The Toolkit and the Journal are never
    /// gated, so no `HomeGate` may name one — a case appearing here would mean a paywall had been put
    /// in front of something we promised was free.
    func testTheFreeSurfacesHaveNoGate() {
        let named = HomeGate.allCases.map(\.rawValue)
        XCTAssertFalse(named.contains("toolkit"))
        XCTAssertFalse(named.contains("journal"))
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
        for trigger in [PaywallTrigger.drawYourOwn, .proExercise, .planner, .launch, .general] {
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
