import XCTest
@testable import Pocket

/// **The one substring rule** every search field in the app now shares.
///
/// Pinned as its own suite rather than left to each caller's tests, because the failure this
/// consolidation fixes was invisible per-screen: each matcher was self-consistent and passed its own
/// tests, and the bug only existed in the *difference between* them. A test that can only see one
/// screen cannot catch that, so the rule is asserted once, here, where a fifth variant would have to
/// contradict it out loud.
final class TextMatchTests: XCTestCase {

    // MARK: - contains

    func testMatchingIgnoresCase() {
        XCTAssertTrue(TextMatch.contains("Little Wing", "little"))
        XCTAssertTrue(TextMatch.contains("little wing", "WING"))
    }

    /// The case the consolidation exists for. A player types what they remember, and what they
    /// remember rarely carries the accent.
    func testMatchingIgnoresDiacritics() {
        XCTAssertTrue(TextMatch.contains("Björk", "bjork"))
        XCTAssertTrue(TextMatch.contains("Bjork", "björk"), "and the other direction")
        XCTAssertTrue(TextMatch.contains("Andalusían cadence", "andalusian"))
    }

    /// **A portability guard, not a style assertion.** `range(of:)` answers this differently on
    /// different toolchains — `nil` on CI's Xcode 16, a range on local Xcode 26.5 — so `contains`
    /// decides it rather than inheriting it. This test is what caught that (CI, 2026-09-04), and it
    /// fails again the moment the explicit guard is removed on a machine where the framework
    /// disagrees.
    func testAnEmptyNeedleMatchesEverything() {
        XCTAssertTrue(TextMatch.contains("anything", ""),
                      "callers rely on this in both directions and must not each re-decide it")
        XCTAssertTrue(TextMatch.contains("", ""), "and an empty haystack too")
    }

    func testANeedleThatIsAbsentDoesNotMatch() {
        XCTAssertFalse(TextMatch.contains("Little Wing", "castles"))
    }

    // MARK: - matchesAllTokens

    /// **Every** token must appear — the semantics that make a second word narrow the feed rather
    /// than widen it.
    func testEveryTokenMustAppear() {
        XCTAssertTrue(TextMatch.matchesAllTokens("scales · exercise 17 jul 2026", query: "scales jul"))
        XCTAssertFalse(TextMatch.matchesAllTokens("scales · exercise 17 jul 2026", query: "scales chords"),
                       "one missing token drops the item, however well the other matched")
    }

    func testTokenMatchingIgnoresCaseAndDiacritics() {
        XCTAssertTrue(TextMatch.matchesAllTokens("Björk — Hyperballad", query: "bjork hyperballad"))
    }

    func testAnEmptyQueryKeepsEverything() {
        XCTAssertTrue(TextMatch.matchesAllTokens("anything", query: ""))
        XCTAssertTrue(TextMatch.matchesAllTokens("anything", query: "   "),
                      "whitespace only is still empty — a cleared field restores the list")
    }
}
