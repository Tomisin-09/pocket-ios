import Foundation

/// **The Journal feed's owner-kind facet** (ADR 0190 D5) — which kinds of thing the feed shows, and
/// the selection of them the player has made.
///
/// Split from `JournalTimeline` when the facet became **multi-select** (ADR 0190 D10). It is two
/// types rather than one enum with an `all` case, and that shape is the decision: a set that is
/// *empty* means "everything", so there is no `All` value competing with a selection to represent
/// the same state. `LibraryView`'s collection filter has always worked this way, and ADR 0159 §2
/// makes the symmetry explicit — clearing a filter must not behave differently from never having set
/// one.
///
/// Pure and UI-free, like the rest of `JournalTimeline`: it reads model *properties* only, so tests
/// can build owners uninserted.
extension JournalTimeline {

    /// One **owner kind** the feed can be narrowed to.
    ///
    /// Five kinds are offered. `.orphan` is deliberately **not** a case (D6): a note that outlives
    /// its unit keeps its caption (`ownerLabelAtEntry`, ADR 0151) but not which kind of unit it had
    /// been — `loop` and `exercise` both nullify to `.orphan` — so the app genuinely no longer knows,
    /// and offering *Loop* would be offering an answer it cannot give. An orphan therefore appears
    /// only in the unfiltered feed, and the empty state says so rather than hiding it.
    ///
    /// **Entry kind** (`EntryKind`) is the third axis and is *not* shipped (D5): its default is
    /// `.note` and the composer offers rather than requires it, so a filter over it would mostly
    /// separate "the player picked a chip" from "the player didn't".
    ///
    /// `String`-raw because the selection persists across `@AppStorage` (D8), and the raw values are
    /// the case names. **Declaration order is the menu order** and the order the stored string is
    /// written in — see `OwnerSelection.rawValue`.
    enum OwnerFilter: String, CaseIterable, Identifiable {
        case exercise
        case loop
        case session
        case metronome
        /// `.standalone` — a note about practice generally (ADR 0155), named in the player's words
        /// rather than the model's.
        case standalone

        var id: String { rawValue }

        var label: String {
            switch self {
            case .exercise: return "Exercise"
            case .loop: return "Loop"
            case .session: return "Session"
            case .metronome: return "Metronome"
            case .standalone: return "Just me"
            }
        }

        /// Which offered kind an item falls under, or `nil` for one that falls under **none** and so
        /// appears only in the unfiltered feed. One derivation, read by `OwnerSelection.matches` —
        /// two would drift.
        ///
        /// **A take is bucketed on the same axis as a note**, because the Journal space's premise is
        /// one feed (ADR 0100): filtering to *Loop* has to bring the loop's takes with its notes, or
        /// the control means something different depending on which rows a day happens to hold —
        /// the same reasoning that put the pin on both row kinds (D2). A take's owner is
        /// `Recording.OwnerKind`, a separate enum, so the mapping is written out rather than derived.
        ///
        /// `nil` covers three cases, and they are `nil` for three different reasons:
        /// - an **orphaned note**, whose kind the app genuinely no longer knows (D6);
        /// - an **ownerless take**, the take-shaped version of the same loss;
        /// - a **song**-owned take. No screen records one today (a song stage has no recorder, ADR
        ///   0179 D6) and `Song` is not one of D6's five kinds; when songs gain a recorder, this is
        ///   the line that has to grow a case rather than quietly keep falling through.
        static func bucket(for item: Item) -> OwnerFilter? {
            switch item {
            case .note(let entry): bucket(forNote: entry.ownerKind)
            case .take(let take): bucket(forTake: take.ownerKind)
            }
        }

        /// A note's kind, mapped onto the offered five. Split from `bucket(for:)` — the two model
        /// enums are exhaustive and unrelated, so one function over both trips the complexity rule
        /// and, more to the point, reads as one mapping when it is two.
        private static func bucket(forNote kind: JournalEntryOwnerKind) -> OwnerFilter? {
            switch kind {
            case .exercise: .exercise
            case .loop: .loop
            case .session: .session
            case .metronome: .metronome
            case .standalone: .standalone
            case .orphan: nil
            }
        }

        /// A take's kind, mapped onto the same five.
        private static func bucket(forTake kind: Recording.OwnerKind) -> OwnerFilter? {
            switch kind {
            case .exercise: .exercise
            case .loop: .loop
            case .song, .none: nil
            }
        }
    }

