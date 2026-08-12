import XCTest
@testable import Pocket

/// `FormspreeSender`'s half of ADR 0161 — the request it builds and the verdict it reads back.
///
/// Driven through a stubbed `URLProtocol`, so **no test here touches the network**. That matters more
/// than usual: the live endpoint delivers to a real support inbox on a 50-submission monthly plan, and
/// a test suite that posted to it would burn the allowance and spam the inbox on every CI run.
///
/// The case worth understanding is `testAnHTTPFailureIsRejectedNotNetwork`. Formspree answers a refusal
/// with a 4xx *response*, not a transport error, so a sender that only caught thrown errors would call
/// every refusal a success. The two are told apart because the sheet offers a different next step for
/// each.
final class FormspreeSenderTests: XCTestCase {

    private let endpoint = URL(string: "https://formspree.example/f/test")!

    private var request: SupportRequest {
        SupportRequest(
            message: "The loop keeps jumping back a bar.",
            replyAddress: "player@example.com",
            diagnostics: SupportDiagnostics(appVersion: "1.2 (4)",
                                            systemVersion: "18.5",
                                            deviceModel: "iPhone17,1")
        )
    }

    private func sender() -> FormspreeSender {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return FormspreeSender(endpoint: endpoint, session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - The request that goes out

    func testSendsJSONByPOSTAndAsksForAJSONVerdict() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ok":true}"#.utf8))

        try await sender().send(request)

        let sent = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.url, endpoint)
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Content-Type"), "application/json")
        // Without this header Formspree redirects to an HTML thank-you page instead of answering
        // with a verdict, and `URLSession` follows the redirect — every refusal would read as a 200.
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testTheBodyIsThePayload() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ok":true}"#.utf8))

        try await sender().send(request)

        let body = try XCTUnwrap(StubURLProtocol.lastBody)
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(decoded, request.formspreePayload)
    }

    // MARK: - The verdict that comes back

    func testATwoHundredIsASuccess() async throws {
        StubURLProtocol.respond(status: 200, body: Data(#"{"ok":true}"#.utf8))
        try await sender().send(request)
    }

    func testAnHTTPFailureIsRejectedNotNetwork() async {
        StubURLProtocol.respond(status: 422,
                                body: Data(#"{"errors":[{"message":"Email is invalid"}]}"#.utf8))

        await XCTAssertThrowsSupportError(try await sender().send(request),
                                          .rejected(detail: "Email is invalid"))
    }

    func testARejectionWithNoReadableBodyStillRejects() async {
        // The status code decides the outcome; the detail only sharpens the wording.
        StubURLProtocol.respond(status: 500, body: Data("<html>nope</html>".utf8))

        await XCTAssertThrowsSupportError(try await sender().send(request), .rejected(detail: nil))
    }

    func testATransportFailureIsNetwork() async {
        StubURLProtocol.fail(with: URLError(.notConnectedToInternet))

        await XCTAssertThrowsSupportError(try await sender().send(request), .network)
    }

    // MARK: - What the player is told

    func testNetworkFailureInvitesARetryAndPromisesTheMessageIsKept() {
        let message = SupportSendError.network.playerFacingMessage
        XCTAssertTrue(message.contains("try again"))
        XCTAssertTrue(message.contains("still here"))
    }

    func testRejectionPointsAtTheAddress() {
        // A refusal may not be fixable by retrying, so this ending has to carry the fallback address —
        // which is why `FAQEntry.supportAddress` may not be deleted.
        let message = SupportSendError.rejected(detail: nil).playerFacingMessage
        XCTAssertTrue(message.contains(FAQEntry.supportAddress))
    }

    func testRejectionRepeatsTheReasonWhenThereIsOne() {
        // Verified against the live endpoint: a bad address returns "should be an email", which the
        // player *can* fix. Swallowing it and saying only "that didn't send" would hide the fix.
        let message = SupportSendError.rejected(detail: "should be an email").playerFacingMessage
        XCTAssertTrue(message.contains("should be an email"))
    }

    func testTheLiveErrorBodyIsDecoded() {
        // The exact 422 body the live endpoint returned for an invalid address, pinned verbatim so a
        // change in Formspree's error shape fails here rather than silently blanking the reason.
        let body = Data(#"{"error":"Validation errors","errors":[{"code":"TYPE_EMAIL","#.utf8)
            + Data(#""field":"email","message":"should be an email"}]}"#.utf8)
        XCTAssertEqual(FormspreeSender.firstErrorMessage(in: body), "should be an email")
    }

    func testAnUnreadableErrorBodyYieldsNoReason() {
        XCTAssertNil(FormspreeSender.firstErrorMessage(in: Data("<html>nope</html>".utf8)))
    }

    // MARK: - The live endpoint

    func testTheDefaultEndpointIsTheSharedFormOverHTTPS() {
        // The same form the marketing site's contact page and the beta guide post to — one inbox, one
        // format. HTTPS is asserted because an http:// endpoint would be blocked by ATS at runtime
        // and would ship a support message in the clear.
        XCTAssertEqual(FormspreeSender.defaultEndpoint.scheme, "https")
        XCTAssertEqual(FormspreeSender.defaultEndpoint.absoluteString,
                       "https://formspree.io/f/mbdweqar")
    }

    /// `XCTAssertThrowsError` has no async form that reads well, and the failure this checks is a typed
    /// enum with an associated value — so the comparison is explicit rather than a cast.
    private func XCTAssertThrowsSupportError(
        _ expression: @autoclosure () async throws -> Void,
        _ expected: SupportSendError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected \(expected), but the send succeeded", file: file, line: line)
        } catch let error as SupportSendError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected \(expected), got \(error)", file: file, line: line)
        }
    }
}

/// Answers every request with whatever the test last set, and records what it was asked to send.
///
/// `URLProtocol` registration is process-wide, so the state is static and `tearDown` resets it. The
/// lock is not ceremony: `URLSession` calls this on its own queue while the test awaits on another.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    /// All of the stub's mutable state in one box, so the `nonisolated(unsafe)` escape hatch is taken
    /// exactly once and its justification — every access goes through `lock` — is stated in one place
    /// rather than three.
    private struct State {
        var status = 200
        var body = Data()
        var failure: (any Error)?
        var recorded: URLRequest?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var state = State()

    private static func withState<T>(_ body: (inout State) -> T) -> T {
        lock.withLock { body(&state) }
    }

    static func respond(status: Int, body: Data) {
        withState {
            $0.status = status
            $0.body = body
            $0.failure = nil
        }
    }

    static func fail(with error: any Error) {
        withState { $0.failure = error }
    }

    static func reset() {
        withState { $0 = State() }
    }

    static var lastRequest: URLRequest? {
        withState { $0.recorded }
    }

    /// `URLProtocol` strips `httpBody` from the request it hands over, keeping it only as a stream —
    /// reading the stream is the only way to see what was actually posted.
    static var lastBody: Data? {
        guard let stream = withState({ $0.recorded })?.httpBodyStream else {
            return withState { $0.recorded }?.httpBody
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 1024
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            guard read > 0 else { break }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let snapshot = Self.withState { state -> State in
            state.recorded = request
            return state
        }

        if let failure = snapshot.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: snapshot.status,
                                             httpVersion: "HTTP/1.1", headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: snapshot.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
