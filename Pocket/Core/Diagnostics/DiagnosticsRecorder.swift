import Foundation
import MetricKit
import Observation

/// The **side-effecting half** of diagnostics (ADR 0183): it subscribes to MetricKit, reduces what
/// the OS delivers to `DiagnosticEvent`s, and keeps them on disk. Every *decision* — which payloads
/// count, how many are kept, how they read — is delegated to `DiagnosticSummary`, which is pure and
/// unit-tested; this type only does the things a test can't.
///
/// **`usesSystemMetrics` is a flag, never a stored `MXMetricManager`.** Straight from
/// `TrialReminder`'s doc comment, which learned it the hard way: holding a non-`Sendable` OS
/// singleton as a property of a `@MainActor` type puts it in the actor's isolation region and
/// compiles clean locally while failing CI's stricter Xcode 16 with *"sending risks causing data
/// races"*. Storing a `Bool` and reaching for `.shared` at the point of use removes the crossing
/// rather than annotating around it.
///
/// ⚠ **`MXMetricManager` holds its subscribers weakly.** This object must be owned for the app's
/// lifetime — it is a `@State` at the `PocketApp` root beside `store` and `trialReminder` — or the
/// subscription is silently dropped and the screen stays empty forever with nothing to notice.
@MainActor
@Observable
final class DiagnosticsRecorder {

    /// What the OS has reported, newest first, already capped by `DiagnosticSummary.keeping`.
    private(set) var events: [DiagnosticEvent]

    /// The bounded line for a support message, or `nil` when there is nothing to report. Read by
    /// `AboutSection` when the player has opted in — the *only* route these ever take off the device.
    var supportLine: String? { DiagnosticSummary.line(for: events) }

    /// Whether this instance talks to MetricKit at all. `false` in previews and unit tests.
    private let usesSystemMetrics: Bool

    /// The `NSObject` MetricKit actually calls. Held **strongly** here, because the manager does not.
    private var subscriber: DiagnosticsSubscriber?

    /// Injected so a test drives the whole persistence path against a throwaway container rather
    /// than the test host's own Application Support.
    private let files: FileManager

    /// - Parameters:
    ///   - usesSystemMetrics: `false` in previews and tests, where subscribing would reach for a real
    ///     `MXMetricManager` and no payload could ever arrive anyway.
    ///   - seeded: preview and test fixtures, in place of whatever is on disk.
    ///   - files: the container to read and write in.
    init(usesSystemMetrics: Bool = true, seeded: [DiagnosticEvent]? = nil,
         files: FileManager = .default) {
        self.usesSystemMetrics = usesSystemMetrics
        self.files = files
        self.events = seeded.map { DiagnosticSummary.keeping($0) } ?? DiagnosticsStore.load(files)
        guard usesSystemMetrics else { return }
        let subscriber = DiagnosticsSubscriber { [weak self] events in
            Task { @MainActor in self?.record(events) }
        }
        self.subscriber = subscriber
        MXMetricManager.shared.add(subscriber)
    }

    /// Merge newly delivered events in and persist the result.
    ///
    /// Internal rather than private so a test can drive the whole write path without MetricKit —
    /// which is the only way any of this is exercised before a real device crashes.
    func record(_ incoming: [DiagnosticEvent]) {
        guard !incoming.isEmpty else { return }
        events = DiagnosticsStore.save(incoming + events, files)
    }

    /// Forget everything reported so far, on disk as well as on screen.
    func clear() {
        DiagnosticsStore.clear(files)
        events = []
    }
}

/// The `NSObject` MetricKit talks to, kept apart from `DiagnosticsRecorder` for one reason: an
/// `MXDiagnosticPayload` is **not `Sendable`**, so it cannot cross to the main actor. This runs
/// `nonisolated` on whatever queue the OS delivers on, reduces each payload to plain values *there*,
/// and hands the main actor an array of `Sendable` structs.
///
/// Reducing on the delivery queue is also the cheaper order: the call-stack trees are the large part
/// of a payload and nothing downstream wants them.
private final class DiagnosticsSubscriber: NSObject, MXMetricManagerSubscriber {

    private let onEvents: @Sendable ([DiagnosticEvent]) -> Void

    init(onEvents: @escaping @Sendable ([DiagnosticEvent]) -> Void) {
        self.onEvents = onEvents
    }

    /// Required by `MXMetricManagerSubscriber`, and deliberately empty. The daily *metrics* payload
    /// is battery, launch times and network transfer — performance telemetry about a player's device
    /// that we neither asked for nor have any consented route to send (ADR 0120, ADR 0147). Only the
    /// diagnostics callback below is implemented.
    func didReceive(_ payloads: [MXMetricPayload]) {}

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let events = payloads.flatMap(DiagnosticEvent.events(from:))
        guard !events.isEmpty else { return }
        onEvents(events)
    }
}

extension DiagnosticEvent {

    /// Reduce one MetricKit payload to the events worth keeping.
    ///
    /// **Crashes and hangs only.** The payload also carries `cpuExceptionDiagnostics` and
    /// `diskWriteExceptionDiagnostics`; both are performance advisories about a build, neither is
    /// something a player noticed or a support message can act on, and each one that appeared would
    /// push a real crash off a five-row screen. Dropping them is the retention budget being spent on
    /// what it was raised for.
    ///
    /// `appLaunchDiagnostics` is dropped for the same reason — a slow launch is not a fault.
    static func events(from payload: MXDiagnosticPayload) -> [DiagnosticEvent] {
        let date = payload.timeStampEnd
        let crashes = (payload.crashDiagnostics ?? []).map { crash in
            DiagnosticEvent(
                kind: .crash,
                date: date,
                detail: DiagnosticSummary.crashDetail(exceptionType: crash.exceptionType?.intValue,
                                                      signal: crash.signal?.intValue),
                appBuild: crash.applicationVersion,
                systemVersion: DiagnosticSummary.shortOSVersion(crash.metaData.osVersion)
            )
        }
        let hangs = (payload.hangDiagnostics ?? []).map { hang in
            DiagnosticEvent(
                kind: .hang,
                date: date,
                detail: DiagnosticSummary.hangDetail(
                    seconds: hang.hangDuration.converted(to: .seconds).value),
                appBuild: hang.applicationVersion,
                systemVersion: DiagnosticSummary.shortOSVersion(hang.metaData.osVersion)
            )
        }
        return crashes + hangs
    }
}
