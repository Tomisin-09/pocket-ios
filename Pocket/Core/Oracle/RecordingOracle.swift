import Foundation

/// A conformance that answers from a script instead of a model (ADR 0187 D4, D17).
///
/// Two jobs. It is what previews and unit tests drive the screen with, and it is what **UI tests
/// get instead of a network**: D17 is categorical that no test, unit or UI, may reach the API, and
/// the way that is guaranteed is by installing this at the composition root under
/// `UITestRuntime.isActive` — the same place and the same reasoning as the analytics sink
/// (`PocketApp.swift:30-35`: *"the composition root, and the only place that knows a vendor
/// exists"*).
///
/// It records what it was asked, so a test can assert on the **request** — which is where D6's
/// rules actually live. Asserting that a builder produced a field is one test; asserting that the
/// field survived all the way into the thing that would have been sent is the one that catches a
/// later caller reaching around the builder.
final class RecordingOracle: OracleReading, @unchecked Sendable {

    /// What to answer with. A `model`-sourced reading by default, so a test that wants to exercise
    /// the D12 path can hand it prose that trips the guard and watch the local one come back.
    let response: OracleReadingText
    /// Thrown instead of answering, for the failure path.
    let failure: (any Error)?

    /// Recorded requests, behind a lock because a UI test's app and its assertions are not the
    /// same thread. `withLock` rather than a bare `lock()`/`unlock()` pair: the unscoped form is
    /// unavailable from an async context under Swift 6, which is exactly the context `reading(for:)`
    /// runs in.
    private let recorded = Recorded()

    private final class Recorded: @unchecked Sendable {
        private let lock = NSLock()
        private var requests: [OracleReadingRequest] = []

        func append(_ request: OracleReadingRequest) {
            lock.withLock { requests.append(request) }
        }

        var all: [OracleReadingRequest] {
            lock.withLock { requests }
        }
    }

    init(response: OracleReadingText = RecordingOracle.plainReading, failure: (any Error)? = nil) {
        self.response = response
        self.failure = failure
    }

    /// Every request made, in order.
    var requests: [OracleReadingRequest] { recorded.all }

    func reading(for request: OracleReadingRequest) async throws -> OracleReadingText {
        recorded.append(request)
        if let failure { throw failure }
        return response
    }

    /// A short, tone-clean reading — deliberately bland, because a fixture that says something
    /// interesting invites a test to assert on the interesting part rather than on the mechanism.
    static let plainReading = OracleReadingText(
        paragraphs: [OracleReadingText.Paragraph("A week of playing, written down.")],
        source: .model
    )
}
