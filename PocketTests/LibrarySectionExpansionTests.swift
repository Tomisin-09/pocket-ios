import XCTest
@testable import Pocket

/// The persisted collapse state behind every grouped library list (v2 close-out Slice 5). Storage
/// codec + the two rules that decide whether rows render: collapsed-is-stored, and search wins.
final class LibrarySectionExpansionTests: XCTestCase {

    // MARK: - Defaults

    func testUntouchedSectionIsExpanded() {
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("Scales", in: ""))
        XCTAssertTrue(LibrarySectionExpansion.collapsed(from: "").isEmpty)
    }

    /// The reason collapse (not expansion) is what's stored: a bucket that appears later — a first
    /// scales drill, a newly imported song — must arrive open.
    func testNewSectionIsExpandedAlongsideCollapsedOnes() {
        let raw = LibrarySectionExpansion.setting("Picking", expanded: false, in: "")
        XCTAssertFalse(LibrarySectionExpansion.isExpanded("Picking", in: raw))
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("Scales", in: raw))
    }

    func testUnreadablePayloadReadsAsNothingCollapsed() {
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("Scales", in: "not json at all"))
        XCTAssertTrue(LibrarySectionExpansion.collapsed(from: "[\"unterminated").isEmpty)
    }

    // MARK: - Toggling

    func testCollapseThenExpandRoundTrips() {
        var raw = LibrarySectionExpansion.setting("Scales", expanded: false, in: "")
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), ["Scales"])
        raw = LibrarySectionExpansion.setting("Scales", expanded: true, in: raw)
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), [])
    }

    func testTogglingOneSectionLeavesTheOthers() {
        var raw = LibrarySectionExpansion.setting("Scales", expanded: false, in: "")
        raw = LibrarySectionExpansion.setting("Picking", expanded: false, in: raw)
        raw = LibrarySectionExpansion.setting("Scales", expanded: true, in: raw)
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), ["Picking"])
    }

    /// Titles are user text — a song called "A · B" must collapse one section, not two. This is why
    /// the payload is JSON rather than a joined string.
    func testTitleContainingPunctuationIsOneSection() {
        let raw = LibrarySectionExpansion.setting("A · B, and \"C\"", expanded: false, in: "")
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), ["A · B, and \"C\""])
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("A", in: raw))
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("B", in: raw))
    }

    // MARK: - Search

    /// The one way a collapse could read as a bug: a search matching rows inside a shut bucket.
    func testSearchForcesEverySectionOpen() {
        let raw = LibrarySectionExpansion.setting("Scales", expanded: false, in: "")
        XCTAssertFalse(LibrarySectionExpansion.isExpanded("Scales", in: raw, searching: false))
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("Scales", in: raw, searching: true))
    }

    /// Searching only *displays* the section — it must not forget the collapse, so clearing the
    /// query puts the list back the way it was left.
    func testSearchDoesNotClearStoredCollapse() {
        let raw = LibrarySectionExpansion.setting("Scales", expanded: false, in: "")
        _ = LibrarySectionExpansion.isExpanded("Scales", in: raw, searching: true)
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), ["Scales"])
    }

    // MARK: - Scopes

    /// The song library re-buckets by mastery / artist / title, where the same letter means
    /// different sections. Collapsing "A" under Artist must not shut "A" under Title.
    func testScopesDoNotCollide() {
        let raw = LibrarySectionExpansion.setting("A", expanded: false, in: "", scope: "artist")
        XCTAssertFalse(LibrarySectionExpansion.isExpanded("A", in: raw, scope: "artist"))
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("A", in: raw, scope: "title"))
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw, scope: "title"), [])
    }

    func testTogglingInOneScopeCarriesTheOtherThrough() {
        var raw = LibrarySectionExpansion.setting("A", expanded: false, in: "", scope: "artist")
        raw = LibrarySectionExpansion.setting("Polished", expanded: false, in: raw, scope: "mastery")
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw, scope: "artist"), ["A"])
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw, scope: "mastery"), ["Polished"])
    }

    /// A scoped payload and an unscoped one share the same storage; neither may read the other's
    /// titles (the two practice libraries pass no scope, the song library always does).
    func testUnscopedReadIgnoresScopedTitles() {
        let raw = LibrarySectionExpansion.setting("A", expanded: false, in: "", scope: "artist")
        XCTAssertTrue(LibrarySectionExpansion.isExpanded("A", in: raw))
        XCTAssertEqual(LibrarySectionExpansion.collapsed(from: raw), [])
    }
}
