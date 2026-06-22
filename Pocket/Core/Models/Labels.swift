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
    /// `selected` matches everything (no filter). The common single-select case is
    /// AND-of-one — tap a collection, get its items. Drives the library filter (ADR 0033).
    static func matches(_ itemLabels: [String], allOf selected: [String]) -> Bool {
        let have = Set(normalized(itemLabels).map { $0.lowercased() })
        return normalized(selected).allSatisfy { have.contains($0.lowercased()) }
    }
}
