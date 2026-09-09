import Foundation

/// Pure, UI-free month arithmetic for the Journal's two date controls (ADR 0207): the **month rail**
/// above the feed, and the **month grid** behind *Jump to…*.
///
/// It exists as its own type for the reason `JournalGrouping` does — this is calendar logic, which is
/// where the silent bugs live (a locale whose week starts on Monday, a month whose first day is a
/// Saturday, February in a leap year), and none of it needs a view or a store to be exercised.
///
/// **Everything here reads days that are already start-of-day section keys** from
/// `JournalGrouping.byDay`, and every function takes its `Calendar` so tests can pin a locale
/// rather than inherit the machine's.
enum JournalMonthLayout {

    /// Start-of-month for whatever instant it is handed.
    ///
    /// The fallback cannot be reached with a Gregorian calendar — `year` + `month` always resolve —
    /// but `date(from:)` is optional and a crash here would be a worse way to record that than
    /// degrading to the day itself.
    static func month(containing day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: day))
            ?? calendar.startOfDay(for: day)
    }

    /// The distinct months present in `days`, **in the order they first appear**.
    ///
    /// Order is inherited rather than imposed, which is what makes one function serve both sort
    /// orders: `days` arrives as `JournalTabView.visibleDays` — the sections in display order — so
    /// `newest` yields months descending and `oldest` yields them ascending, with no second
    /// parameter and no way for the rail to disagree with the list beneath it.
    static func months(in days: [Date], calendar: Calendar = .current) -> [Date] {
        var seen: Set<Date> = []
        var ordered: [Date] = []
        for day in days {
            let monthStart = month(containing: day, calendar: calendar)
            if seen.insert(monthStart).inserted { ordered.append(monthStart) }
        }
        return ordered
    }

    /// The first day of `days` that falls in `month`, in the order `days` is given.
    ///
    /// **"First" means first on screen, not earliest in time** — the rail scrolls you to the top of a
    /// month, and which end that is depends on the sort. Reading it positionally out of the display
    /// order gets both for free; computing a min or a max would get one of them wrong.
    static func firstDay(inMonth month: Date, of days: [Date],
                         calendar: Calendar = .current) -> Date? {
        let target = self.month(containing: month, calendar: calendar)
        return days.first { self.month(containing: $0, calendar: calendar) == target }
    }

    /// One month laid out as calendar weeks, `nil` where a cell belongs to a neighbouring month.
    ///
    /// Rows are always seven wide and the last row is padded, so a caller can lay this out as a grid
    /// without measuring anything. **Leading blanks are computed against `calendar.firstWeekday`**,
    /// not against Sunday: the app ships wherever the App Store does, and a Monday-first locale
    /// rendered Sunday-first is a calendar that is wrong by one column all month.
    static func weeks(of month: Date, calendar: Calendar = .current) -> [[Date?]] {
        let start = self.month(containing: month, calendar: calendar)
        guard let dayCount = calendar.range(of: .day, in: .month, for: start)?.count else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        while !cells.count.isMultiple(of: 7) { cells.append(nil) }

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// The weekday column headings, rotated to start on the calendar's own first weekday.
    ///
    /// `veryShortStandaloneWeekdaySymbols` is Sunday-first regardless of locale, so it has to be
    /// rotated by hand — the same off-by-one column the layout above avoids, arriving through the
    /// headings instead of through the cells.
    static func weekdayInitials(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    /// Step one month, staying inside `bounds`. `nil` when the step would leave the journal's own
    /// span — which is what disables the grid's ‹ › and stops it offering a month with nothing in it.
    static func month(after month: Date, by step: Int, within bounds: [Date],
                      calendar: Calendar = .current) -> Date? {
        guard let moved = calendar.date(byAdding: .month, value: step,
                                        to: self.month(containing: month, calendar: calendar)),
              let earliest = bounds.min(), let latest = bounds.max() else { return nil }
        let target = self.month(containing: moved, calendar: calendar)
        let low = self.month(containing: earliest, calendar: calendar)
        let high = self.month(containing: latest, calendar: calendar)
        return (low...high).contains(target) ? target : nil
    }
}
