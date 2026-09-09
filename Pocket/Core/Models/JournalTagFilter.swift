import Foundation

/// **The Journal feed's tag facet** (ADR 0207 D11) — which `EntryKind` tags the feed shows.
///
/// ### Why this ships now, when ADR 0190 D5 said it should not
///
/// D5 deferred exactly this control, and its reasoning was about **data, not design**: `.note` is the
/// default and the composer *offers* the tag rather than requiring it, so a filter over the field
/// would mostly separate *"the player picked a chip"* from *"the player didn't"*. D5 closed by naming
/// the condition for shipping — *"ship it when there is a reason to believe the field is populated
/// deliberately"*.
///
/// Two things now answer it. **Only `.note` is ever a default**: nothing in the app writes 🎯, ⚡️,
/// 🧗, 💡, 👂 or 🎸 on a player's behalf, so every one of those is a chip somebody tapped. And the
/// one bucket that *is* untrustworthy says so on its own row — **"Note or untagged"** — which turns
/// D5's objection from a hidden defect into the row's own label.
///
/// `.session` is the exception and is **not offered**. It is the one tag the app sets itself
/// (`RoutinePlayerView+Finished`), so it is not a deliberate mark; and it would sit one section above
/// the owner facet's own **Session** row meaning very nearly the same thing, which is two controls
/// that look like a choice and are not.
///
/// ### Shape
///
/// Mirrors `OwnerSelection` deliberately — an empty set means "everything", ticking widens (ADR 0159:
/// *OR within a facet, AND across facets*), and the raw string is written in a fixed order so it does
/// not churn `UserDefaults` between runs. Two facets over one feed should not have two grammars.
///
/// Pure and UI-free like the rest of `JournalTimeline`: it reads model *properties* only.
extension JournalTimeline {

    /// The tags the player has ticked — a union, not an intersection, for the same reason
    /// `OwnerSelection` is: an entry carries exactly one tag, so an intersection of two would always
    /// be empty and the second tick would clear the screen every time.
    struct TagSelection: RawRepresentable, Equatable {
        var tags: Set<EntryKind>

        /// The unfiltered feed. A `static let` both this type and the view's `@AppStorage`
        /// initialiser read — a declared literal is what SwiftUI actually uses for an unset key.
        static let `default` = TagSelection()

        /// The tags the filter offers, in menu order. `EntryKind.pickerOrder` minus `.session` — see
        /// this extension's note for why that one is left out. **This is also the order the stored
        /// string is written in**, so the raw value is stable across runs.
        static let offered: [EntryKind] = EntryKind.pickerOrder.filter { $0 != .session }

        /// What a row calls a tag **in this control**, which is not always what the chip calls it.
        ///
        /// `.note` is *"Note or untagged"* because the filter cannot tell the two apart and must not
        /// pretend to: `EntryKind.default` is `.note`, so this bucket holds both the notes somebody
        /// tagged 📝 and every note nobody tagged at all. Naming that on the row is what makes the
        /// facet honest enough to ship at all (ADR 0190 D5).
        static func label(for tag: EntryKind) -> String {
            tag == .note ? "Note or untagged" : tag.label
        }

        init(_ tags: Set<EntryKind> = []) {
            self.tags = tags
        }

        /// Parses the stored string, **dropping anything it doesn't recognise or no longer offers**.
        ///
        /// Non-failing, like `OwnerSelection`: `@AppStorage` falls back to its default only when the
        /// key is *absent*, not when the value fails to parse, so a failable init would leave a nil
        /// binding on a garbled value. Dropping unknown tokens degrades to the unfiltered feed, the
        /// one state that is always safe to land in — and it is what makes a stored `session` from a
        /// future or hand-edited value fall away rather than filter to a row the sheet cannot untick.
        init(rawValue: String) {
            let offered = Set(Self.offered)
            tags = Set(rawValue.split(separator: ",")
                .compactMap { EntryKind(rawValue: String($0)) }
                .filter(offered.contains))
        }

        /// Written in `offered` order, never in the set's own — a `Set` has no order, so joining it
        /// directly would write a different string for the same selection between runs.
        var rawValue: String {
            Self.offered.filter(tags.contains).map(\.rawValue).joined(separator: ",")
        }

        var isFiltering: Bool { !tags.isEmpty }

        /// Whether an item survives the filter.
        ///
        /// **A take never does while this is on**, and that is the decision rather than an oversight.
        /// A take has no `EntryKind` at all — not an unknown one, none — so it falls under no ticked
        /// tag, exactly as an orphaned note falls under no owner kind (ADR 0190 D6). The alternative,
        /// letting takes through a facet they cannot participate in, would mean a filter that says
        /// *Idea* and shows rows that are not ideas.
        ///
        /// It is why the empty state has to name this filter by its own name: a player on **Takes**
        /// with a tag ticked is looking at a screen that can never fill, and the screen has to say so.
        func matches(_ item: Item) -> Bool {
            guard isFiltering else { return true }
            guard case .note(let entry) = item else { return false }
            return tags.contains(entry.kind)
        }

        mutating func toggle(_ tag: EntryKind) {
            if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
        }

        /// The ticked tags as a phrase — *"Idea"*, *"Idea or Struggle"* — or `nil` when none are.
        /// "or", because the relation is the part a player cannot see (ADR 0159 §3).
        var phrase: String? {
            let labels = Self.offered.filter(tags.contains).map(Self.label(for:))
            guard !labels.isEmpty else { return nil }
            return labels.formatted(.list(type: .or))
        }

        /// The same thing, short enough for a chip: the phrase up to two tags, a count beyond that.
        /// **"tags", where the owner facet says "kinds"** — the two summaries can appear side by side
        /// on one chip, and a count that did not say which facet it counted would be unreadable.
        var summary: String? {
            guard isFiltering else { return nil }
            return tags.count <= 2 ? phrase : "\(tags.count) tags"
        }
    }

    /// Keep only the items whose **tag** the selection asks for (order preserved); everything under an
    /// empty selection.
    ///
    /// A fifth independent axis alongside scope, owner, pinned and query — all five compose in the
    /// view's `items` under ADR 0159's rule, *OR within a facet, AND across facets*.
    static func filter(_ items: [Item], tags: TagSelection) -> [Item] {
        guard tags.isFiltering else { return items }
        return items.filter(tags.matches)
    }
}
