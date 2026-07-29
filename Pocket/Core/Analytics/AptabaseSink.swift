import Aptabase
import Foundation

/// Delivers events to **Aptabase** (ADR 0120) — the app's only third-party service and the only
/// component that can send anything off-device.
///
/// Everything here is `@MainActor` by way of `AnalyticsSink`, deliberately: the SDK is a non-final
/// `NSObject` subclass whose client and dispatcher hold unguarded mutable state, and whose first
/// touch of `.shared` reads `UIDevice.current`. It builds in Swift 5 language mode, so the compiler
/// will not police our use of it — main-actor confinement is what makes it safe here. `trackEvent`
/// itself is non-blocking (the SDK queues and flushes on its own timer), which is why it is safe to
/// call from `commitAndStart()` at the moment audio starts.
///
/// **Started lazily, never at launch.** `initialize` registers `NotificationCenter` observers and
/// stands up a flush timer, and the SDK offers no way to switch itself off afterwards. Deferring it
/// to the first *delivered* event means it can only ever start after consent — a player who declines
/// never has an Aptabase client at all, rather than one sitting idle.
///
/// Known limitation worth remembering: the SDK's queue is **in-memory only**. It flushes every 60s
/// and once on backgrounding, and re-enqueues on failure, but events are lost if the app is killed
/// while offline. Since Red Moon is built to work with no network, offline sessions are therefore
/// under-counted. The upside is that nothing is ever written to disk.
@MainActor
final class AptabaseSink: AnalyticsSink {

    /// The Info.plist key carrying the write-only ingest key, resolved from `APTABASE_APP_KEY`.
    private nonisolated static let appKeyInfoKey = "AptabaseAppKey"

    private let appKey: String?
    private var started = false

    /// `appKey` is injectable for tests; production reads the bundled value.
    init(appKey: String? = AptabaseSink.bundledAppKey) {
        self.appKey = appKey
    }

    /// The configured key, or `nil` when absent, empty, or still an unresolved `$(…)` placeholder —
    /// all three mean "no Aptabase app exists yet", and the sink must stay inert rather than
    /// initialise the SDK with rubbish.
    ///
    /// This and the two members after it are `nonisolated`: pure functions over their inputs, plus a
    /// thread-safe `Bundle.main` read. Only the SDK contact in `send` genuinely needs the main-actor
    /// isolation the protocol imposes.
    nonisolated static var bundledAppKey: String? {
        resolvedKey(raw: Bundle.main.object(forInfoDictionaryKey: appKeyInfoKey) as? String)
    }

    /// Pure key resolution, split out so the "inert unless properly configured" rule is
    /// unit-testable — an unresolved `$(APTABASE_APP_KEY)` reaching the SDK would otherwise be
    /// discovered only as a silent stream of dropped events.
    nonisolated static func resolvedKey(raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    func send(_ event: AnalyticsEvent) {
        guard let appKey else { return }
        if !started {
            started = true
            Aptabase.shared.initialize(appKey: appKey)
        }
        Aptabase.shared.trackEvent(event.name, with: Self.props(for: event))
        // Delivery is driven explicitly, because the SDK's own flush timer never starts for us.
        // `initialize` only *registers* an observer for `willEnterForegroundNotification`; it never
        // calls `startPolling()` itself. Since we initialise lazily — on the first delivered event,
        // with the app already foregrounded — that transition never arrives, so without this the
        // queue would sit in memory until the app was backgrounded. (Found on device: consent given,
        // events emitted, dashboard empty until the app was backgrounded.)
        //
        // Flushing per event rather than batching is a deliberate trade at this volume: a handful of
        // events per session, none of them per-beat or per-tap. It also makes delivery prompt enough
        // to debug. `flush()` is non-blocking (it spawns its own Task) and a no-op on an empty queue,
        // and a failed send re-enqueues, so the next event retries it.
        Aptabase.shared.flush()
    }

    /// Map the closed vocabulary onto the SDK's supported property types. Numbers stay numeric so
    /// the dashboard can aggregate them; `.text` only ever carries an enum's raw value.
    nonisolated static func props(for event: AnalyticsEvent) -> [String: Value] {
        event.payload.mapValues { value in
            switch value {
            case let .text(text): return text as Value
            case let .number(number): return number as Value
            case let .flag(flag): return flag as Value
            }
        }
    }
}
