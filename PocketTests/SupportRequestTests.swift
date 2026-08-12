import XCTest
@testable import Pocket

/// The in-app contact form's pure half (ADR 0161) — what counts as sendable, what the payload carries,
/// and how the diagnostics string is built.
///
/// The point of most of these is **the disclosure promise**: the sheet shows the player
/// `SupportDiagnostics.summary` and tells them that is everything attached. That promise is only true
/// while the payload carries nothing the summary doesn't mention, which no amount of careful UI work
/// can guarantee on its own — so it is pinned here.
final class SupportRequestTests: XCTestCase {

    private let diagnostics = SupportDiagnostics(
        appVersion: "1.2 (4)",
        systemVersion: "18.5",
        deviceModel: "iPhone17,1"
    )

    private func request(message: String = "The loop keeps jumping back a bar.",
                         address: String = "player@example.com") -> SupportRequest {
        SupportRequest(message: message, replyAddress: address, diagnostics: diagnostics)
    }

    // MARK: - What may be sent

    func testAMessageWithAnAddressIsSendable() {
        XCTAssertTrue(request().isSendable)
    }

    func testAnEmptyMessageIsNotSendable() {
        XCTAssertFalse(request(message: "").isSendable)
    }

    func testAWhitespaceOnlyMessageIsNotSendable() {
        // "   \n  " reads as an empty message to a human, so it has to read as one to the Send button.
        XCTAssertFalse(request(message: "   \n\t ").isSendable)
    }

    func testAMissingAddressIsNotSendable() {
        // ADR 0161 D2: the address is required. A message we can read and never answer is the outcome
        // this rules out.
        XCTAssertFalse(request(address: "").isSendable)
    }

    // MARK: - The address check (a typo catcher, not a validator)

    func testOrdinaryAddressesPass() {
        for address in ["a@b.co", "player@example.com", "first.last+tag@sub.domain.co.uk"] {
            XCTAssertTrue(SupportRequest.looksLikeEmailAddress(address), "Rejected \(address)")
        }
    }

    func testTheTwoTyposThatActuallyHappenAreCaught() {
        XCTAssertFalse(SupportRequest.looksLikeEmailAddress("me@gmail"), "No dot in the domain")
        XCTAssertFalse(SupportRequest.looksLikeEmailAddress("player.example.com"), "No @ at all")
    }

    func testMalformedShapesAreCaught() {
        for address in ["@example.com", "player@", "player@@example.com", "player@.com",
                        "player@example.", "player name@example.com"] {
            XCTAssertFalse(SupportRequest.looksLikeEmailAddress(address), "Accepted \(address)")
        }
    }

    func testSurroundingWhitespaceIsForgiven() {
        // Autocomplete and paste both hand over a trailing space. Refusing to send over one would be
        // a maddening way to lose a message.
        XCTAssertTrue(SupportRequest.looksLikeEmailAddress("  player@example.com  "))
    }

    // MARK: - The payload

    func testPayloadCarriesTheMessageAndAddress() {
        let payload = request().formspreePayload
        XCTAssertEqual(payload["email"], "player@example.com")
        XCTAssertEqual(payload["message"], "The loop keeps jumping back a bar.")
    }

    func testPayloadTrimsBothFields() {
        let payload = request(message: "\n  it drifts  \n", address: " player@example.com ")
            .formspreePayload
        XCTAssertEqual(payload["message"], "it drifts")
        XCTAssertEqual(payload["email"], "player@example.com")
    }

    func testPayloadCarriesTheVersionInTheSubjectForTriage() {
        // `_subject` is a Formspree special field — it becomes the email's subject line, which is the
        // triage signal the old `mailto:` carried and the reason to keep the version in it.
        XCTAssertEqual(request().formspreePayload["_subject"],
                       "Red Moon Practice 1.2 (4) — support")
    }

    /// **The disclosure promise.** Every value in the payload is either something the player typed or
    /// something `summary` puts on screen. A new key here that the sheet doesn't show turns the
    /// "nothing else goes with it" footer into a false statement, and this is what catches that.
    func testPayloadCarriesNothingTheSheetDoesNotShow() {
        let payload = request().formspreePayload
        let typed = ["email", "message"]
        let disclosed = ["app_version", "ios_version", "device_model", "_subject"]
        XCTAssertEqual(Set(payload.keys), Set(typed + disclosed),
                       "A payload key was added or removed — if it is new, the sheet must show it "
                        + "and ADR 0161 D3 plus the privacy manifest must be updated with it")

        let summary = diagnostics.summary
        for key in ["app_version", "ios_version", "device_model"] {
            guard let value = payload[key] else { return XCTFail("\(key) missing from the payload") }
            XCTAssertTrue(summary.contains(value),
                          "\(key) is sent but does not appear in the summary shown to the player")
        }
    }

    func testPayloadNeverCarriesAnIdentifier() {
        // Blunt, and deliberately so. No IDFV, no IDFA, no account id — ADR 0120's rule that the app
        // sends nothing linked to an identity survives the app gaining its first real network call.
        let joined = request().formspreePayload.values.joined(separator: " ").lowercased()
        for forbidden in ["idfa", "idfv", "vendor", "advertis", "uuid"] {
            XCTAssertFalse(joined.contains(forbidden), "Payload mentions \(forbidden)")
        }
    }

    // MARK: - Diagnostics

    func testSummaryReadsAsOneLine() {
        XCTAssertEqual(diagnostics.summary, "Red Moon Practice 1.2 (4) · iOS 18.5 · iPhone17,1")
    }

    func testAppVersionCombinesMarketingAndBuild() {
        let bundle = StubInfoDictionary(["CFBundleShortVersionString": "1.2", "CFBundleVersion": "4"])
        XCTAssertEqual(SupportDiagnostics.currentAppVersion(bundle: bundle), "1.2 (4)")
    }

    func testAppVersionOmitsAMissingBuildRatherThanFakingOne() {
        let bundle = StubInfoDictionary(["CFBundleShortVersionString": "1.2"])
        XCTAssertEqual(SupportDiagnostics.currentAppVersion(bundle: bundle), "1.2")
    }

    func testAppVersionFallsBackRatherThanCrashing() {
        // The contact-support screen is the worst possible place to crash: it is where someone goes
        // when something else has already gone wrong.
        XCTAssertEqual(SupportDiagnostics.currentAppVersion(bundle: StubInfoDictionary([:])), "—")
    }

    func testSystemVersionDropsAZeroPatch() {
        let version = OperatingSystemVersion(majorVersion: 18, minorVersion: 5, patchVersion: 0)
        XCTAssertEqual(SupportDiagnostics.currentSystemVersion(version), "18.5")
    }

    func testSystemVersionKeepsANonZeroPatch() {
        let version = OperatingSystemVersion(majorVersion: 18, minorVersion: 5, patchVersion: 1)
        XCTAssertEqual(SupportDiagnostics.currentSystemVersion(version), "18.5.1")
    }

    func testDeviceModelIsNeverEmpty() {
        // Under the test host this reports the simulator's model identifier; on a device, the
        // hardware one. Either way it must not hand an empty string to the summary.
        XCTAssertFalse(SupportDiagnostics.currentDeviceModel().isEmpty)
    }
}

// MARK: - Stubs

/// An Info dictionary that is whatever the test says it is — including empty, which is the case that
/// would otherwise only show up as a crash in front of a player.
private struct StubInfoDictionary: InfoDictionaryReading {
    private let values: [String: String]

    init(_ values: [String: String]) {
        self.values = values
    }

    func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}
