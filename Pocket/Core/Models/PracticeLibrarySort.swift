import Foundation

/// How the **Loops** library inside Practice is ordered (ADR 0056). The user picks one key;
/// the same rows re-sort under it. The raw value persists the choice across launches.
enum LoopSortKey: String, CaseIterable, Identifiable {
    /// The loop's song title, then loop name — the default, so a song's loops read together.
    case song
    /// Loop name, A→Z.
    case name
    /// The measured command speed (× of original) — your fastest/slowest owned loops.
    case commandTempo
    /// How cleanly you own the loop (0–5, unrated last) — surfaces what needs work.
    case mastery

    var id: String { rawValue }

    /// Compact toolbar label (the sort menu spells out the active key).
    var label: String {
        switch self {
        case .song: "Song"
        case .name: "Name"
        case .commandTempo: "Command"
        case .mastery: "Mastery"
        }
    }
}

/// How the **Exercises** library inside Practice is ordered (ADR 0056). Exercises are
/// audio-free command drills — no song, no mastery — so the keys differ from loops.
enum ExerciseSortKey: String, CaseIterable, Identifiable {
    /// Exercise name, A→Z — the default.
    case name
    /// The command BPM — your highest/lowest drills.
    case commandTempo
    /// Newest first, by `Exercise.dateAdded`.
    case recentlyAdded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "Name"
        case .commandTempo: "Command"
        case .recentlyAdded: "Recently Added"
        }
    }
}

/// The sort-relevant projection of a `Loop` — the only fields the ordering needs. Keeping it a
/// plain value keeps `PracticeLibrarySort` SwiftData-free and unit-testable (AGENTS.md: pure
/// logic stays pure), mirroring `SongGroupFields`.
struct LoopSortFields {
    let name: String
    /// The loop's song title, or "" when detached.
    let songTitle: String
    /// The effective command speed (× of original) — `Loop.command`.
    let command: Double
    /// Cleanliness 0–5, or `nil` when never rated (sorts last ascending). ADR 0039.
    let mastery: Int?
}

/// The sort-relevant projection of an `Exercise` (see `LoopSortFields`).
struct ExerciseSortFields {
    let name: String
    /// The effective command BPM — `Exercise.command`.
    let command: Int
    let dateAdded: Date
}

/// Pure ordering + search for the two Practice unit libraries (ADR 0056). Generic over the item
/// type so it works on `[Loop]` / `[Exercise]` without importing SwiftData — the caller supplies a
/// closure projecting each item to its fields. `ascending` is the natural order for the key (A→Z,
/// low→high, needs-work first, newest first); `false` **flips the whole list**, ties included, so
/// the reversal is total and predictable (matching the song library, ADR 0035).
enum PracticeLibrarySort {

    // MARK: - Loops

    static func sortedLoops<Item>(_ items: [Item], by key: LoopSortKey, ascending: Bool,
                                  fields: (Item) -> LoopSortFields) -> [Item] {
        let ordered = items
            .map { (item: $0, fields: fields($0)) }
            .sorted { loopPrecedes($0.fields, $1.fields, key: key) }
        return (ascending ? ordered : ordered.reversed()).map(\.item)
    }

    /// Whether a loop matches a search `query` — a case- and diacritic-insensitive substring of its
    /// name or song title. An empty/whitespace query matches everything.
    static func loopMatches(_ fields: LoopSortFields, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return contains(fields.name, trimmed) || contains(fields.songTitle, trimmed)
    }

    /// Ascending comparator for loops; `name` is the tiebreaker on every key so the order is
    /// deterministic (the descending flip then reverses ties too, ADR 0035).
    private static func loopPrecedes(_ lhs: LoopSortFields, _ rhs: LoopSortFields,
                                     key: LoopSortKey) -> Bool {
        switch key {
        case .song:
            let comparison = lhs.songTitle.caseInsensitiveCompare(rhs.songTitle)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return byName(lhs, rhs)
        case .name:
            return byName(lhs, rhs)
        case .commandTempo:
            if lhs.command != rhs.command { return lhs.command < rhs.command }
            return byName(lhs, rhs)
        case .mastery:
            // Unrated (`nil`) reads as "unknown need" → sorts after every rating ascending.
            let left = lhs.mastery ?? Int.max, right = rhs.mastery ?? Int.max
            if left != right { return left < right }
            return byName(lhs, rhs)
        }
    }

    private static func byName(_ lhs: LoopSortFields, _ rhs: LoopSortFields) -> Bool {
        lhs.name.caseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    // MARK: - Exercises

    static func sortedExercises<Item>(_ items: [Item], by key: ExerciseSortKey, ascending: Bool,
                                      fields: (Item) -> ExerciseSortFields) -> [Item] {
        let ordered = items
            .map { (item: $0, fields: fields($0)) }
            .sorted { exercisePrecedes($0.fields, $1.fields, key: key) }
        return (ascending ? ordered : ordered.reversed()).map(\.item)
    }

    /// Whether an exercise matches a search `query` — a case- and diacritic-insensitive substring
    /// of its name. Empty/whitespace matches everything.
    static func exerciseMatches(_ fields: ExerciseSortFields, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return contains(fields.name, trimmed)
    }

    private static func exercisePrecedes(_ lhs: ExerciseSortFields, _ rhs: ExerciseSortFields,
                                         key: ExerciseSortKey) -> Bool {
        switch key {
        case .name:
            return byName(lhs, rhs)
        case .commandTempo:
            if lhs.command != rhs.command { return lhs.command < rhs.command }
            return byName(lhs, rhs)
        case .recentlyAdded:
            // "Ascending" reads newest-first here (the natural order), matching the song library.
            if lhs.dateAdded != rhs.dateAdded { return lhs.dateAdded > rhs.dateAdded }
            return byName(lhs, rhs)
        }
    }

    private static func byName(_ lhs: ExerciseSortFields, _ rhs: ExerciseSortFields) -> Bool {
        lhs.name.caseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    // MARK: - Shared

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