    /// The kinds the player has ticked — **a union, not an intersection** (ADR 0190 D10).
    ///
    /// Ticking a second kind **widens** the feed: an item shows if it matches *any* ticked kind. This
    /// is ADR 0159's rule — *OR within a facet, AND across facets* — and this facet is the first
    /// thing built under it since. The alternative is not merely surprising but useless: an item has
    /// exactly one owner kind, so an intersection of two would always return nothing, and the second
    /// tick would empty the screen every single time.
    ///
    /// **Empty means everything.** There is no `all` member, because a set that already represents
    /// "no constraint" by being empty does not need a value that means the same thing — two
    /// representations of one state is a bug waiting for the day they disagree. The sheet's *All* row
    /// is a *clear*, and it is checked exactly when nothing else is.
    struct OwnerSelection: RawRepresentable, Equatable {
        var kinds: Set<OwnerFilter>

        /// The unfiltered feed. A `static let` both this type and the view's `@AppStorage`
        /// initialiser read — a declared literal is what SwiftUI actually uses for an unset key, and
        /// a second literal that drifts from its accessor is a trap this project has already paid
        /// for.
        static let `default` = OwnerSelection()

        init(_ kinds: Set<OwnerFilter> = []) {
            self.kinds = kinds
        }

        /// Parses the stored string, **dropping anything it doesn't recognise**.
        ///
        /// Non-failing on purpose. `@AppStorage` falls back to the default only when the key is
        /// absent, not when its value fails to parse, so a failable init would leave a nil binding on
        /// a garbled value; dropping unknown tokens degrades to the unfiltered feed instead, which is
        /// the one state that is always safe to land in.
        ///
        /// It is also the whole migration from the single-select build. That key held one bare kind
        /// (`"session"`), which parses to a one-kind selection — the same feed the player left on —
        /// and the old `"all"` sentinel is not a case any more, so it drops to empty, which is
        /// exactly what it meant. No migration code, and none needed.
        init(rawValue: String) {
            kinds = Set(rawValue.split(separator: ",")
                .compactMap { OwnerFilter(rawValue: String($0)) })
        }

        /// Written in `allCases` order, never in the set's own. A `Set` has no order, so joining it
        /// directly would write a different string for the same selection between runs — churning
        /// `UserDefaults` and making any round-trip test pass or fail by hash seed.
        var rawValue: String {
            OwnerFilter.allCases.filter(kinds.contains).map(\.rawValue).joined(separator: ",")
        }

        /// Whether the feed is narrowed at all. Reads better than `!kinds.isEmpty` at every call site
        /// and keeps "empty means everything" stated in one place.
        var isFiltering: Bool { !kinds.isEmpty }

        /// Whether an item survives the filter. Everything survives an empty selection; an item with
        /// no bucket (an orphan, an ownerless or song-owned take) survives only an empty one.
        ///
        /// Note the consequence, which is deliberate: ticking **all five** kinds is not the same as
        /// ticking none. An orphan matches none of the five, so it is hidden by the first and shown
        /// by the second. That falls out of the union honestly — the five are the kinds the app can
        /// still name — and the empty state names the ticked kinds so the omission is legible.
        func matches(_ item: Item) -> Bool {
            guard isFiltering else { return true }
            guard let bucket = OwnerFilter.bucket(for: item) else { return false }
            return kinds.contains(bucket)
        }

        mutating func toggle(_ kind: OwnerFilter) {
            if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
        }

        /// The ticked kinds as a phrase — `"Loop"`, `"Loop or Session"`, `"Loop, Session or
        /// Metronome"` — or `nil` when nothing is ticked.
        ///
        /// **"or", because the relation is the part a player can't see.** ADR 0159's finding was that
        /// a filter which states the count and hides the relation ("Filtering by 2 collections")
        /// leaves the one question worth answering unanswered. Built with the system's list
        /// formatter rather than by hand so it stays right in a locale that punctuates lists
        /// differently.
        var phrase: String? {
            let labels = OwnerFilter.allCases.filter(kinds.contains).map(\.label)
            guard !labels.isEmpty else { return nil }
            return labels.formatted(.list(type: .or))
        }

        /// The same thing, short enough for a menu row: the phrase up to two kinds, a count beyond
        /// that. *"Exercise, Loop, Session or Metronome"* is true and does not fit on one.
        var summary: String? {
            guard isFiltering else { return nil }
            return kinds.count <= 2 ? phrase : "\(kinds.count) kinds"
        }
    }

    /// Keep only the items whose **owner kind** the selection asks for (order preserved); everything
    /// under an empty selection (ADR 0190 D5, D10).
    ///
    /// A fourth independent axis alongside scope, pinned and query — all four compose in the view's
    /// `items`, and all four read model *properties* only, which is what lets the tests keep building
    /// owners uninserted.
    static func filter(_ items: [Item], owner: OwnerSelection) -> [Item] {
        guard owner.isFiltering else { return items }
        return items.filter(owner.matches)
    }
}
