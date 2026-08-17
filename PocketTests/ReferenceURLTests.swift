import XCTest
@testable import Pocket

/// The save-time gate on a reference link (ADR 0167). Pure — no store, no view — because "is this
/// a link we will open?" is the kind of predicate that fails silently in the permissive direction:
/// a bad scheme that slips through is handed straight to `openURL`.
final class ReferenceURLTests: XCTestCase {

    // MARK: - What is accepted

    func testAcceptsHTTPAndHTTPS() {
        XCTAssertTrue(ReferenceURL.isValid("https://www.youtube.com/watch?v=abc123"))
        XCTAssertTrue(ReferenceURL.isValid("http://example.com/lesson"))
    }

    /// The paste case, and the reason this feature is usable on a phone: a share sheet routinely
    /// hands over a bare host with no scheme.
    func testSchemeLessEntryIsReadAsHTTPS() throws {
        let url = try XCTUnwrap(ReferenceURL.normalised("youtube.com/watch?v=abc123"))
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.absoluteString, "https://youtube.com/watch?v=abc123")
    }

    func testSurroundingWhitespaceIsTrimmed() throws {
        let url = try XCTUnwrap(ReferenceURL.normalised("  https://example.com/a  \n"))
        XCTAssertEqual(url.absoluteString, "https://example.com/a")
    }

    func testUppercaseSchemeIsAccepted() {
        XCTAssertTrue(ReferenceURL.isValid("HTTPS://Example.com"))
    }

    // MARK: - What is refused

    /// The allowlist earning its keep. Each of these parses as a perfectly good `URL` and would be
    /// handed to `openURL` if the check were a denylist or a "does it parse" test.
    func testRefusesEverySchemeOutsideTheAllowlist() {
        for raw in ["javascript:alert(1)",
                    "mailto:teacher@example.com",
                    "file:///Users/me/tab.pdf",
                    "shortcuts://run-shortcut?name=Wipe",
                    "tel:+441234567890",
                    "data:text/html,<script>0</script>"] {
            XCTAssertFalse(ReferenceURL.isValid(raw), "should refuse \(raw)")
            XCTAssertNil(ReferenceURL.normalised(raw), "should refuse \(raw)")
        }
    }

    func testRefusesEmptyAndWhitespaceOnly() {
        XCTAssertNil(ReferenceURL.normalised(""))
        XCTAssertNil(ReferenceURL.normalised("   \n "))
    }

    /// A scheme with nothing behind it is not a destination, and neither is a bare word — the
    /// scheme-less branch must not turn "notes" into `https://notes`.
    func testRefusesAStringWithNoHost() {
        XCTAssertNil(ReferenceURL.normalised("https://"))
        XCTAssertNil(ReferenceURL.normalised("http:///lesson"))
    }

    // MARK: - The subtitle

    func testDisplayHostDropsWWWAndFoldsCase() {
        XCTAssertEqual(ReferenceURL.displayHost("https://WWW.YouTube.com/watch?v=x"), "youtube.com")
        XCTAssertEqual(ReferenceURL.displayHost("https://youtube.com/watch?v=x"), "youtube.com")
    }

    func testDisplayHostKeepsSubdomainsThatAreNotWWW() {
        XCTAssertEqual(ReferenceURL.displayHost("https://tabs.ultimate-guitar.com/tab/1"),
                       "tabs.ultimate-guitar.com")
    }

    func testDisplayHostWorksOnASchemeLessEntry() {
        XCTAssertEqual(ReferenceURL.displayHost("songsterr.com/a/wsa/x"), "songsterr.com")
    }

    /// The subtitle and the save button must agree: anything that will not be stored has no host
    /// to show, so a row can never render a site for a link the app refused.
    func testDisplayHostIsNilExactlyWhenTheURLIsRefused() {
        for raw in ["javascript:alert(1)", "", "https://", "mailto:a@b.com"] {
            XCTAssertNil(ReferenceURL.displayHost(raw), "should have no host: \(raw)")
            XCTAssertFalse(ReferenceURL.isValid(raw), "should be refused: \(raw)")
        }
    }
}
