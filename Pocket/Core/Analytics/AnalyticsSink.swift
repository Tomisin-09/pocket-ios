import Foundation

/// Where an `AnalyticsEvent` goes once the consent gate has let it through (ADR 0120).
///
/// **`@MainActor`, deliberately not `Sendable`.** The Aptabase SDK is a non-final `NSObject`
/// subclass whose client and dispatcher hold unguarded mutable state, and whose first touch of
/// `.shared` reads `UIDevice.current`. It compiles in Swift 5 language mode, so the compiler will
/// not police our use of it — confining every sink to the main actor is what keeps that safe under
/// this target's Swift 6 strict concurrency. Events are only ever emitted from user-action
/// closures, never from an audio render context or a detached task.
@MainActor
protocol AnalyticsSink {
    func send(_ event: AnalyticsEvent)
}

/// Discards everything. The default sink, and the one the app ships with until an
/// `AnalyticsSink`-conforming vendor is installed at the composition root — which is what lets the
/// call sites land and be reviewed independently of any SDK.
struct NoOpSink: AnalyticsSink {
    func send(_ event: AnalyticsEvent) {}
}

/// Keeps every event it is given, for tests. Not compiled out of the app target (it costs nothing
/// and `@testable import` needs it visible), but never installed outside a test.
final class RecordingSink: AnalyticsSink {
    private(set) var events: [AnalyticsEvent] = []

    func send(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
