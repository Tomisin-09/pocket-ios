import Foundation

/// Which sections of a grouped library list are **collapsed**, and how that survives a launch
/// (v2 close-out Slice 5). Pure and Foundation-only, like the sectioning it accompanies — the
/// storage codec is the part that breaks silently, so it's unit-tested (AGENTS.md).
///
/// **Collapsed is the stored state, not expanded.** A section the player has never touched is open,
/// so a template bucket that appears later — a first Scales drill, a newly imported song's loops —
/// shows its contents without asking to be found. Storing "expanded" would make every new bucket
/// arrive shut.
///
/// Titles are user text (song titles group the loops library), so the set is persisted as **JSON**
/// rather than a joined string: a song called "A · B" would otherwise collapse two buckets at once.
/// A payload that fails to decode reads as "nothing collapsed" — the list is a browse surface, and
/// an unreadable preference should open it, never hide rows.
///
/// `scope` namespaces the titles for a list whose buckets change axis: the song library regroups by
/// mastery / artist / genre, where "A" under Artist and "A" under Title are different sections that
/// must not share one collapse. Lists with a fixed axis (exercises by template, loops by song) pass
/// no scope.
enum LibrarySectionExpansion {

    /// The collapsed titles held in `raw`, for `scope`. Unknown scopes read as empty — and an
    /// unscoped read skips every scoped key rather than returning it prefix and all, so the two
    /// forms can share one payload without either seeing the other's titles.
    static func collapsed(from raw: String, scope: String = "") -> Set<String> {
        let marker = prefix(scope)
        return Set(decode(raw)
            .filter { scope.isEmpty ? !$0.contains(separator) : $0.hasPrefix(marker) }
            .map { String($0.dropFirst(marker.count)) })
    }

    /// Whether `title` renders its rows. `searching` **forces every section open**: a query that
    /// matched rows inside a collapsed bucket would otherwise look like a search returning nothing,
    /// which is the one way a collapse can read as a bug rather than a choice.
    static func isExpanded(_ title: String, in raw: String, scope: String = "",
                           searching: Bool = false) -> Bool {
        searching || !collapsed(from: raw, scope: scope).contains(title)
    }

    /// `raw` with `title` set expanded or collapsed. Returns the new payload to store; every other
    /// title — and every other scope — in the payload is carried through untouched.
    static func setting(_ title: String, expanded: Bool, in raw: String,
                        scope: String = "") -> String {
        let key = prefix(scope) + title
        var keys = decode(raw).filter { $0 != key }
        if !expanded { keys.append(key) }
        return encode(keys)
    }

    // MARK: - Private

    /// The scope separator is a unit separator (U+001F) — a control character no title can contain,
    /// unlike any punctuation a song or template name might.
    private static let separator = "\u{1F}"

    private static func prefix(_ scope: String) -> String {
        scope.isEmpty ? "" : scope + separator
    }

    private static func decode(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let keys = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return keys
    }

    private static func encode(_ keys: [String]) -> String {
        guard let data = try? JSONEncoder().encode(keys),
              let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }
}
