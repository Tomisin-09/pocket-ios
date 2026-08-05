import XCTest
@testable import Pocket

/// Matching for the searchable picker (`SearchablePickerList`). Pinned because a search that quietly
/// stops matching looks like a **missing library**, not a broken filter — the player concludes the
/// song isn't there and stops looking, which is the worst way for this to fail.
final class PickerSearchTests: XCTestCase {

    private let library = [
        PickerItem(value: "1", title: "Black Dog", context: "Led Zeppelin"),
        PickerItem(value: "2", title: "Björk — Hyperballad", context: "Post"),
        PickerItem(value: "3", title: "Little Wing", context: "Jimi Hendrix"),
        PickerItem(value: "4", title: "Untitled", context: nil)
    ]

    private func titles(_ query: String) -> [String] {
        PickerSearch.filter(library, query: query).map(\.title)
    }

    /// A cleared field restores the whole library rather than emptying it.
    func testAnEmptyQueryMatchesEverything() {
        XCTAssertEqual(titles("").count, library.count)
        XCTAssertEqual(titles("   ").count, library.count, "whitespace only is still empty")
    }

    func testMatchesOnTheTitle() {
        XCTAssertEqual(titles("wing"), ["Little Wing"])
    }

    /// **The context line is searched too.** Which half of a song a player remembers — its title or
    /// who played it — is a coin toss, and a picker that only matches titles loses that toss half the
    /// time.
    func testMatchesOnTheContextLine() {
        XCTAssertEqual(titles("hendrix"), ["Little Wing"])
        XCTAssertEqual(titles("zeppelin"), ["Black Dog"])
    }

    func testMatchingIgnoresCase() {
        XCTAssertEqual(titles("BLACK"), ["Black Dog"])
        XCTAssertEqual(titles("black"), ["Black Dog"])
    }

    /// "Bjork" must find "Björk". Requiring the exact glyphs would make a correctly-spelled library
    /// unsearchable from a plain keyboard.
    func testMatchingIgnoresDiacritics() {
        XCTAssertEqual(titles("bjork"), ["Björk — Hyperballad"])
    }

    func testAnItemWithNoContextStillMatchesOnItsTitle() {
        XCTAssertEqual(titles("untitled"), ["Untitled"])
    }

    func testNoMatchReturnsNothingRatherThanEverything() {
        XCTAssertTrue(titles("zzzz").isEmpty)
    }

    /// The library's own sort is a decision the picker has no business re-making.
    func testFilteringPreservesTheCallersOrder() {
        // "n" matches items 1, 3 and 4 — via "Led Zeppelin", "Wing" and "Untitled" — so a filter that
        // reordered or grouped by which field matched would show up here.
        XCTAssertEqual(titles("n"), ["Black Dog", "Little Wing", "Untitled"])
    }
}
