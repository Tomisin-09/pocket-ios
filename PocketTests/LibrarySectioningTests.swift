import XCTest
@testable import Pocket

/// Covers the pure library grouping/sorting (ADR 0035) — bucket boundaries and section
/// ordering that break silently otherwise.
final class LibrarySectioningTests: XCTestCase {

    /// Gregorian calendar pinned to GMT so day boundaries are deterministic across machines.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        return cal
    }()
    /// Fixed reference "now" so the date buckets are deterministic. 2023-11-14 22:13:20 GMT.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 86_400
    private let hour: TimeInterval = 3_600

    private func fields(_ title: String, artist: String = "", album: String = "",
                        genre: String = "", mastery: Int? = 0,
                        dateAdded: Date? = nil) -> SongGroupFields {
        SongGroupFields(title: title, artist: artist, album: album, genre: genre,
                        mastery: mastery, dateAdded: dateAdded)
    }

    private func sections(_ items: [SongGroupFields], by grouping: SongGrouping) -> [LibrarySection<SongGroupFields>] {
        LibrarySectioning.sections(items, by: grouping, now: now, calendar: calendar) { $0 }
    }

    // MARK: - masteryTier

    func testMasteryTierBoundaries() {
        XCTAssertEqual(LibrarySectioning.masteryTier(0).title, "Needs work")
        XCTAssertEqual(LibrarySectioning.masteryTier(1).title, "Needs work")
        XCTAssertEqual(LibrarySectioning.masteryTier(2).title, "Solid")
        XCTAssertEqual(LibrarySectioning.masteryTier(3).title, "Solid")
        XCTAssertEqual(LibrarySectioning.masteryTier(4).title, "Polished")
        XCTAssertEqual(LibrarySectioning.masteryTier(5).title, "Polished")
    }

    func testMasteryTierNilIsUnrated() {
        XCTAssertEqual(LibrarySectioning.masteryTier(nil).title, "Unrated")
    }

    // MARK: - dateBucket

    func testDateBucketToday() {
        XCTAssertEqual(LibrarySectioning.dateBucket(now, now: now, calendar: calendar).title, "Today")
    }

    func testDateBucketWithinWeek() {
        let threeDaysAgo = now.addingTimeInterval(-3 * day)
        XCTAssertEqual(LibrarySectioning.dateBucket(threeDaysAgo, now: now, calendar: calendar).title, "This week")
    }

    func testDateBucketEarlierAndNil() {
        let longAgo = now.addingTimeInterval(-30 * day)
        XCTAssertEqual(LibrarySectioning.dateBucket(longAgo, now: now, calendar: calendar).title, "Earlier")
        XCTAssertEqual(LibrarySectioning.dateBucket(nil, now: now, calendar: calendar).title, "Earlier")
    }

    // MARK: - alphaSection

    func testAlphaSectionLetterUppercases() {
        XCTAssertEqual(LibrarySectioning.alphaSection("blue hour", emptyTitle: "X").title, "B")
    }

    func testAlphaSectionNonLetterIsHash() {
        XCTAssertEqual(LibrarySectioning.alphaSection("3am", emptyTitle: "X").title, "#")
        XCTAssertEqual(LibrarySectioning.alphaSection("!!!", emptyTitle: "X").title, "#")
    }

    func testAlphaSectionEmptyUsesFallback() {
        XCTAssertEqual(LibrarySectioning.alphaSection("   ", emptyTitle: "Unknown Artist").title, "Unknown Artist")
    }

    // MARK: - sections: mastery

    func testMasterySectionsOrderedNeedsWorkFirstUnratedLast() {
        let result = sections([
            fields("Polished one", mastery: 5),
            fields("Rough one", mastery: 0),
            fields("Solid one", mastery: 3),
            fields("Loopless one", mastery: nil)
        ], by: .mastery)
        XCTAssertEqual(result.map(\.title), ["Needs work", "Solid", "Polished", "Unrated"])
    }

    // MARK: - sections: recentlyAdded

    func testRecentlyAddedBucketsAndNewestFirst() {
        let today1 = now
        let today2 = now.addingTimeInterval(-2 * hour)
        let lastWeek = now.addingTimeInterval(-4 * day)
        let result = sections([
            fields("Older today", dateAdded: today2),
            fields("Newest", dateAdded: today1),
            fields("Week", dateAdded: lastWeek),
            fields("Ancient", dateAdded: nil)
        ], by: .recentlyAdded)
        XCTAssertEqual(result.map(\.title), ["Today", "This week", "Earlier"])
        // Within Today, the newer import comes first.
        XCTAssertEqual(result[0].items.map(\.title), ["Newest", "Older today"])
    }

    // MARK: - sections: title (A–Z, # after letters)

    func testTitleSectionsAlphabeticalWithHashAfterLetters() {
        let result = sections([
            fields("Banana"),
            fields("apple"),
            fields("3 strikes")
        ], by: .title)
        XCTAssertEqual(result.map(\.title), ["A", "B", "#"])
    }

    // MARK: - sections: artist (Unknown bucket last)

    func testArtistUnknownBucketSortsLast() {
        let result = sections([
            fields("No artist", artist: ""),
            fields("Zed song", artist: "Zydeco"),
            fields("Aaa song", artist: "Allman")
        ], by: .artist)
        XCTAssertEqual(result.map(\.title), ["A", "Z", "Unknown Artist"])
    }

    func testArtistSectionItemsSortByArtistThenTitle() {
        // Same "A" section, two artists — order by artist, then title within an artist.
        let result = sections([
            fields("Song B", artist: "Allman"),
            fields("Song A", artist: "Allman"),
            fields("Apex", artist: "Arc")
        ], by: .artist)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].items.map(\.title), ["Song A", "Song B", "Apex"])
    }

    // MARK: - sections: genre

    func testGenreUnknownBucket() {
        let result = sections([
            fields("Untagged", genre: ""),
            fields("Bluesy", genre: "Blues")
        ], by: .genre)
        XCTAssertEqual(result.map(\.title), ["B", "Unknown Genre"])
    }

    // MARK: - sections: descending flip

    func testDescendingReversesSectionAndItemOrder() {
        let input = [fields("apple"), fields("Banana"), fields("Berry")]
        let asc = sections(input, by: .title)
        let desc = LibrarySectioning.sections(input, by: .title, ascending: false,
                                              now: now, calendar: calendar) { $0 }
        // Ascending: A [apple], B [Banana, Berry].
        XCTAssertEqual(asc.map(\.title), ["A", "B"])
        XCTAssertEqual(asc[1].items.map(\.title), ["Banana", "Berry"])
        // Descending flips both the section order and each section's items.
        XCTAssertEqual(desc.map(\.title), ["B", "A"])
        XCTAssertEqual(desc[0].items.map(\.title), ["Berry", "Banana"])
    }

    // MARK: - empty

    func testEmptyInputYieldsNoSections() {
        XCTAssertTrue(sections([], by: .title).isEmpty)
    }

    // MARK: - matchesSearch

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(LibrarySectioning.matchesSearch(fields("Anything"), query: ""))
        XCTAssertTrue(LibrarySectioning.matchesSearch(fields("Anything"), query: "   "))
    }

    func testSearchMatchesTitleOrArtistCaseInsensitively() {
        let song = fields("Blue Hour", artist: "The Allmans")
        XCTAssertTrue(LibrarySectioning.matchesSearch(song, query: "blue"))
        XCTAssertTrue(LibrarySectioning.matchesSearch(song, query: "ALLMAN"))
        XCTAssertFalse(LibrarySectioning.matchesSearch(song, query: "zydeco"))
    }

    func testSearchIgnoresDiacritics() {
        XCTAssertTrue(LibrarySectioning.matchesSearch(fields("Café del Mar"), query: "cafe"))
    }
}
