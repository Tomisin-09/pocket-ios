import Foundation

/// One choice offered by a picker surface — the shared shape behind `OptionListSection` (a bounded
/// set of options laid out in a `Form`) and `SearchablePickerList` (an unbounded library list you
/// search). Both render the same two lines, so they take the same item.
///
/// Generic over the selected `Value` and identified **by that value**, so a caller never has to
/// invent a parallel id and the two can never drift apart.
struct PickerItem<Value: Hashable>: Identifiable {
    /// What selecting this row means.
    let value: Value
    /// The row's first line.
    let title: String
    /// Optional second line — a song's artist, a time signature's musical context. Also searched.
    var context: String?

    var id: Value { value }
}

/// Matching for a searchable picker, kept pure and free of SwiftUI so the rule is unit-tested rather
/// than eyeballed through a text field (AGENTS.md).
///
/// **Diacritic- and case-insensitive, and it searches the context line too.** A player looking for a
/// song types what they remember, which is as often the artist as the title, and "Bjork" must find
/// "Björk" — a search that only matches the exact glyphs someone typed reads as a broken library
/// rather than as a strict one.
enum PickerSearch {

    /// Whether `item` should survive `query`. An empty or whitespace-only query matches everything,
    /// so a cleared search field restores the full list rather than emptying it.
    static func matches<Value>(_ item: PickerItem<Value>, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return contains(item.title, trimmed) || contains(item.context ?? "", trimmed)
    }

    /// `items` filtered by `query`, preserving the caller's order — the library's own sort is a
    /// decision the picker has no business re-making.
    static func filter<Value>(_ items: [PickerItem<Value>], query: String) -> [PickerItem<Value>] {
        items.filter { matches($0, query: query) }
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        TextMatch.contains(haystack, needle)
    }
}
