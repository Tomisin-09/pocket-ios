import Foundation

/// The unified, read-only **Journal space** feed: journal notes (`JournalEntry`) and audio takes
/// (`Recording`) merged onto one newest-first timeline, across every owner (loop / exercise / song).
///
/// Pure and UI-free — like its sibling `JournalGrouping` — so the merge, scope filter, and
/// owner-label logic stays unit-testable without a SwiftData container. It reads only *properties*
/// of the models (never inserts a graph), so tests can build owners uninserted. The view layer
/// feeds `merge` → `filter` into `JournalGrouping.byDay` for day-sectioning.
enum JournalTimeline {

    /// One item on the feed — a written **note** or an audio **take**. Both carry a date and a
    /// polymorphic owner. `Identifiable` by the underlying model's stable `uid`.
    enum Item: Identifiable {
        case note(JournalEntry)
        case take(Recording)

        var id: UUID {
            switch self {
            case .note(let entry): entry.uid
            case .take(let take): take.uid
            }
        }

        /// When the item was written / recorded — the timeline sorts (and day-groups) on this.
        var date: Date {
            switch self {
            case .note(let entry): entry.createdAt
            case .take(let take): take.createdAt
            }
        }

        var isNote: Bool { if case .note = self { true } else { false } }
        var isTake: Bool { if case .take = self { true } else { false } }
    }

    /// Which items the feed shows. `all` is the default; `notes`/`takes` are the escape valve as
    /// the aggregate grows.
    enum Scope: CaseIterable {
        case all, notes, takes
    }

    /// Display order for the day-grouped feed. `newest` (default) is the reflective default; `oldest`
    /// walks the history forwards.
    enum SortOrder: CaseIterable {
        case newest, oldest
    }

    /// Merge notes + takes into one **newest-first** feed.
    static func merge(entries: [JournalEntry], takes: [Recording]) -> [Item] {
        let items = entries.map(Item.note) + takes.map(Item.take)
        return items.sorted { $0.date > $1.date }
    }

    /// Keep only the items the scope asks for (order preserved).
    static func filter(_ items: [Item], scope: Scope) -> [Item] {
        switch scope {
        case .all: items
        case .notes: items.filter(\.isNote)
        case .takes: items.filter(\.isTake)
        }
    }

    /// A human **owner label** for an item — the aggregated feed's attribution, since (unlike the
    /// per-owner `JournalSheet`) context isn't implicit here. A **loop** reads
    /// `"<song title> · <loop name>"` (bare loop name when it has no song); an **exercise** reads
    /// `"<name> · exercise"`; a **song**-owned take reads its title. `nil` for an orphaned item
    /// whose owner was cleared. UI-free.
    static func ownerLabel(for item: Item) -> String? {
        switch item {
        case .note(let entry): label(loop: entry.loop, exercise: entry.exercise, song: nil)
        case .take(let take): label(loop: take.loop, exercise: take.exercise, song: take.song)
        }
    }

    /// The exercise **template**'s display name for an item ("Scales", "Chords", …), or `nil` — loops,
    /// takes and songs have no template. Feeds the search index so a note can be found by its template.
    static func templateLabel(for item: Item) -> String? {
        switch item {
        case .note(let entry): entry.exercise?.template.displayName
        case .take(let take): take.exercise?.template.displayName
        }
    }

    /// The lowercased text a search matches against — the item's owner (song / loop / exercise name),
    /// its exercise template, and its date (abbreviated + long, e.g. "17 jul 2026" / "17 july 2026"),
    /// so a note can be found by song, exercise, template *or* date. UI-free.
    static func searchHaystack(for item: Item) -> String {
        var parts: [String] = []
        if let owner = ownerLabel(for: item) { parts.append(owner) }
        if let template = templateLabel(for: item) { parts.append(template) }
        parts.append(item.date.formatted(date: .abbreviated, time: .omitted))
        parts.append(item.date.formatted(date: .long, time: .omitted))
        return parts.joined(separator: " ").lowercased()
    }

    /// Keep the items matching a free-text `query` — **every** whitespace-separated token must appear
    /// in the item's haystack (so "scales jul" narrows to scale-template items in July). An empty or
    /// all-whitespace query keeps everything.
    static func filter(_ items: [Item], query: String) -> [Item] {
        let tokens = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return items }
        return items.filter { item in
            let haystack = searchHaystack(for: item)
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    private static func label(loop: Loop?, exercise: Exercise?, song: Song?) -> String? {
        if let loop {
            let loopName = loop.name.isEmpty ? "Loop" : loop.name
            if let title = loop.song?.title, !title.isEmpty { return "\(title) · \(loopName)" }
            return loopName
        }
        if let exercise {
            return "\(exercise.name.isEmpty ? "Exercise" : exercise.name) · exercise"
        }
        if let song {
            return song.title.isEmpty ? "Song" : song.title
        }
        return nil
    }
}
