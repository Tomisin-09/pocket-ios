import Foundation

/// Canonicalisation for the app's `[String]` label axes — song **Collections**
/// (ADR 0033) and loop **Tags** (ADR 0034). Scope-agnostic on purpose: it operates
/// on plain strings, not on `Song`/`Loop`, so both axes route through *one*
/// normaliser and never drift (ADR 0034 records this as a build constraint).
///
/// Pure and UI-free per AGENTS.md, so the rules that actually prevent fragmentation
/// — whitespace canonicalisation and case-insensitive de-duplication — are
/// unit-tested independently of SwiftData and SwiftUI.
enum Labels {

    /// The canonical form of a single label, or `nil` when it carries no content:
    /// leading/trailing whitespace trimmed and internal whitespace runs collapsed to
    /// one space. Empty (or whitespace-only) input ⇒ `nil` (rejected, not stored).
    static func canonical(_ raw: String) -> String? {
        let collapsed = raw
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    /// `existing` with `raw` added in canonical form — unless it is empty or already
    /// present **case-insensitively**, in which case `existing` is returned unchanged
    /// (the first-seen display form is preserved: adding "blues" when "Blues" exists
    /// is a no-op). This is the guard that keeps a label set from splintering into
    /// `Blues` / `blues` / `blues `.
    static func adding(_ raw: String, to existing: [String]) -> [String] {
        guard let label = canonical(raw) else { return existing }
        let folded = label.lowercased()
        guard !existing.contains(where: { $0.lowercased() == folded }) else { return existing }
        return existing + [label]
    }

    /// `list` canonicalised end-to-end: each entry normalised, empties dropped, and
    /// case-insensitively de-duplicated keeping the **first-seen** display form.
    /// Order is otherwise preserved. Use to clean a whole stored array (e.g. a set
    /// fragmented before normalisation shipped).
    static func normalized(_ list: [String]) -> [String] {
        list.reduce(into: [String]()) { result, raw in
            result = adding(raw, to: result)
        }
    }

    /// The canonical form of a **single-valued** group-key field (song `genre`, ADR 0036)
    /// chosen against the library's existing values. Whitespace is canonicalised, and when an
    /// existing value matches case-insensitively the input folds onto that value's first-seen
    /// display form — so a group key doesn't splinter into `Blues` / `blues` the way an
    /// un-normalised string would. Empty (or whitespace-only) input ⇒ `""`: a single field keeps
    /// its unset state (which buckets as "Unknown Genre" in the library), unlike a tag, which is
    /// dropped. Pass `pool` as the *other* items' values (exclude the item being edited) so a
    /// deliberate case change of the only holder isn't folded back onto its old form.
    static func canonicalSingle(_ raw: String, against pool: [String]) -> String {
        guard let label = canonical(raw) else { return "" }
        let folded = label.lowercased()
        return normalized(pool).first { $0.lowercased() == folded } ?? label
    }

    /// Suggestion candidates for an editor: the distinct normalised labels drawn from
    /// `pool` (the labels already used across the library), **excluding** any already
    /// on the current item (`current`, matched case-insensitively), sorted
    /// case-insensitively. This is the convergence mechanism — offering the labels you
    /// already use so many items share the *same* one instead of re-typed variants.
    static func suggestions(from pool: [String], excluding current: [String]) -> [String] {
        let taken = Set(normalized(current).map { $0.lowercased() })
        return normalized(pool)
            .filter { !taken.contains($0.lowercased()) }
            .sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Whether `itemLabels` satisfies an **intersection (AND)** filter: true when the
    /// item carries *every* one of `selected` (matched case-insensitively). An empty
    /// `selected` matches everything (no filter).
    ///
    /// **No longer what the library filter uses** — ADR 0159 moved that to `anyOf` below. Kept
    /// because AND is still the right relation *across* facets (collection AND instrument AND
    /// favourite), which is the shape a combined filter will need, and because
    /// `CollectionSessionBuilder` asks it of a single label, where the two relations agree.
    static func matches(_ itemLabels: [String], allOf selected: [String]) -> Bool {
        let have = Set(normalized(itemLabels).map { $0.lowercased() })
        return normalized(selected).allSatisfy { have.contains($0.lowercased()) }
    }

    /// Whether `itemLabels` satisfies a **union (OR)** filter: true when the item carries *any* one
    /// of `selected` (matched case-insensitively). An empty `selected` matches everything (no
    /// filter), exactly as `allOf` does — "no filter" must not depend on which relation is asked.
    ///
    /// **This is what multi-select inside one facet means** (ADR 0159). ADR 0033 chose AND here, but
    /// the only case it argued was single-select — the one case where AND and OR are identical — so
    /// the multi-select behaviour was never really decided. Ticking two collections asks to see
    /// both; intersecting them asks for songs filed in both at once, which in a personal library is
    /// almost always nothing.
    static func matches(_ itemLabels: [String], anyOf selected: [String]) -> Bool {
        let selected = normalized(selected)
        guard !selected.isEmpty else { return true }
        let have = Set(normalized(itemLabels).map { $0.lowercased() })
        return selected.contains { have.contains($0.lowercased()) }
    }
}
