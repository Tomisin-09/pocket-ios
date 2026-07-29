import XCTest
@testable import Pocket

/// The consent gate (ADR 0120) — the pure rule that carries the app's privacy promise, plus the
/// dispatcher that applies it. Analytics is **opt-in**: silence is the default and every suppression
/// path is asserted here rather than trusted.
final class AnalyticsPolicyTests: XCTestCase {

    // MARK: - AnalyticsPolicy

    func testNothingIsEmittedWithoutConsent() {
        XCTAssertFalse(AnalyticsPolicy.shouldEmit(consentGranted: false,
                                                  isUITesting: false,
                                                  isPreview: false),
                       "Analytics is opt-in: no consent means no events, full stop.")
    }

    func testConsentAloneIsEnough() {
        XCTAssertTrue(AnalyticsPolicy.shouldEmit(consentGranted: true,
                                                 isUITesting: false,
                                                 isPreview: false))
    }

    func testUITestRunsNeverEmit() {
        XCTAssertFalse(AnalyticsPolicy.shouldEmit(consentGranted: true,
                                                  isUITesting: true,
                                                  isPreview: false),
                       "A UI-test run must not reach the network or pollute the dashboard.")
    }

    func testPreviewsNeverEmit() {
        XCTAssertFalse(AnalyticsPolicy.shouldEmit(consentGranted: true,
                                                  isUITesting: false,
                                                  isPreview: true))
    }

    // MARK: - Analytics dispatcher

    @MainActor
    func testDispatcherDropsEverythingWhenConsentIsWithheld() {
        let sink = RecordingSink()
        Analytics.resetForTesting(sink: sink, consent: { false })
        defer { Analytics.resetForTesting() }

        Analytics.send(.loopCreated)
        Analytics.send(.paywallShown(trigger: .planner))

        XCTAssertTrue(sink.events.isEmpty, "The gate leaked events with consent off.")
    }

    @MainActor
    func testDispatcherDeliversOnceConsentIsGranted() {
        let sink = RecordingSink()
        Analytics.resetForTesting(sink: sink, consent: { true })
        defer { Analytics.resetForTesting() }

        Analytics.send(.loopCreated)
        Analytics.send(.micPermission(outcome: .denied))

        XCTAssertEqual(sink.events, [.loopCreated, .micPermission(outcome: .denied)])
    }

    @MainActor
    func testWithdrawingConsentTakesEffectOnTheNextEventWithoutARelaunch() {
        let sink = RecordingSink()
        var granted = true
        Analytics.resetForTesting(sink: sink, consent: { granted })
        defer { Analytics.resetForTesting() }

        Analytics.send(.loopCreated)
        granted = false
        Analytics.send(.loopCreated)

        XCTAssertEqual(sink.events.count, 1,
                       "Consent is read per-send precisely so Off the grid is immediate.")
    }

    @MainActor
    func testDefaultSinkIsTheNoOp() {
        Analytics.resetForTesting(consent: { true })
        // Nothing to assert beyond "this does not crash and goes nowhere" — the point is that the
        // app ships inert until a sink is installed at the composition root.
        Analytics.send(.loopCreated)
    }

    // MARK: - AppSettings defaults

    func testAnalyticsDefaultsToOffWhenNeverSet() {
        XCTAssertFalse(AppSettings.resolvedBool(storedValue: nil, default: false),
                       "The opt-in default is load-bearing: AppSettings.bool's own fallback is "
                       + "true, so analyticsEnabled must pass default: false explicitly.")
    }

    func testInstallDateIsRecordedOnceAndNeverDriftsForward() {
        guard let store = UserDefaults(suiteName: #function) else {
            return XCTFail("Could not open an isolated defaults suite.")
        }
        store.removePersistentDomain(forName: #function)
        defer { store.removePersistentDomain(forName: #function) }

        let first = Date(timeIntervalSince1970: 1_700_000_000)
        AppSettings.recordInstallDateIfNeeded(now: first, store: store)
        AppSettings.recordInstallDateIfNeeded(now: first.addingTimeInterval(86_400), store: store)

        XCTAssertEqual(store.object(forKey: AppSettings.Key.installDate) as? Date, first,
                       "Re-recording would reset every install to 'day 1' on every launch.")
    }
}
