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

        /// The lead-in greeting shown above the headline.
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Late session"
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
