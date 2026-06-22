import XCTest
@testable import Pocket

/// Covers the shared label canonicaliser (ADR 0033 / 0034) — the guard that keeps
/// Collections and Tags from fragmenting into Blues / blues / "blues ".
final class LabelsTests: XCTestCase {

    // MARK: - canonical

    func testCanonicalTrimsSurroundingWhitespace() {
        XCTAssertEqual(Labels.canonical("  Blues "), "Blues")
    }

    func testCanonicalCollapsesInternalWhitespaceRuns() {
        XCTAssertEqual(Labels.canonical("needs   work"), "needs work")
        // Tabs / newlines count as whitespace and collapse to a single space too.
        XCTAssertEqual(Labels.canonical("needs\t\nwork"), "needs work")
    }

    func testCanonicalPreservesCase() {
        // Canonicalisation is whitespace-only — it never changes the display form's case.
        XCTAssertEqual(Labels.canonical("Drop D"), "Drop D")
    }

    func testCanonicalRejectsEmptyAndWhitespaceOnly() {
        XCTAssertNil(Labels.canonical(""))
        XCTAssertNil(Labels.canonical("   "))
        XCTAssertNil(Labels.canonical("\t \n"))
    }

    // MARK: - adding

    func testAddingAppendsCanonicalForm() {
        XCTAssertEqual(Labels.adding("  Blues ", to: []), ["Blues"])
    }

    func testAddingIsCaseInsensitiveNoOpKeepingFirstSeenForm() {
        // "blues" with "Blues" already present is a no-op, and the stored form stays "Blues".
        XCTAssertEqual(Labels.adding("blues", to: ["Blues"]), ["Blues"])
    }

    func testAddingDedupsAfterCanonicalisation() {
        // "blues " canonicalises to "blues", which matches "Blues" case-insensitively.
        XCTAssertEqual(Labels.adding("blues ", to: ["Blues"]), ["Blues"])
    }

    func testAddingRejectsEmptyInput() {
        XCTAssertEqual(Labels.adding("   ", to: ["Blues"]), ["Blues"])
    }

    func testAddingDistinctLabelAppends() {
        XCTAssertEqual(Labels.adding("Jazz", to: ["Blues"]), ["Blues", "Jazz"])
    }

    // MARK: - normalized

    func testNormalizedCleansAWholeFragmentedSet() {
        // First-seen form wins; later case/whitespace variants and empties drop out.
        let input = ["Blues", "blues", "  Jazz ", "", "JAZZ", "rock  solid"]
        XCTAssertEqual(Labels.normalized(input), ["Blues", "Jazz", "rock solid"])
    }

    func testNormalizedPreservesOrderOfFirstAppearance() {
        XCTAssertEqual(Labels.normalized(["b", "a", "B", "A"]), ["b", "a"])
    }

    // MARK: - suggestions

    func testSuggestionsAreDistinctNormalisedAndSorted() {
        // Pool spans multiple songs (duplicates, case + whitespace variants); the
        // suggestion list is distinct, canonical, and case-insensitively sorted.
        let pool = ["Blues", "blues", "Jazz", "  rock ", "JAZZ"]
        XCTAssertEqual(Labels.suggestions(from: pool, excluding: []), ["Blues", "Jazz", "rock"])
    }

    func testSuggestionsExcludeLabelsAlreadyOnTheItem() {
        // "blues" is already on this song (as "Blues") → not re-offered.
        let pool = ["Blues", "Jazz", "Rock"]
        XCTAssertEqual(Labels.suggestions(from: pool, excluding: ["blues"]), ["Jazz", "Rock"])
    }

    func testSuggestionsEmptyWhenPoolExhaustedByCurrent() {
        XCTAssertEqual(Labels.suggestions(from: ["Blues"], excluding: ["BLUES"]), [])
    }
}
