import Foundation

/// Pure, UI-free grouping for the loop journal (ADR 0038). The journal sheet lists
/// entries under day headers ("Today", a date); this turns a flat list into ordered
/// day-sections so that logic stays unit-testable and free of SwiftUI/SwiftData.
///
/// Generic over the element so tests don't need a SwiftData container — pass any type
/// plus a closure that pulls its date. Days sort newest-first; entries within a day
/// sort newest-first too.
enum JournalGrouping {

    /// One day's worth of entries, newest entry first.
    struct DaySection<Element> {
        /// Start-of-day for the section (the calendar day all its entries fall on).
        let day: Date
        let entries: [Element]
    }

    /// Group `entries` into day-sections, newest day first.
    /// - Parameters:
    ///   - entries: the flat entry list (any order).
    ///   - calendar: calendar used to bucket by day (injectable for tests).
    ///   - date: pulls the timestamp from an element.
    static func byDay<Element>(_ entries: [Element],
                               calendar: Calendar = .current,
                               date: (Element) -> Date) -> [DaySection<Element>] {
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: date($0)) }
        return buckets
            .map { day, items in
                DaySection(day: day, entries: items.sorted { date($0) > date($1) })
            }
            .sorted { $0.day > $1.day }
    }
}
