import XCTest
@testable import Pocket

/// The Aptabase sink's configuration guard and property mapping (ADR 0120).
///
/// The sink is the one component in the app that can send anything off-device, so the rule that
/// keeps it inert until it is properly configured is pinned here rather than trusted. An unresolved
/// `$(APTABASE_APP_KEY)` reaching the SDK would otherwise surface only as a silent stream of
/// dropped events against an app key that doesn't exist.
final class AptabaseSinkTests: XCTestCase {

    // MARK: - Configuration guard

    func testMissingOrUnconfiguredKeysLeaveTheSinkInert() {
        XCTAssertNil(AptabaseSink.resolvedKey(raw: nil), "No Info.plist entry at all.")
        XCTAssertNil(AptabaseSink.resolvedKey(raw: ""), "The shipped default, before an app exists.")
        XCTAssertNil(AptabaseSink.resolvedKey(raw: "   "))
        XCTAssertNil(AptabaseSink.resolvedKey(raw: "$(APTABASE_APP_KEY)"),
                     "An unresolved build setting must never be handed to the SDK as a key.")
    }

    func testAConfiguredKeyResolves() {
        XCTAssertEqual(AptabaseSink.resolvedKey(raw: "A-EU-1234567890"), "A-EU-1234567890")
        XCTAssertEqual(AptabaseSink.resolvedKey(raw: "  A-EU-1234567890  "), "A-EU-1234567890",
                       "A key pasted with stray whitespace should still work.")
    }

    func testTheBundledKeyIsPresentAndEURegion() {
        guard let key = AptabaseSink.bundledAppKey else {
            return XCTFail("APTABASE_APP_KEY is not resolving from the Info.plist. Analytics would "
                           + "be silently inert for everyone who opted in.")
        }
        XCTAssertTrue(key.hasPrefix("A-EU-"),
                      "The SDK derives its ingest host from the region segment of the key, so a "
                      + "non-EU key would send EU users' events to the wrong region — a data "
                      + "residency claim we make in the privacy policy (ADR 0120).")
    }

    // MARK: - Property mapping

    func testNumbersStayNumericAndTextStaysText() {
        let props = AptabaseSink.props(for: .songImported(count: 4, failed: 1))
        XCTAssertEqual(props["count"] as? Int, 4, "Counts must stay Int so the dashboard can sum.")
        XCTAssertEqual(props["failed"] as? Int, 1)

        let tool = AptabaseSink.props(for: .toolOpened(tool: .tuner))
        XCTAssertEqual(tool["tool"] as? String, "tuner")

        let restore = AptabaseSink.props(for: .restoreCompleted(restored: true))
        XCTAssertEqual(restore["restored"] as? Bool, true)
    }

    func testEveryPayloadKeySurvivesTheMapping() {
        let event = AnalyticsEvent.paywallDismissed(trigger: .newExercise(.scales), purchased: false)
        XCTAssertEqual(Set(AptabaseSink.props(for: event).keys), Set(event.payload.keys),
                       "A dropped key is a breakdown that silently goes empty.")
    }

    func testAnEventWithNoPropertiesMapsToAnEmptyDictionary() {
        XCTAssertTrue(AptabaseSink.props(for: .loopCreated).isEmpty)
    }
}
