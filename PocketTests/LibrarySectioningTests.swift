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
                        genre: String = "", proficiency: Int = 0,
                        dateAdded: Date? = nil) -> SongGroupFields {
        SongGroupFields(title: title, artist: artist, album: album, genre: genre,
                        proficiency: proficiency, dateAdded: dateAdded)
    }

    private func sections(_ items: [SongGroupFields], by grouping: SongGrouping) -> [LibrarySection<SongGroupFields>] {
        LibrarySectioning.sections(items, by: grouping, now: now, calendar: calendar) { $0 }
    }

    // MARK: - proficiencyTier

    func testProficiencyTierBoundaries() {
        XCTAssertEqual(LibrarySectioning.proficiencyTier(0).title, "Needs work")
        XCTAssertEqual(LibrarySectioning.proficiencyTier(1).title, "Needs work")
        XCTAssertEqual(LibrarySectioning.proficiencyTier(2).title, "Solid")
        XCTAssertEqual(LibrarySectioning.proficiencyTier(3).title, "Solid")
        XCTAssertEqual(LibrarySectioning.proficiencyTier(4).title, "Polished")
        XCTAssertEqual(LibrarySectioning.proficiencyTier(5).title, "Polished")
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

    // MARK: - sections: proficiency

    func testProficiencySectionsOrderedNeedsWorkFirst() {
        let result = sections([
            fields("Polished one", proficiency: 5),
            fields("Rough one", proficiency: 0),
            fields("Solid one", proficiency: 3)
        ], by: .proficiency)
        XCTAssertEqual(result.map(\.title), ["Needs work", "Solid", "Polished"])
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
