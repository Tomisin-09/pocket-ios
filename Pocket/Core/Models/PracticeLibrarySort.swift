import Foundation

/// A library's sort axis — the key enum each practice library persists in `AppStorage`. Generalised
/// so the shared `LibrarySortPickers` can render any of them without knowing the concrete key.
/// Deliberately Foundation-only, like the rest of this file (AGENTS.md: pure logic stays pure).
protocol LibrarySortKey: CaseIterable, Identifiable, Hashable {
    /// The human label shown in the sort menu.
    var label: String { get }
}

/// How the **Loops** library inside Practice is ordered (ADR 0056). The user picks one key;
/// the same rows re-sort under it. The raw value persists the choice across launches.
enum LoopSortKey: String, CaseIterable, Identifiable, LibrarySortKey {
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
enum ExerciseSortKey: String, CaseIterable, Identifiable, LibrarySortKey {
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
    /// Notes played per beat — `Exercise.noteRate`, defaulted to 1 so sort-only call sites keep
    /// compiling and an exercise that declares no rhythm compares as its bare BPM. The Command key
    /// ranks on `notesPerMinute`, not on `command`: 80 BPM at sixteenths and 80 at quarters are a
    /// 4× difference the raw BPM reads as a tie (device pass 2026-07-29).
    var notesPerBeat: Int = 1
    /// The exercise template's display name (ADR 0068, revised) — the library **section** key
    /// (Strumming, Scales, Basic, …). Defaulted so sort-only call sites keep compiling.
    var templateName: String = ExerciseTemplate.basic.displayName
    /// The template's SF Symbol, drawn on the section header so a bucket is recognisable before it is
    /// read. Defaulted alongside `templateName` so sort-only call sites keep compiling.
    var templateIcon: String = ExerciseTemplate.basic.iconName
    /// The exercise's instrument (ADR 0116 S4) — the axis the Library's progressive-disclosure filter
    /// narrows on. Defaulted to guitar so sort-only call sites keep compiling.
    var instrument: Instrument = .guitar

    /// The command tempo normalised by its rhythm — `command × notesPerBeat`. **A comparison aid, not
    /// a difficulty score** (see `NoteRate`): it makes two commands rankable, it does not say which
    /// drill is harder.
    var commandNotesPerMinute: Int { max(0, command) * max(1, notesPerBeat) }
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

    /// Group loops into **song sections** (v2 close-out Slice 5), each section's items ordered by the
    /// chosen sort `key`/`ascending`. Songs run A→Z with **"No song" last**, matching the
    /// `AddRoutineUnitSheet` bucket grammar this list is meant to echo — a detached loop is a
    /// leftover, not a song called nothing, so it sinks rather than sorting under the empty string.
    ///
    /// Section order does **not** follow `ascending`: it orders the items inside a section, exactly
    /// as `exerciseSections` treats its template buckets. Grouping is an axis of its own — the sort
    /// says how a song's loops read, not which song comes first.
    static func loopSections<Item>(_ items: [Item], sortedBy key: LoopSortKey, ascending: Bool,
                                   fields: (Item) -> LoopSortFields) -> [LibrarySection<Item>] {
        var buckets: [String: [Item]] = [:]
        for item in items {
            buckets[fields(item).songTitle, default: []].append(item)
        }
        return buckets.keys
            .sorted { lhs, rhs in
                if lhs.isEmpty != rhs.isEmpty { return !lhs.isEmpty }
                return lhs.caseInsensitiveCompare(rhs) == .orderedAscending
            }
            .map { title in
                let ordered = sortedLoops(buckets[title] ?? [], by: key,
                                          ascending: ascending, fields: fields)
                return LibrarySection(title: title.isEmpty ? noSongSection : title, items: ordered)
            }
    }

    /// The section a loop with no song lands in. Named rather than inlined because it is both the
    /// header text and the key the collapse state persists under.
    static let noSongSection = "No song"

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

    /// Group exercises into **template sections** (ADR 0068, revised), each section's items ordered
    /// by the chosen sort `key`/`ascending`. Sections are ordered alphabetically by the template's
    /// display name. Every exercise resolves to exactly one template (`.basic` is a real section,
    /// not a leftover bucket), so there is no empty/"Uncategorized" case to special-case. Pure — the
    /// bucket boundaries and ordering are the logic that breaks silently, so they're unit-tested
    /// (mirrors `LibrarySectioning`).
    static func exerciseSections<Item>(_ items: [Item], sortedBy key: ExerciseSortKey,
                                       ascending: Bool,
                                       fields: (Item) -> ExerciseSortFields) -> [LibrarySection<Item>] {
        var buckets: [String: [Item]] = [:]
        // The section's icon rides along with its name, keyed by the same bucket. Carrying it here
        // beats reverse-mapping a display name back to a template at the view: the bucket key *is* a
        // display name, so that lookup would break the moment two templates read alike.
        var icons: [String: String] = [:]
        for item in items {
            let itemFields = fields(item)
            buckets[itemFields.templateName, default: []].append(item)
            icons[itemFields.templateName] = itemFields.templateIcon
        }
        return buckets.keys
            .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
            .map { title in
                let ordered = sortedExercises(buckets[title] ?? [], by: key,
                                              ascending: ascending, fields: fields)
                return LibrarySection(title: title, items: ordered, icon: icons[title])
            }
    }

    /// Whether an exercise matches the active Library filters — the search `query` (a case- and
    /// diacritic-insensitive substring of its name; empty/whitespace matches everything) **and** the
    /// optional `instrument` filter (ADR 0116 S4; `nil` = "All", matches every instrument).
    static func exerciseMatches(_ fields: ExerciseSortFields, query: String,
                                instrument: Instrument? = nil) -> Bool {
        if let instrument, fields.instrument != instrument { return false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return contains(fields.name, trimmed)
    }

    /// The distinct instruments present across `instruments`, in canonical enum order (guitar, bass) —
    /// the input to the Library's **progressive-disclosure** instrument filter (ADR 0116 S4): the
    /// filter appears only when this returns more than one, so a single-instrument player never sees
    /// it. Pure so the disclosure threshold — the bit that silently over- or under-shows the control —
    /// is unit-tested.
    static func instrumentsPresent(_ instruments: [Instrument]) -> [Instrument] {
        Instrument.allCases.filter { instruments.contains($0) }
    }

    private static func exercisePrecedes(_ lhs: ExerciseSortFields, _ rhs: ExerciseSortFields,
                                         key: ExerciseSortKey) -> Bool {
        switch key {
        case .name:
            return byName(lhs, rhs)
        case .commandTempo:
            // Ranked on notes-per-minute, so a slower BPM at a denser rhythm sorts above a faster one
            // at quarters — the raw BPMs are not comparable across rhythms. Bare BPM stays the first
            // tiebreaker, so two drills at the same note speed still order by the number on screen.
            if lhs.commandNotesPerMinute != rhs.commandNotesPerMinute {
                return lhs.commandNotesPerMinute < rhs.commandNotesPerMinute
            }
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
