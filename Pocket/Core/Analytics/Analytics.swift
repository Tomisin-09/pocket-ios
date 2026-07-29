import Foundation

/// The pure decision of whether an event may be emitted at all (ADR 0120). Kept free of
/// `UserDefaults`, SwiftUI and any SDK so the rule that carries the app's privacy promise is
/// exhaustively unit-testable — the same shape as `AccessPolicy` for the entitlement axis.
enum AnalyticsPolicy {

    /// Analytics is **opt-in**: it emits only on an explicit, affirmative consent, and is
    /// suppressed outright under UI test and in Xcode previews.
    ///
    /// The consent default is `false` because ePrivacy / PECR Art 5(3) governs storing or accessing
    /// information on a device *irrespective of whether that information is personal*, and product
    /// analytics never qualifies for the "strictly necessary" exemption. (Aptabase's own
    /// irreversible anonymisation does take it outside GDPR proper — but Art 5(3) is the stricter
    /// test here and the one that decides the default.)
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

    /// The house UI-test escape hatch (`StoreManager`, `HomeView+ProfileMoment` and
    /// `RowDeletionCoordinator` read the same flag). A UI-test run must never reach the network or
    /// pollute the dashboard.
    private static var isUITesting: Bool {
        CommandLine.arguments.contains("-uiTesting")
    }

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
