import Foundation

/// How the song library is grouped and ordered (ADR 0035). The user picks one key;
/// the same cards re-bucket and re-sort under it. The raw value persists the choice.
enum SongGrouping: String, CaseIterable, Identifiable {
    case mastery, recentlyAdded, title, artist, album, genre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mastery: "Mastery"
        case .recentlyAdded: "Recently Added"
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .genre: "Genre"
        }
    }
}

/// The grouping-relevant projection of a `Song` — the only fields the sectioning needs.
/// Keeping it a plain value keeps `LibrarySectioning` SwiftData-free and unit-testable
/// (AGENTS.md: pure logic stays pure).
struct SongGroupFields {
    let title: String
    let artist: String
    let album: String
    let genre: String
    /// Derived song mastery (0–5), or `nil` when the song has no loops ("unrated"). ADR 0036.
    let mastery: Int?
    let dateAdded: Date?
}

/// A rendered library section: a header and its already-ordered items.
struct LibrarySection<Item> {
    let title: String
    let items: [Item]
}

/// Pure grouping/sorting for the library list (ADR 0035). Generic over the item type
/// so it works on `[Song]` without importing SwiftData — the caller supplies a closure
/// projecting each item to its `SongGroupFields`. The bucket boundaries and section
/// ordering are the logic that breaks silently, so they're unit-tested.
enum LibrarySectioning {

    /// Group `items` under `grouping` into ordered sections, each with its items ordered.
    /// `ascending` is the natural order for the key (A→Z, newest-first, needs-work-first);
    /// `false` **flips the whole list** — section order and each section's item order are
    /// reversed — so the user can read it bottom-up (Z→A, oldest-first, polished-first).
    static func sections<Item>(
        _ items: [Item],
        by grouping: SongGrouping,
        ascending: Bool = true,
        now: Date = Date(),
        calendar: Calendar = .current,
        fields: (Item) -> SongGroupFields
    ) -> [LibrarySection<Item>] {
        var order: [String: Int] = [:]
        var buckets: [String: [(item: Item, fields: SongGroupFields)]] = [:]
        for item in items {
            let projected = fields(item)
            let key = sectionKey(for: grouping, fields: projected, now: now, calendar: calendar)
            order[key.title] = key.order
            buckets[key.title, default: []].append((item, projected))
        }

        let ascendingSections = buckets.keys
            .sorted { lhs, rhs in
                let lhsOrder = order[lhs] ?? 0, rhsOrder = order[rhs] ?? 0
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.caseInsensitiveCompare(rhs) == .orderedAscending
            }
            .map { title in
                let ordered = (buckets[title] ?? [])
                    .sorted { itemPrecedes($0, $1, grouping: grouping) }
                    .map(\.item)
                return LibrarySection(title: title, items: ordered)
            }

        guard !ascending else { return ascendingSections }
        return ascendingSections
            .reversed()
            .map { LibrarySection(title: $0.title, items: $0.items.reversed()) }
    }

    /// Whether a song matches a search `query` — a case- and diacritic-insensitive
    /// substring of its title or artist. An empty/whitespace query matches everything.
    static func matchesSearch(_ fields: SongGroupFields, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return contains(fields.title, trimmed) || contains(fields.artist, trimmed)
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    // MARK: - Bucket helpers (pure, individually tested)

    /// Derived mastery (0–5) → a practice tier, surfaced needs-work first. `nil` (a song
    /// with no loops) buckets as "Unrated", which sorts last (ADR 0036).
    static func masteryTier(_ mastery: Int?) -> (order: Int, title: String) {
        guard let mastery else { return (3, "Unrated") }
        switch mastery {
        case ...1: return (0, "Needs work")
        case 2...3: return (1, "Solid")
        default: return (2, "Polished")
        }
    }

    /// Import date → a recency bucket relative to `now`. `nil` (pre-0035 / demo) ⇒ Earlier.
    static func dateBucket(_ date: Date?, now: Date, calendar: Calendar) -> (order: Int, title: String) {
        guard let date else { return (2, "Earlier") }
        if calendar.isDate(date, inSameDayAs: now) { return (0, "Today") }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
            return (1, "This week")
        }
        return (2, "Earlier")
    }

    /// First-letter section for an alphabetical grouping: a capital letter (order 0),
    /// `#` for anything starting non-alphabetically (order 1), or `emptyTitle` when blank
    /// (order 2 — sorts to the bottom, e.g. "Unknown Artist").
    static func alphaSection(_ value: String, emptyTitle: String) -> (order: Int, title: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return (2, emptyTitle) }
        return first.isLetter ? (0, String(first).uppercased()) : (1, "#")
    }

    // MARK: - Private

    private static func sectionKey(for grouping: SongGrouping, fields: SongGroupFields,
                                   now: Date, calendar: Calendar) -> (order: Int, title: String) {
        switch grouping {
        case .mastery: masteryTier(fields.mastery)
        case .recentlyAdded: dateBucket(fields.dateAdded, now: now, calendar: calendar)
        case .title: alphaSection(fields.title, emptyTitle: "—")
        case .artist: alphaSection(fields.artist, emptyTitle: "Unknown Artist")
        case .album: alphaSection(fields.album, emptyTitle: "Unknown Album")
        case .genre: alphaSection(fields.genre, emptyTitle: "Unknown Genre")
        }
    }

    /// Order items *within* a section. Alphabetical groupings sort by the grouping field
    /// then title; Recently Added is newest-first (nil last); the rest sort by title.
    private static func itemPrecedes<Item>(_ lhs: (item: Item, fields: SongGroupFields),
                                           _ rhs: (item: Item, fields: SongGroupFields),
                                           grouping: SongGrouping) -> Bool {
        let left = lhs.fields, right = rhs.fields
        switch grouping {
        case .recentlyAdded:
            switch (left.dateAdded, right.dateAdded) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate: return lhsDate > rhsDate
            case (nil, .some): return false
            case (.some, nil): return true
            default: return byTitle(left, right)
            }
        case .artist: return bySecondary(left.artist, right.artist, then: left, right)
        case .album: return bySecondary(left.album, right.album, then: left, right)
        case .genre: return bySecondary(left.genre, right.genre, then: left, right)
        case .title, .mastery: return byTitle(left, right)
        }
    }

    private static func bySecondary(_ lhs: String, _ rhs: String,
                                    then leftFields: SongGroupFields, _ rightFields: SongGroupFields) -> Bool {
        let comparison = lhs.caseInsensitiveCompare(rhs)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        return byTitle(leftFields, rightFields)
    }

    private static func byTitle(_ lhs: SongGroupFields, _ rhs: SongGroupFields) -> Bool {
        lhs.title.caseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
