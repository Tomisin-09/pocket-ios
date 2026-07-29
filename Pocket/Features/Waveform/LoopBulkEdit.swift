import Foundation

/// A **partial** edit applied across a selection of loops (ADR 0125): the practice
/// categories from the loop edit sheet — type, focus and tags — with every field able to
/// say "leave this alone."
///
/// The three-state fields are the whole point. `focus` is already `Int?` on the model,
/// where `nil` means *never triaged* (ADR 0039) — a real, meaningful value — so a bulk
/// edit needs a third state above "some value" and "nil" to mean *don't touch it*.
/// `FieldEdit` supplies it rather than a double optional, which reads as a typo at every
/// call site.
///
/// Pure (no SwiftData import beyond the model it writes into, no SwiftUI) so the merge
/// rules and the mixed-value reads are unit-testable.
struct LoopBulkEdit: Equatable {

    /// A field that either carries a new value or is left as it was.
    enum FieldEdit<Value: Equatable>: Equatable {
        case unchanged
        case set(Value)

        var value: Value? {
            if case let .set(value) = self { return value }
            return nil
        }
    }

    var loopType: FieldEdit<LoopType> = .unchanged
    /// `.set(nil)` clears the focus back to *not set*; `.unchanged` leaves each loop's own.
    var focus: FieldEdit<Int?> = .unchanged
    /// Tags are **additive**, not replaced: a selection's loops usually have their own
    /// descriptive tags worth keeping, and a bulk field that replaced them would quietly
    /// destroy work. Removal is explicit and only offers tags the selection actually has.
    var tagsToAdd: [String] = []
    var tagsToRemove: [String] = []

    /// True when applying this would change nothing — the sheet's Apply button reads it.
    var isEmpty: Bool {
        loopType == .unchanged && focus == .unchanged && tagsToAdd.isEmpty && tagsToRemove.isEmpty
    }

    /// Apply to one loop. Tags route through `Labels` so bulk-added tags canonicalise the
    /// same way hand-typed ones do (ADR 0034) — otherwise "Solo" and "solo" split.
    func apply(to loop: Loop) {
        if case let .set(type) = loopType { loop.loopType = type }
        if case let .set(newFocus) = focus { loop.focus = newFocus }
        var tags = loop.tags
        for tag in tagsToAdd { tags = Labels.adding(tag, to: tags) }
        if !tagsToRemove.isEmpty {
            let removing = Set(tagsToRemove.map { $0.lowercased() })
            tags.removeAll { removing.contains($0.lowercased()) }
        }
        loop.tags = tags
    }
}

/// Reads over a selection of loops — what the bulk sheet shows *before* you change
/// anything, and what the header's favourite control does.
enum LoopSelectionSummary {

    /// The value every selected loop shares, or `nil` when they differ (the sheet shows
    /// "Multiple"). An empty selection has no common value either.
    static func commonType(of loops: [Loop]) -> LoopType? {
        common(loops.map(\.loopType))
    }

    /// The shared focus. Double-optional by necessity: outer `nil` = they differ, inner
    /// `nil` = they agree on *not triaged*.
    static func commonFocus(of loops: [Loop]) -> Int?? {
        common(loops.map(\.focus))
    }

    /// Tags present on **every** selected loop — the ones "Remove" can meaningfully offer.
    static func sharedTags(of loops: [Loop]) -> [String] {
        guard let first = loops.first else { return [] }
        var shared = first.tags
        for loop in loops.dropFirst() {
            let theirs = Set(loop.tags.map { $0.lowercased() })
            shared.removeAll { !theirs.contains($0.lowercased()) }
        }
        return shared
    }

    /// Every tag on any selected loop, canonicalised — the "already applied" set the add
    /// field filters its suggestions against.
    static func anyTags(of loops: [Loop]) -> [String] {
        Labels.suggestions(from: loops.flatMap(\.tags), excluding: [])
    }

    /// What a bulk favourite tap should do: **favourite** unless every selected loop
    /// already is, in which case it unfavourites. One control, no ambiguity about what a
    /// mixed selection does — the majority-neutral rule is "make them all the same, and
    /// prefer adding," so a mixed selection never silently unstars anything.
    static func favoriteAction(for loops: [Loop]) -> Bool {
        !loops.allSatisfy(\.isFavorite)
    }

    private static func common<Value: Equatable>(_ values: [Value]) -> Value? {
        guard let first = values.first else { return nil }
        return values.allSatisfy { $0 == first } ? first : nil
    }
}
