import Foundation

/// The weeks and months the Practice log can page back through (ADR 0241): every calendar period from
/// the one holding the first run to the one holding now, **oldest first**, so the current period is
/// always the last page and swiping right reaches further back.
///
/// **Calendar periods, never rolling windows.** A page is a week or a month the player can name and
/// come back to; "the last 30 days" is a different set of days every morning, so there would be no
/// page to return to. Each page is read with the same `PracticeProgress.week` / `.month` call the
/// current one has always used, handed a date inside it — so no boundary maths is written twice.
///
/// **The range is bounded both ways.** Nothing before the period you started in (there is nothing to
/// show, and an empty page you can scroll to indefinitely reads as a gap in your history), and nothing
/// after the current one (there is nothing to show there either).
enum PracticeLogPages {

    /// Which page a pager is showing, and where its step buttons go — the arithmetic both sections
    /// share, kept here so it is tested rather than re-derived in two views.
    struct Position: Equatable {
        /// Every period's start, oldest first. The last is the current period.
        let starts: [Date]
        /// Where the pager has settled, or `nil` before it has settled anywhere.
        let position: Date?

        /// The period on screen: the pager's position when it names a page, else the current period.
        /// A position that is no longer a page (the log was cleared while the screen was open) falls
        /// back to now rather than to nothing.
        var shown: Date? {
            if let position, starts.contains(position) { return position }
            return starts.last
        }

        var isCurrent: Bool { shown == starts.last }

        /// One period back, or `nil` on the first period you practised in.
        var earlier: Date? { index.flatMap { $0 > 0 ? starts[$0 - 1] : nil } }
        /// One period forward, or `nil` on the current period.
        var later: Date? { index.flatMap { $0 < starts.count - 1 ? starts[$0 + 1] : nil } }

        private var index: Int? { shown.flatMap { starts.firstIndex(of: $0) } }
    }

    /// The start of every calendar week from the week holding `since` to the week holding `now`,
    /// oldest first. Always holds at least the current week, so an empty log still has a page.
    static func weekStarts(since: Date?, now: Date, calendar: Calendar = .current) -> [Date] {
        starts(since: since, now: now) {
            PracticeLog.weekInterval(containing: $0, calendar: calendar)
        }
    }

    /// The first of every month from the month holding `since` to the month holding `now`, oldest
    /// first. Always holds at least the current month.
    static func monthStarts(since: Date?, now: Date, calendar: Calendar = .current) -> [Date] {
        starts(since: since, now: now) {
            PracticeLog.monthInterval(containing: $0, calendar: calendar)
        }
    }

    /// Walks period by period from `since`'s to `now`'s.
    ///
    /// Each step lands on the **end** of the previous period and re-reads the period that contains it,
    /// rather than adding a week or a month to a start date — the end is by definition the next
    /// period's start, so a 23- or 25-hour day at a clock change can't drift the walk off a boundary.
    /// A `since` after `now` (a clock set backwards) yields the current period alone.
    private static func starts(since: Date?,
                               now: Date,
                               interval: (Date) -> DateInterval) -> [Date] {
        let current = interval(now).start
        guard let since, since < current else { return [current] }
        var result: [Date] = []
        var cursor = interval(since)
        while cursor.start < current {
            result.append(cursor.start)
            let next = interval(cursor.end)
            guard next.start > cursor.start else { break }
            cursor = next
        }
        result.append(current)
        return result
    }
}
