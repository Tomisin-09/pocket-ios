import Foundation

/// The pure decision of whether an event may be emitted at all (ADR 0120). Kept free of
/// `UserDefaults`, SwiftUI and any SDK so the rule that carries the app's privacy promise is
/// exhaustively unit-testable — the same shape as `AccessPolicy` for the entitlement axis.
enum AnalyticsPolicy {

    /// How this region's law lets us arrive at "analytics is on" (ADR 0147).
    ///
    /// This decides **only the default**, never whether an event may be sent. That check stays a
    /// single early return in `Analytics.send`, re-read per event, so withdrawal is immediate under
    /// either model.
    enum ConsentModel: Equatable {
        /// EEA + CH — ePrivacy Art 5(3): explicit consent, default **off**. Exactly ADR 0120.
        case ask
        /// UK + rest of world — DUAA 2025 Sch A1 para 5: inform and allow objection, default **on**.
        case notify
    }

    /// EEA + Switzerland: the regions where ePrivacy Art 5(3) still requires consent (ADR 0147 §1).
    ///
    /// **`GB` is deliberately absent.** The UK is not in the EEA, so it falls through to `.notify`
    /// with no special case — adding a `GB` branch would imply this set contains it, which is the
    /// actual mistake. `CH` *is* present: it sits outside ePrivacy, but the inclusion is cheap and
    /// conservative, and Switzerland is routinely handled alongside the EEA.
    private static let askRegions: Set<String> = [
        // 27 EU member states
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        // EEA non-EU
        "IS", "LI", "NO",
        // Conservative addition
        "CH"
    ]

    /// Which consent model applies, from an ISO 3166-1 alpha-2 region code.
    ///
    /// `nil` — an unknown location — takes the **stricter** path. That is the only safe direction
    /// for this default to fail in.
    ///
    /// Callers pass `Locale.current.region?.identifier`. That is a good-faith, conventional signal,
    /// not a location claim: it is unverified, nothing is sent about it, and a player who travels is
    /// not tracked. StoreKit storefront is a possible later refinement if a reason ever appears.
    static func consentModel(regionCode: String?) -> ConsentModel {
        guard let regionCode else { return .ask }
        return askRegions.contains(regionCode.uppercased()) ? .ask : .notify
    }

    /// Whether this event may be emitted at all.
    ///
    /// **Unchanged by ADR 0147 in signature and behaviour** — deliberately. `consentGranted` now
    /// means "enabled, however that value arrived": an explicit tap under `.ask`, or the seeded
    /// regional default under `.notify` that the player has not objected to. Region never reaches
    /// this function, because a wrong default must still be overridable by one toggle and a gate
    /// that consulted region could not be.
    ///
    /// Suppressed outright under UI test and in Xcode previews.
    ///
    /// Why a default of "off" was ever required, and still is inside the EEA: ePrivacy / PECR
    /// Art 5(3) governs storing or accessing information on a device *irrespective of whether that
    /// information is personal*, and product analytics never qualifies for the "strictly necessary"
    /// exemption. (Aptabase's irreversible anonymisation does take it outside GDPR proper — but
    /// Art 5(3) is the stricter test, which is why anonymity was never the unlock. See ADR 0120 §2.)
    static func shouldEmit(consentGranted: Bool,
                           isUITesting: Bool,
                           isPreview: Bool) -> Bool {
        guard consentGranted else { return false }
        guard !isUITesting, !isPreview else { return false }
        return true
    }
}

/// The single dispatcher every call site talks to. Mirrors the `haptic(_:)` seam in
/// `Pocket/Features/Waveform/Haptics.swift`: a main-actor entry point that reads `AppSettings`
/// itself, so no view has to plumb anything through the environment. (Environment plumbing is
/// actively the wrong tool here — a modifier applied inside a `body` is invisible to the view that
/// applied it, the trap that silently broke the first cut of `RowDeletionCoordinator`.)
///
/// The consent gate lives here as **one early return**, not as a guard repeated at every call site.
/// It is evaluated per-send rather than at install time, so withdrawing consent in Settings takes
/// effect on the very next event with no relaunch.
@MainActor
enum Analytics {

    private static var sink: AnalyticsSink = NoOpSink()

    /// Overridable for tests; production reads the real setting.
    static var consentGranted: () -> Bool = { AppSettings.analyticsEnabled }

    /// Install the real sink. Called once from `PocketApp`. Constructing a sink must **not** start
    /// an SDK — `AptabaseSink` initialises lazily on its first delivered event, which by
    /// construction can only happen after consent.
    static func install(_ newSink: AnalyticsSink) {
        sink = newSink
    }

    /// Emit an event, if policy allows.
    ///
    /// Call this only from user-action closures. Several events fire at `commitAndStart()`, which is
    /// the moment the audio engine starts; this codebase has already taken a device-only `SIGTRAP`
    /// from a non-`@Sendable` closure on that path, so nothing here may be reached from a render
    /// callback or a detached task.
    static func send(_ event: AnalyticsEvent) {
        guard AnalyticsPolicy.shouldEmit(consentGranted: consentGranted(),
                                         isUITesting: isUITesting,
                                         isPreview: isPreview) else { return }
        sink.send(event)
    }

    /// The house UI-test escape hatch, now `UITestRuntime.isActive` (ADR 0146 pass 2). A UI-test run
    /// must never reach the network or pollute the dashboard.
    private static var isUITesting: Bool { UITestRuntime.isActive }

    /// The existing preview-safety idiom (`LoopRunModel`, `TunerView`, and two others).
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Test seam

    /// Restore the default sink and consent source. Tests only.
    static func resetForTesting(sink newSink: AnalyticsSink = NoOpSink(),
                                consent: @escaping () -> Bool = { false }) {
        sink = newSink
        consentGranted = consent
    }
}
