import Foundation

/// Why a support message didn't get through, in the two shapes the sheet has to tell apart.
///
/// The distinction is not pedantry: **`.network` is worth retrying and `.rejected` is not**, so the
/// sheet offers a different next step for each. Both carry a sentence written for a player rather than
/// a log line, because this error is displayed — there is nowhere else for it to go.
enum SupportSendError: Error, Equatable {
    /// The request never reached Formspree: no connection, a timeout, a DNS failure.
    case network
    /// Formspree answered and refused — a malformed address, a tripped spam rule, or the monthly
    /// submission cap reached. `detail` is its own message when it sent one.
    case rejected(detail: String?)

    /// What the sheet shows. Both endings point at the plain-text address, which is the fallback that
    /// works when every other part of this feature doesn't (ADR 0161 D5).
    ///
    /// The refusal **repeats Formspree's own reason when it gave one**. Verified against the live
    /// endpoint, a bad address comes back as `"should be an email"` — which is correctable, so telling
    /// the player only "trying again won't help" would be actively wrong. The reason is quoted rather
    /// than rewritten because we cannot enumerate what it might say.
    var playerFacingMessage: String {
        switch self {
        case .network:
            return "That didn't send — check your connection and try again. Your message is still here."
        case let .rejected(detail):
            let reason = detail.map { " The reply came back: \($0)." } ?? ""
            return "That didn't send.\(reason) If it keeps failing you can email us directly at "
                + "\(FAQEntry.supportAddress) — your message is still here to copy."
        }
    }
}

/// Where a `SupportRequest` goes when the player taps Send (ADR 0161).
///
/// **This protocol is the whole point of the Formspree decision being reversible.** ADR 0161 picks
/// Formspree because no backend exists to extend and standing one up would still mean a third-party
/// email vendor, a key to hold and a rate limiter to write. If that trade ever stops paying — the
/// submission cap bites, or the endpoint gets scraped out of the binary and abused — replacing it is a
/// second conformance and a different URL. No view, no test and no ADR has to move.
///
/// `Sendable` and free of the main actor: the send is awaited off the main thread from a `Task` the
/// sheet owns, and the only main-actor work is the state the sheet flips when it returns.
protocol SupportSending: Sendable {
    func send(_ request: SupportRequest) async throws
}

/// Posts a support message to the Formspree form that already backs the marketing site's contact form
/// and the beta guide's confusion reports (ADR 0161).
///
/// **The endpoint is a public form URL that ships inside the binary**, and that is understood rather
/// than overlooked — it is the same exposure the marketing site has had all along, and it holds no
/// secret. It is not the parked `POCKET_API_HOST` and must not be pointed at it: that host is the
/// Phase 4 Claude proxy, still a placeholder (`api.pocket.example.com`), and this feature deliberately
/// does not wait on it.
///
/// **The contract below was verified against the live endpoint on 2026-08-12**, not inferred from
/// docs — worth doing, because the two callers that already use this form (the marketing site and the
/// beta guide) both post `FormData`, so JSON was genuinely unproven here:
///
/// - Accepted: `200` with `{"next":"/thanks","ok":true}`
/// - Refused:  `422` with
///   `{"error":"Validation errors","errors":[{"code":"TYPE_EMAIL","field":"email","message":"should be an email"}]}`
struct FormspreeSender: SupportSending {
    /// The same form the site's contact page and the beta guide post to, so support messages from every
    /// surface land in one inbox in one format. A valid compile-time literal.
    static let defaultEndpoint = URL(string: "https://formspree.io/f/mbdweqar")!

    let endpoint: URL
    /// Injected so the tests can drive a stubbed protocol without reaching the network.
    let session: URLSession

    init(endpoint: URL = FormspreeSender.defaultEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func send(_ request: SupportRequest) async throws {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        // Without `Accept: application/json` Formspree answers a *redirect to an HTML thank-you page*
        // rather than a JSON verdict, which `URLSession` follows and reports as a 200 — every failure
        // would look like a success. The header is what makes the response readable.
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request.formspreePayload)
        urlRequest.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            // Everything `URLSession` throws here is a transport failure — offline, timed out, DNS.
            // An HTTP refusal arrives as a response, not as a throw, and is handled below.
            throw SupportSendError.network
        }

        guard let http = response as? HTTPURLResponse else { throw SupportSendError.network }
        guard (200..<300).contains(http.statusCode) else {
            throw SupportSendError.rejected(detail: Self.firstErrorMessage(in: data))
        }
    }

    /// Formspree's failure body is `{"errors": [{"message": "…"}, …]}`. Best-effort by design: the
    /// status code has already decided the outcome, and this only sharpens what the player is told.
    static func firstErrorMessage(in data: Data) -> String? {
        try? JSONDecoder().decode(FormspreeFailure.self, from: data).errors?
            .compactMap(\.message).first
    }
}

/// Formspree's failure body: `{"errors": [{"message": "…"}, …]}`. File-scoped rather than nested
/// inside `firstErrorMessage` only because the nesting depth trips SwiftLint.
private struct FormspreeFailure: Decodable {
    struct Item: Decodable { let message: String? }
    let errors: [Item]?
}

/// Keeps every request it is given and fails on command, for tests and previews. Mirrors
/// `RecordingSink`'s role for analytics — not compiled out of the app target (it costs nothing and
/// `@testable import` needs it visible), but never installed outside a test or a `#Preview`.
final class RecordingSupportSender: SupportSending, @unchecked Sendable {
    /// Guards `requests` — `send` is called from a detached task, so the array is touched off the main
    /// actor and the `@unchecked` conformance has to be earned rather than assumed.
    private let lock = NSLock()
    private var stored: [SupportRequest] = []
    private let failure: SupportSendError?

    init(failing failure: SupportSendError? = nil) {
        self.failure = failure
    }

    var requests: [SupportRequest] {
        lock.withLock { stored }
    }

    func send(_ request: SupportRequest) async throws {
        lock.withLock { stored.append(request) }
        if let failure { throw failure }
    }
}
