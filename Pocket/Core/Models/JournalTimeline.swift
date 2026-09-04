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

        /// Whether the player has pinned this item (ADR 0190). Polymorphic like `date`, because both
        /// models carry the column — the feed's verbs must not depend on which row you are on.
        var isPinned: Bool {
            switch self {
            case .note(let entry): entry.isPinned
            case .take(let take): take.isPinned
            }
        }
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

    /// Keep only the **pinned** items when the filter is on (order preserved); everything when it is
    /// off (ADR 0190 D4).
    ///
    /// A filter and never a sort. The feed is day-grouped, so floating pinned items to the top would
    /// have to render them under a day they did not happen in — or in a second band above the first
    /// section, which is two competing groupings on one list. Narrowing leaves the chronology alone,
    /// which is also what keeps the pin honest as a *review* verb: it changes what you can find, not
    /// what the record says.
    static func filter(_ items: [Item], pinnedOnly: Bool) -> [Item] {
        pinnedOnly ? items.filter(\.isPinned) : items
    }

    /// A human **owner label** for an item — the aggregated feed's attribution, since (unlike the
    /// per-owner `JournalSheet`) context isn't implicit here. A **loop** reads
    /// `"<song title> · <loop name>"` (bare loop name when it has no song); an **exercise** reads
    /// `"<name> · exercise"`; a **song**-owned take reads its title; a **session** note (ADR 0143)
    /// reads the routine's snapshotted name. `nil` for an orphaned item whose owner was cleared.
    /// UI-free.
    ///
    /// A session's name comes from the entry's own `routineNameAtEntry`, never from a lookup through
    /// `routineUID` — that is the point of snapshotting it. The routine may since have been renamed
    /// or deleted, and the entry still says what the sitting was called when it happened (ADR 0038).
    static func ownerLabel(for item: Item) -> String? {
        switch item {
        case .note(let entry):
            switch entry.ownerKind {
            case .session:
                let name = entry.routineNameAtEntry ?? ""
                return name.isEmpty ? "Routine session" : name
            case .standalone:
                // Never a caption, and stated as its own branch rather than left to fall through
                // (ADR 0155 §2). The shared branch below would reach the same `nil` today only
                // because `forStandalone` writes no `ownerLabelAtEntry` — resting on that would make
                // a caption one careless assignment away, and a standalone note attributed to a unit
                // is precisely the corruption this decision exists to prevent.
                return nil
            case .metronome:
                // A constant, not a snapshot (ADR 0160 §6): there is exactly one metronome, it is a
                // screen rather than a row, and it can be neither renamed nor deleted — so there is
                // nothing for `ownerLabelAtEntry` to protect the caption from. It also makes
                // "metronome" a search term, since `searchHaystack` folds this in.
                return "Metronome"
            case .exercise, .loop, .orphan:
                return ownerLabel(loop: entry.loop, exercise: entry.exercise, song: nil)
                    ?? entry.ownerLabelAtEntry
            }
        case .take(let take):
            return ownerLabel(loop: take.loop, exercise: take.exercise, song: take.song)
                ?? take.ownerLabelAtTake
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

    /// The lowercased text a search matches against — the item's owner (song / loop / exercise name,
    /// or a session's routine name), its exercise template, the **units a session was made of**, and
    /// its date (abbreviated + long, e.g. "17 jul 2026" / "17 july 2026"), so a note can be found by
    /// song, exercise, template, routine, a unit practised in it, *or* date. UI-free.
    ///
    /// The unit titles matter more than they look: a session note is the one entry whose text is
    /// *about* the sitting rather than about a drill, so searching a drill's name would otherwise
    /// never surface the session you played it in.
    static func searchHaystack(for item: Item) -> String {
        var parts: [String] = []
        if let owner = ownerLabel(for: item) { parts.append(owner) }
        if let template = templateLabel(for: item) { parts.append(template) }
        // A named take must be findable by its name — otherwise naming one makes it identifiable
        // everywhere except the search field that exists to find it.
        if case .take(let take) = item, let title = take.title { parts.append(title) }
        parts.append(contentsOf: practisedTitles(for: item))
        parts.append(item.date.formatted(date: .abbreviated, time: .omitted))
        parts.append(item.date.formatted(date: .long, time: .omitted))
        return parts.joined(separator: " ").lowercased()
    }

    /// The unit titles a **session** note snapshotted (ADR 0143); empty for every other item — a
    /// unit-owned entry has no `practisedUnitsRaw`, so this costs nothing on the common path.
    private static func practisedTitles(for item: Item) -> [String] {
        guard case .note(let entry) = item else { return [] }
        return entry.practisedUnits.map(\.title)
    }

    /// Keep the items matching a free-text `query` — **every** whitespace-separated token must appear
    /// in the item's haystack (so "scales jul" narrows to scale-template items in July). An empty or
    /// all-whitespace query keeps everything.
    ///
    /// Token-AND is this feed's own semantics and is deliberately preserved; what it delegates is the
    /// per-token *substring* rule, which is `TextMatch`'s and shared with every other search field.
    /// Before that, this was the one matcher in the app that folded case but not diacritics.
    static func filter(_ items: [Item], query: String) -> [Item] {
        guard !query.split(whereSeparator: \.isWhitespace).isEmpty else { return items }
        return items.filter { TextMatch.matchesAllTokens(searchHaystack(for: $0), query: query) }
    }

    /// The owner label for a live owner — **also the snapshot** taken at write time (ADR 0151), so
    /// the caption a surviving take or note falls back to is byte-identical to the one it showed
    /// while its owner existed. Internal rather than private for exactly that reason: two
    /// derivations of the same string would drift the first time either is edited.
    static func ownerLabel(loop: Loop?, exercise: Exercise?, song: Song?) -> String? {
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
