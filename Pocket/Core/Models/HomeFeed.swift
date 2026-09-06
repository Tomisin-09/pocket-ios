import Foundation

/// Pure, UI-free logic for the V1 **home hub** (ADR 0044 follow-on): the time-of-day
/// greeting bucket and the "recently practised" selection/ordering the screen shows. Kept
/// free of SwiftUI/SwiftData (it works over a `practicedAt` closure, not `Song` directly) so
/// the rules are unit-testable without a model container — the AGENTS.md "pure logic stays
/// pure" rule.
enum HomeFeed {

    /// Which part of the day it is, from a 24-hour clock hour. Drives the greeting line; the
    /// headline copy ("Ready to practice") is fixed, this only varies the lead-in.
    enum TimeOfDay {
        case morning, afternoon, evening, night

        /// 5–11 morning · 12–16 afternoon · 17–21 evening · else night. Hours outside 0...23
        /// fold via `((hour % 24) + 24) % 24` so a stray value still buckets sanely.
        static func at(hour: Int) -> TimeOfDay {
            switch ((hour % 24) + 24) % 24 {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<22: return .evening
            default: return .night
            }
        }

        /// The lead-in greeting shown above the headline, name-free.
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Late session"
            }
        }

        /// The lead-in greeting, personalised with the artist name when there is one (ADR 0113).
        /// A `nil`/blank name is first-class — it falls straight back to the name-free `greeting`,
        /// so an un-named profile reads exactly as before. Named copy stays in the Red Moon
        /// register: quiet, no exclamation marks, night reads "Late one, {name}". The name is
        /// trimmed; an all-whitespace name counts as unset.
        func greeting(name: String?) -> String {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmed, !trimmed.isEmpty else { return greeting }
            switch self {
            case .morning: return "Morning, \(trimmed)"
            case .afternoon: return "Afternoon, \(trimmed)"
            case .evening: return "Evening, \(trimmed)"
            case .night: return "Late one, \(trimmed)"
            }
        }
    }

    /// The single most-recently-practised item — the "Jump back in" subject — or `nil` when
    /// nothing has been practised yet (every `practicedAt` is `nil`). Generic over the item so
    /// it tests with plain values.
    static func mostRecentlyPracticed<Item>(_ items: [Item],
                                            practicedAt: (Item) -> Date?) -> Item? {
        items
            .compactMap { item in practicedAt(item).map { (item, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// The most-recently-practised items, newest first, capped at `limit` — the home hub's
    /// "recent routines" rail. Never-practised items (`practicedAt == nil`) are dropped entirely
    /// (the rail shows only things actually run), and ties break by `id` for a stable order. Generic
    /// over the item so it tests with plain values.
    static func recentlyPracticed<Item, Key: Comparable>(_ items: [Item],
                                                         limit: Int,
                                                         practicedAt: (Item) -> Date?,
                                                         id: (Item) -> Key) -> [Item] {
        guard limit > 0 else { return [] }
        return items
            .compactMap { item in practicedAt(item).map { (item, $0) } }
            .sorted { lhs, rhs in
                lhs.1 == rhs.1 ? id(lhs.0) < id(rhs.0) : lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    /// Items ordered for the home "Your songs" list: most-recently-practised first, then the
    /// never-practised ones, each group broken by a `title` key for a stable, predictable order
    /// (case-insensitive). Total and deterministic so the list doesn't reshuffle between renders.
    static func orderedForHome<Item>(_ items: [Item],
                                     practicedAt: (Item) -> Date?,
                                     title: (Item) -> String) -> [Item] {
        items.sorted { lhs, rhs in
            switch (practicedAt(lhs), practicedAt(rhs)) {
            case let (left?, right?):
                if left != right { return left > right }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return title(lhs).localizedCaseInsensitiveCompare(title(rhs)) == .orderedAscending
        }
    }
}

/// Which kind of unit Home's **Jump back in** card offers (ADR 0193) — the player's stated
/// preference, not a record of what happened. `RawRepresentable` with a `String` raw value so it
/// works directly with `@AppStorage`.
///
/// **`Loop` is absent on purpose.** `lastPracticed` exists on `Song`, `Routine` and `Exercise` and
/// nowhere else; giving `Loop` one to round the set out would be a schema change made for a card,
/// which is the trade ADR 0189's criteria exist to refuse.
enum JumpBackInPreference: String, CaseIterable, Identifiable {
    /// Whatever was touched last, of any kind — the default, and exactly what Home did before this
    /// setting existed.
    case mostRecent
    case song
    case routine
    case exercise

    static let `default` = JumpBackInPreference.mostRecent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mostRecent: return "Most recent"
        case .song: return "Song"
        case .routine: return "Routine"
        case .exercise: return "Exercise"
        }
    }

    /// The kind this preference pins the card to, or `nil` for `mostRecent`, which pins nothing.
    var pinnedKind: HomeFeed.ResumeKind? {
        switch self {
        case .mostRecent: return nil
        case .song: return .song
        case .routine: return .routine
        case .exercise: return .exercise
        }
    }
}

extension HomeFeed {

    /// Which kind of unit the "Jump back in" card ends up carrying.
    enum ResumeKind: String, CaseIterable {
        case song, routine, exercise
    }

    /// The kind the card should show, from the player's preference and the newest `lastPracticed`
    /// of each kind — or `nil` when nothing anywhere has been practised, which is the case where the
    /// card hides (as it always has on a fresh install).
    ///
    /// **A pinned preference that has nothing to show falls back to the most recent of any kind**
    /// rather than hiding the card. The alternative — honour the pin absolutely, blank the card —
    /// punishes a player for stating a preference before they own anything of that kind, and it is
    /// unobservable in the direction that matters: the moment a routine *is* practised, the pin
    /// takes over and never yields again.
    ///
    /// Ties break **song · routine · exercise**, the declaration order, matching
    /// `mostRecentlyPracticed`'s first-maximal rule so two surfaces reading the same instant can't
    /// disagree about which unit that instant belongs to.
    static func resumeKind(preference: JumpBackInPreference,
                           songPracticedAt: Date?,
                           routinePracticedAt: Date?,
                           exercisePracticedAt: Date?) -> ResumeKind? {
        let practiced: [(kind: ResumeKind, date: Date?)] = [
            (.song, songPracticedAt), (.routine, routinePracticedAt), (.exercise, exercisePracticedAt)
        ]
        if let pinned = preference.pinnedKind,
           practiced.contains(where: { $0.kind == pinned && $0.date != nil }) {
            return pinned
        }
        return practiced
            .compactMap { entry in entry.date.map { (entry.kind, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}
