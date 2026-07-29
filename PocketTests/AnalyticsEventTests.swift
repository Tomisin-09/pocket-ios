import XCTest
@testable import Pocket

/// The closed analytics vocabulary (ADR 0120) — event names, payload shape and the buckets.
///
/// **Why the names are pinned:** an emitted event name is a *wire format*. Renaming a Swift case
/// costs nothing, but changing the string breaks continuity in the dashboard permanently — there is
/// no way to stitch an old and a new series together after the fact. These assertions exist to make
/// that change loud rather than silent.
///
/// `AnalyticsEvent` has associated values so it cannot be `CaseIterable`; `everyEvent` stands in for
/// exhaustiveness, and `testVocabularyIsComplete` fails when an event is added without being pinned
/// here — which is the point. Adding an event must be a deliberate act.
final class AnalyticsEventTests: XCTestCase {

    /// One of every case in the vocabulary.
    private let everyEvent: [AnalyticsEvent] = [
        .practiceStarted(kind: .exercise, source: .standalone, sinceInstall: .day1),
        .practiceFinished(kind: .loop, ending: .natural),
        .songImported(count: 3, failed: 1),
        .toolOpened(tool: .tuner),
        .loopCreated,
        .exerciseCreated(template: .scales, instrument: .guitar),
        .exerciseAuthoringAbandoned(template: .chords),
        .routineCreated(items: 5, generated: false),
        .paywallShown(trigger: .newExercise(.scales)),
        .paywallDismissed(trigger: .routine(.play), purchased: true),
        .purchaseCompleted(product: .annual, trial: true),
        .restoreCompleted(restored: false),
        .micPermission(outcome: .granted)
    ]

    // MARK: - Wire format

    func testVocabularyIsComplete() {
        XCTAssertEqual(everyEvent.count, 13,
                       "The vocabulary changed. Pin the new event's name and payload here, and "
                       + "check it against the 20k/month free tier before shipping it.")
    }

    func testEventNamesAreFrozen() {
        XCTAssertEqual(everyEvent.map(\.name),
                       ["practice_started",
                        "practice_finished",
                        "song_imported",
                        "tool_opened",
                        "loop_created",
                        "exercise_created",
                        "exercise_authoring_abandoned",
                        "routine_created",
                        "paywall_shown",
                        "paywall_dismissed",
                        "purchase_completed",
                        "restore_completed",
                        "mic_permission"],
                       "An event name changed. This breaks the dashboard series permanently — "
                       + "rename the Swift case instead.")
    }

    func testEventNamesAreUnique() {
        XCTAssertEqual(Set(everyEvent.map(\.name)).count, everyEvent.count,
                       "Two events share a wire name; their data would be silently merged.")
    }

    func testPayloadKeysAreFrozen() {
        let keys = everyEvent.map { Set($0.payload.keys).sorted() }
        XCTAssertEqual(keys, [
            ["kind", "since_install", "source"],
            ["ending", "kind"],
            ["count", "failed"],
            ["tool"],
            [],
            ["instrument", "template"],
            ["template"],
            ["generated", "items"],
            ["detail", "trigger"],
            ["detail", "purchased", "trigger"],
            ["product", "trial"],
            ["restored"],
            ["outcome"]
        ], "A payload key changed — the dashboard breakdown built on it will go empty.")
    }

    // MARK: - The privacy guarantee

    func testTextValuesAreOnlyEnumRawValues() {
        // Every string the vocabulary can emit, gathered from the enums it draws on. If a payload
        // ever carries text outside this set, something caller-supplied has leaked in.
        var permitted = Set<String>(["none"])   // the explicit "no template chosen" sentinel
        permitted.formUnion(PracticeKind.allCases.map(\.rawValue))
        permitted.formUnion(PracticeSource.allCases.map(\.rawValue))
        permitted.formUnion(RunEnding.allCases.map(\.rawValue))
        permitted.formUnion(LatencyBucket.allCases.map(\.rawValue))
        permitted.formUnion(Tool.allCases.map(\.rawValue))
        permitted.formUnion(SubscriptionProduct.allCases.map(\.rawValue))
        permitted.formUnion(MicOutcome.allCases.map(\.rawValue))
        permitted.formUnion(ExerciseTemplate.allCases.map(\.rawValue))
        permitted.formUnion(Instrument.allCases.map(\.rawValue))
        // `PaywallTrigger` gained associated values (ADR 0120) so it is no longer `CaseIterable`;
        // its reporting axes are enumerated explicitly instead.
        permitted.formUnion(["draw_your_own", "new_exercise", "pro_exercise",
                             "planner", "routine", "general"])
        permitted.formUnion(RoutineGate.allCases.map(\.rawValue))

        for event in everyEvent {
            for (key, value) in event.payload {
                guard case let .text(text) = value else { continue }
                XCTAssertTrue(permitted.contains(text),
                              "\(event.name).\(key) emitted '\(text)', which is not an enum raw "
                              + "value. User-authored text must never reach the payload.")
            }
        }
    }

    func testAbandonedWithoutATemplateReportsNoneRatherThanDroppingTheKey() {
        let event = AnalyticsEvent.exerciseAuthoringAbandoned(template: nil)
        XCTAssertEqual(event.payload["template"], .text("none"),
                       "Abandoning before choosing a template is its own signal and must be "
                       + "distinguishable from a missing key.")
    }

    func testCountsStayNumericSoTheyCanBeAggregated() {
        let event = AnalyticsEvent.songImported(count: 4, failed: 2)
        XCTAssertEqual(event.payload["count"], .number(4))
        XCTAssertEqual(event.payload["failed"], .number(2))
    }

    // MARK: - LatencyBucket

    func testInstallAgeBucketBoundaries() {
        let day: TimeInterval = 86_400
        XCTAssertEqual(LatencyBucket(installAge: 0), .day1)
        XCTAssertEqual(LatencyBucket(installAge: day - 1), .day1)
        XCTAssertEqual(LatencyBucket(installAge: day), .week1, "Exactly 24h is no longer day one.")
        XCTAssertEqual(LatencyBucket(installAge: 6 * day), .week1)
        XCTAssertEqual(LatencyBucket(installAge: 7 * day), .month1)
        XCTAssertEqual(LatencyBucket(installAge: 29 * day), .month1)
        XCTAssertEqual(LatencyBucket(installAge: 30 * day), .later)
        XCTAssertEqual(LatencyBucket(installAge: 365 * day), .later)
    }

    func testNegativeInstallAgeResolvesToDayOneRatherThanTrapping() {
        XCTAssertEqual(LatencyBucket(installAge: -5_000), .day1,
                       "A clock moved backwards must not crash telemetry.")
    }
}
