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

    // MARK: - canonicalSingle (single-valued group key, e.g. genre)

    func testCanonicalSingleWhitespaceCanonicalisesWhenNoPoolMatch() {
        XCTAssertEqual(Labels.canonicalSingle("  Blues ", against: []), "Blues")
        XCTAssertEqual(Labels.canonicalSingle("rock  solid", against: []), "rock solid")
    }

    func testCanonicalSingleEmptyOrWhitespaceBecomesEmptyString() {
        // Unlike a tag (dropped), a single field keeps its unset state as "".
        XCTAssertEqual(Labels.canonicalSingle("", against: ["Blues"]), "")
        XCTAssertEqual(Labels.canonicalSingle("   ", against: ["Blues"]), "")
    }

    func testCanonicalSingleFoldsOntoExistingDisplayForm() {
        // "blues" with "Blues" already used in the library converges onto "Blues".
        XCTAssertEqual(Labels.canonicalSingle("blues", against: ["Blues", "Jazz"]), "Blues")
        // Whitespace + case both fold.
        XCTAssertEqual(Labels.canonicalSingle("  JAZZ ", against: ["Blues", "Jazz"]), "Jazz")
    }

    func testCanonicalSingleKeepsNewGenreWhenPoolHasNoMatch() {
        // Pool excludes the edited song, so renaming the only holder's case is respected.
        XCTAssertEqual(Labels.canonicalSingle("blues", against: []), "blues")
        XCTAssertEqual(Labels.canonicalSingle("Folk", against: ["Blues", "Jazz"]), "Folk")
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

    // MARK: - matches, allOf (intersection — no longer the library filter, ADR 0159)

    func testEmptyFilterMatchesEverything() {
        XCTAssertTrue(Labels.matches([], allOf: []))
        XCTAssertTrue(Labels.matches(["Blues"], allOf: []))
    }

    func testSingleSelectMatchesCaseInsensitively() {
        XCTAssertTrue(Labels.matches(["Blues", "Jazz"], allOf: ["blues"]))
        XCTAssertFalse(Labels.matches(["Jazz"], allOf: ["Blues"]))
    }

    /// Still correct **as an `allOf` test**. ADR 0159 didn't make intersection wrong, it moved the
    /// library filter off it — AND remains the right relation across facets, and
    /// `CollectionSessionBuilder` still asks it of a single label.
    func testMultiSelectAllOfRequiresEverySelected() {
        XCTAssertTrue(Labels.matches(["Blues", "Jazz", "Rock"], allOf: ["Blues", "Jazz"]))
        XCTAssertFalse(Labels.matches(["Blues"], allOf: ["Blues", "Jazz"]))
    }

    func testMatchesIgnoresWhitespaceVariants() {
        XCTAssertTrue(Labels.matches(["  blues "], allOf: ["Blues"]))
    }

    // MARK: - matches, anyOf (union — the library filter, ADR 0159)

    /// "No filter" must not depend on which relation is asked, or clearing the filter would behave
    /// differently from never having set one.
    func testEmptyAnyOfFilterMatchesEverything() {
        XCTAssertTrue(Labels.matches([], anyOf: []))
        XCTAssertTrue(Labels.matches(["Blues"], anyOf: []))
    }

    /// The single-select case — where AND and OR agree, which is why ADR 0033's argument for AND
    /// went unchallenged for so long.
    func testSingleSelectAnyOfAgreesWithAllOf() {
        XCTAssertTrue(Labels.matches(["Blues", "Jazz"], anyOf: ["blues"]))
        XCTAssertFalse(Labels.matches(["Jazz"], anyOf: ["Blues"]))
    }

    /// **The defect this fixes.** A song in one of two ticked collections must show. Under the old
    /// intersection it didn't, so ticking a second collection emptied the list — the reported
    /// symptom was "Covers ✓ + Ocean's Trilogy ✓ → No songs in this collection".
    func testMultiSelectAnyOfMatchesASongInJustOne() {
        XCTAssertTrue(Labels.matches(["Covers"], anyOf: ["Covers", "Ocean's Trilogy"]))
        XCTAssertTrue(Labels.matches(["Ocean's Trilogy"], anyOf: ["Covers", "Ocean's Trilogy"]))
        XCTAssertFalse(Labels.matches(["Originals"], anyOf: ["Covers", "Ocean's Trilogy"]),
                       "a song in neither still stays hidden — this is a union, not a no-op")
    }

    /// A song in *both* appears once, not twice, and is not excluded for over-qualifying.
    func testAnyOfIncludesASongCarryingEverySelectedLabel() {
        XCTAssertTrue(Labels.matches(["Covers", "Ocean's Trilogy"],
                                     anyOf: ["Covers", "Ocean's Trilogy"]))
    }

    func testAnyOfIgnoresWhitespaceAndCaseVariants() {
        XCTAssertTrue(Labels.matches(["  blues "], anyOf: ["BLUES", "Jazz"]))
    }
}
