import XCTest
@testable import Pocket

/// `OracleEndpoint` — resolving the Oracle proxy's base URL from a build setting (ADR 0187 S0).
///
/// Worth testing beyond its size, because every failure mode here is quiet. A dropped `$()` escape
/// truncates the value to `http:` and still parses; an unexpanded `$(POCKET_API_BASE_URL)` is a
/// valid *relative* URL; and an empty Release value is indistinguishable from a bug unless
/// something asserts that it is the intended state. All three would surface much later as a
/// connection failure, which looks like a network fault rather than a configuration one.
final class OracleEndpointTests: XCTestCase {

    // MARK: - No proxy configured (the Release state until S4)

    func testAnEmptyValueResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve(""))
    }

    func testAWhitespaceOnlyValueResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve("   \n "))
    }

    func testAMissingKeyResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve(nil))
    }

    // MARK: - The failure modes that would otherwise look like a network fault

    /// A mis-wired `.xcconfig` surfaces the literal build-setting reference, which is a valid
    /// relative URL and would sail through a plain `URL(string:)`.
    func testAnUnexpandedBuildSettingResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve("$(POCKET_API_BASE_URL)"))
    }

    /// The `//`-is-a-comment footgun this whole configuration exists to dodge: without the `$()`
    /// escape the value truncates at the first slash pair and arrives with no host.
    func testASchemeWithNoHostResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve("http:"))
        XCTAssertNil(OracleEndpoint.resolve("https:"))
    }

    func testAHostWithNoSchemeResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve("localhost:8787"))
    }

    func testANonHTTPSchemeResolvesToNoEndpoint() {
        XCTAssertNil(OracleEndpoint.resolve("file:///tmp/oracle"))
        XCTAssertNil(OracleEndpoint.resolve("ftp://example.com"))
    }

    // MARK: - A real address resolves

    func testTheDebugAddressResolves() {
        let url = OracleEndpoint.resolve("http://localhost:8787")
        XCTAssertEqual(url?.scheme, "http")
        XCTAssertEqual(url?.host, "localhost")
        XCTAssertEqual(url?.port, 8787)
    }

    func testAnHTTPSHostResolves() {
        let url = OracleEndpoint.resolve("https://oracle.example.co.uk")
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "oracle.example.co.uk")
    }

    func testSurroundingWhitespaceIsTrimmedRatherThanFailing() {
        XCTAssertEqual(OracleEndpoint.resolve("  https://oracle.example.co.uk\n")?.host,
                       "oracle.example.co.uk")
    }

    // MARK: - The wiring itself

    /// The positive control (`PracticeArchiveTests` idiom): assert the key is *present* before
    /// trusting any conclusion drawn from its value. Without this, a typo in the `Info.plist` key
    /// or a dropped `configFiles:` entry would leave every other assertion here passing while the
    /// app resolved nothing — a check that succeeds by reading nothing is worse than none.
    ///
    /// Deliberately asserts presence and not the value: the value is per-configuration, and this
    /// suite runs under Debug.
    ///
    /// `Bundle.main`, not `Bundle(for:)` — this suite is hosted in the app, so `.main` is the app
    /// bundle and `Bundle(for:)` would read the test bundle's generated plist, which never carries
    /// this key and would fail for the wrong reason.
    func testTheInfoPlistCarriesTheKey() {
        let raw = Bundle.main.object(forInfoDictionaryKey: OracleEndpoint.infoDictionaryKey)
        XCTAssertNotNil(raw, "POCKET_API_BASE_URL is missing from Info.plist — the .xcconfig or the "
                           + "configFiles: wiring in project.yml has come undone.")
    }

    /// Debug builds must be able to reach a locally-run proxy. If this fails, the `$()` escape in
    /// `Configuration/Pocket-Debug.xcconfig` has been lost.
    func testDebugBuildsResolveAnEndpoint() {
        #if DEBUG
        XCTAssertNotNil(OracleEndpoint.current(),
                        "The Debug base URL did not resolve — check the $() escape in "
                      + "Configuration/Pocket-Debug.xcconfig.")
        #endif
    }
}
