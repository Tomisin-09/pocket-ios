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

    // MARK: - Which consent model applies (ADR 0147)

    func testUKAndRestOfWorldGetInformAndObject() {
        for region in ["GB", "US", "JP", "AU", "CA", "BR", "IN"] {
            XCTAssertEqual(AnalyticsPolicy.consentModel(regionCode: region), .notify,
                           "\(region) is outside the EEA, so DUAA-style inform-and-object applies. "
                           + "GB especially: the UK is not in the EEA and needs no special case.")
        }
    }

    func testEEAAndSwitzerlandStillRequireConsent() {
        for region in ["DE", "FR", "IE", "IT", "ES", "NL", "NO", "IS", "LI", "CH"] {
            XCTAssertEqual(AnalyticsPolicy.consentModel(regionCode: region), .ask,
                           "\(region) is EEA (or CH, included conservatively), where ePrivacy "
                           + "Art 5(3) still requires consent — ADR 0147 leaves it exactly as 0120.")
        }
    }

    func testAnUnknownRegionTakesTheStricterPath() {
        XCTAssertEqual(AnalyticsPolicy.consentModel(regionCode: nil), .ask,
                       "A nil region must fail safe. Defaulting an unknown location to .notify "
                       + "would turn analytics on for someone we cannot place.")
    }

    func testRegionMatchingIsCaseInsensitive() {
        XCTAssertEqual(AnalyticsPolicy.consentModel(regionCode: "de"), .ask,
                       "Locale region identifiers are conventionally uppercase, but a lowercase "
                       + "value must not silently downgrade an EEA user to inform-and-object.")
    }

    // MARK: - Seeding the regional default (ADR 0147 §3)

    func testSeedingWritesTheRegionalDefault() {
        withCleanStore(#function) { store in
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .notify, store: store)
            XCTAssertEqual(store.object(forKey: AppSettings.Key.analyticsEnabled) as? Bool, true)
        }
        withCleanStore(#function + "ask") { store in
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .ask, store: store)
            XCTAssertEqual(store.object(forKey: AppSettings.Key.analyticsEnabled) as? Bool, false)
        }
    }

    /// **The case that must never regress.** Somebody who tapped "No thanks" under ADR 0120 has the
    /// key present and `false`; a seed that overwrote it would silently re-enrol them.
    func testSeedingNeverOverwritesAnExplicitDecline() {
        withCleanStore(#function) { store in
            store.set(false, forKey: AppSettings.Key.analyticsEnabled)
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .notify, store: store)
            XCTAssertEqual(store.object(forKey: AppSettings.Key.analyticsEnabled) as? Bool, false,
                           "An explicit decline must survive the move to inform-and-object.")
        }
    }

    func testSeedingNeverOverwritesAnExplicitOptIn() {
        withCleanStore(#function) { store in
            store.set(true, forKey: AppSettings.Key.analyticsEnabled)
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .ask, store: store)
            XCTAssertEqual(store.object(forKey: AppSettings.Key.analyticsEnabled) as? Bool, true,
                           "Seeding must no-op in both directions, not just the convenient one.")
        }
    }

    func testSeedingIsIdempotent() {
        withCleanStore(#function) { store in
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .notify, store: store)
            store.set(false, forKey: AppSettings.Key.analyticsEnabled)
            // A later launch must not undo a withdrawal made after the first one.
            AppSettings.seedAnalyticsDefaultIfNeeded(model: .notify, store: store)
            XCTAssertEqual(store.object(forKey: AppSettings.Key.analyticsEnabled) as? Bool, false,
                           "Seeding runs on every launch; only the first may write.")
        }
    }

    /// Run `body` against an isolated defaults suite, cleared before and after.
    private func withCleanStore(_ name: String, _ body: (UserDefaults) -> Void) {
        guard let store = UserDefaults(suiteName: name) else {
            return XCTFail("Could not open an isolated defaults suite.")
        }
        store.removePersistentDomain(forName: name)
        defer { store.removePersistentDomain(forName: name) }
        body(store)
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
