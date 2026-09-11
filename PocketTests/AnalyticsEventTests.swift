import XCTest
@testable import Pocket

/// The closed analytics vocabulary (ADR 0120) — event names, payload shape and the buckets.
///
/// **Why the names are pinned:** an emitted event name is a *wire format*. Renaming a Swift case
/// costs nothing, but changing the string breaks continuity in the dashboard permanently — there is
/// no way to stitch an old and a new series together after the fact. These assertions exist to make
/// that change loud rather than silent.
///
/// `AnalyticsEvent` has associated values so it cannot be `CaseIterable`; `AnalyticsEvent.everyEvent`
/// stands in for exhaustiveness. **It now lives beside the enum**, which is the whole of the fix this
/// file asked for twice and finally got: the list drifted three times while it was a `private let`
/// here, because adding a case and adding its sample were two edits in two targets and nothing
/// connected them. `routine_received` sat unpinned through ADR 0188 (enum at 16, this file at 13);
/// `exercise_received` (0209) arrived unlisted and was still unlisted when 0210 added
/// `folder_created`. Every assertion below was green the entire time.
///
/// **What that does and does not buy.** The count below still compares a list against a number
/// written here, so a case added to the enum and never sampled is still not caught by a compiler —
/// but the two are now three lines apart in one file rather than in separate targets, which is the
/// difference between a miss you see and a miss you count for.
///
/// A **fourth** instance of the same drift was found while fixing the third, in this very file: the
/// permitted-text list enumerated the paywall trigger's reporting names as six string literals
/// against nine the type returned, and stayed green because the samples only ever exercised two
/// triggers. The trigger went with the paywall (ADR 0237); the lesson stays — `permittedText` reads
/// every list from its enum and retypes none.
final class AnalyticsEventTests: XCTestCase {

    // MARK: - Wire format

    func testVocabularyIsComplete() {
        XCTAssertEqual(AnalyticsEvent.everyEvent.count, 15,
                       "The vocabulary changed. Pin the new event's name and payload here, and "
                       + "check it against the 20k/month free tier before shipping it.")
    }

    func testEventNamesAreFrozen() {
        XCTAssertEqual(AnalyticsEvent.everyEvent.map(\.name),
                       ["practice_started",
                        "practice_completed",
                        "song_imported",
                        "tool_opened",
                        "loop_created",
                        "exercise_created",
                        "exercise_authoring_abandoned",
                        "folder_created",
                        "routine_created",
                        "routine_received",
                        "exercise_received",
                        "archive_exported",
                        "archive_restored",
                        "mic_permission",
                        "review_requested"],
                       "An event name changed. This breaks the dashboard series permanently — "
                       + "rename the Swift case instead.")
    }

    /// ADR 0237 D8: the four monetization events left with the paywall, and their names stay retired.
    /// A new event wearing one would land on the old series in the dashboard and read as continuous
    /// with it — the same permanent break `testEventNamesAreFrozen` guards against, arriving from the
    /// other side.
    func testRetiredNamesAreNeverReused() {
        let retired: Set<String> = ["paywall_shown", "paywall_dismissed",
                                    "purchase_completed", "restore_completed"]
        XCTAssertTrue(retired.isDisjoint(with: AnalyticsEvent.everyEvent.map(\.name)),
                      "A retired event name is back in the vocabulary. Pick a new name.")
    }

    func testEventNamesAreUnique() {
        XCTAssertEqual(Set(AnalyticsEvent.everyEvent.map(\.name)).count, AnalyticsEvent.everyEvent.count,
                       "Two events share a wire name; their data would be silently merged.")
    }

    func testPayloadKeysAreFrozen() {
        let keys = AnalyticsEvent.everyEvent.map { Set($0.payload.keys).sorted() }
        XCTAssertEqual(keys, [
            ["kind", "since_install", "source"],
            ["kind"],
            ["count", "failed"],
            ["tool"],
            [],
            ["instrument", "template"],
            ["template"],
            ["depth"],
            ["generated", "items"],
            ["items", "orphaned_blocks"],
            ["template"],
            ["includes_take_audio", "takes"],
            ["already_present", "items_added", "take_files"],
            ["outcome"],
            ["trigger"]
        ], "A payload key changed — the dashboard breakdown built on it will go empty.")
    }

    // MARK: - The privacy guarantee

    /// Every string the vocabulary is allowed to emit, gathered from the enums it draws on — each read
    /// from the enum's own list, never retyped here.
    private var permittedText: Set<String> {
        var permitted = Set<String>(["none"])   // the explicit "no template chosen" sentinel
        permitted.formUnion(PracticeKind.allCases.map(\.rawValue))
        permitted.formUnion(PracticeSource.allCases.map(\.rawValue))
        permitted.formUnion(LatencyBucket.allCases.map(\.rawValue))
        permitted.formUnion(Tool.allCases.map(\.rawValue))
        permitted.formUnion(MicOutcome.allCases.map(\.rawValue))
        permitted.formUnion(ReviewTrigger.allCases.map(\.rawValue))
        permitted.formUnion(ExerciseTemplate.allCases.map(\.rawValue))
        permitted.formUnion(Instrument.allCases.map(\.rawValue))
        return permitted
    }

    func testTextValuesAreOnlyEnumRawValues() {
        assertOnlyPermittedText(in: AnalyticsEvent.everyEvent)
    }

    private func assertOnlyPermittedText(in events: [AnalyticsEvent],
                                         file: StaticString = #filePath, line: UInt = #line) {
        let permitted = permittedText
        for event in events {
            for (key, value) in event.payload {
                guard case let .text(text) = value else { continue }
                XCTAssertTrue(permitted.contains(text),
                              "\(event.name).\(key) emitted '\(text)', which is not an enum raw "
                              + "value. User-authored text must never reach the payload.",
                              file: file, line: line)
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
