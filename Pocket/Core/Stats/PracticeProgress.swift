import Foundation

/// The **Progress screen's** whole read, computed in one pure pass (ADR 0117, Slice 2): This week,
/// This month and All-time, over `[SessionRecord]` values plus the derived inventory counts
/// `PracticeStats` already produces.
///
/// The view does no arithmetic. It runs its `@Query`s, maps to values, calls `summarize` once and
/// renders — which is what keeps three horizons' worth of boundary maths inside the tested pure layer
/// rather than scattered across three section views.
///
/// **This year is deliberately absent.** ADR 0117 defers the year tier and the "wrapped" card: a year
/// view over five weeks of history shows one month. There is no placeholder for it here — an empty
/// struct would invite someone to fill it in early.
///
/// **Nothing here is a target.** No goal, no denominator, no week-over-week delta, no streak: those
/// all travel with the deferred streak work because each is habit-pressure under a different name.
/// Every number below describes what happened.
enum PracticeProgress {

    // MARK: - Horizons

    /// **This week** — the shape of seven days. Legible on day two, which is why it leads.
    struct Week: Equatable, Sendable {
        let interval: DateInterval
        /// Always seven buckets, empty days included, so the chart keeps its shape on a quiet week.
        let days: [PracticeLog.DayBucket]
        let minutes: Int
        /// A bare count. ADR 0117 holds "4 of 7" with the streaks — a denominator states a target.
        let daysActive: Int

        var isEmpty: Bool { daysActive == 0 }
        /// The busiest day's minutes — the chart's y-scale. At least 1 so an all-zero week doesn't
        /// divide by zero, and so a single one-minute day doesn't draw a full-height bar.
        var peakMinutes: Int { max(1, days.lazy.map(\.minutes).max() ?? 0) }
        /// The week's practice as a figure — "<1 minute" when it rounds to nothing (ADR 0241).
        /// Summed from the buckets, which cover every day of the week and so every run in it.
        var minutesFigure: PracticeLog.MinutesFigure {
            .init(seconds: days.reduce(0) { $0 + $1.seconds })
        }
    }

    /// **This month** — the same aggregation as the week, bucketed differently. The most legible
    /// "am I showing up" artefact in the design once two or three weeks exist.
    struct Month: Equatable, Sendable {
        let interval: DateInterval
        let days: [PracticeLog.DayBucket]
        let minutes: Int
        let daysActive: Int
        let bestDay: PracticeLog.DayBucket?
        /// Runs this month that went faster than that drill had ever been logged at, at that rhythm.
        let newTempos: Int

        var isEmpty: Bool { daysActive == 0 }
        var minutesFigure: PracticeLog.MinutesFigure {
            .init(seconds: days.reduce(0) { $0 + $1.seconds })
        }

        /// The longest day **worth stating** — `nil` until the month has two active days (ADR 0241).
        /// With one, "Longest day" names the only day there is and repeats the figures above it.
        var longestDay: PracticeLog.DayBucket? { daysActive >= 2 ? bestDay : nil }

        // MARK: Shading (ADR 0268)

        /// How many shades a practised day can take. Four is as many as a small cell carries legibly.
        static let shadeCount = 4

        /// Where the darkest shade begins: the month's **typical practised day**, taken as the upper
        /// quartile of its practised days — not its longest (ADR 0268). Against the longest, one
        /// two-hour day turned a month of twenty-minute days pale. The quartile shrugs off up to a
        /// quarter of the days being unusually long, and it is not a number anyone chose, so it
        /// sets no target (ADR 0117).
        ///
        /// Nearest-rank, so it is always a day that happened. With three practised days or fewer
        /// that makes it the longest one: there is no "typical" to find in three. At least a second,
        /// so a month of zero-length runs can't divide by zero.
        var shadeScaleSeconds: Double {
            let practised = days.filter(\.isActive).map(\.seconds).sorted()
            guard !practised.isEmpty else { return 1 }
            let rank = Int((Double(practised.count) * 0.75).rounded(.up)) - 1
            return max(1, practised[rank])
        }

        /// Which shade a day takes, 0 (palest) to `shadeCount - 1` (darkest). `nil` for a day with no
        /// practice, which draws a distinct neutral rather than the palest shade, so "nothing" never
        /// reads as "a little". Any practice at all reaches the palest; anything at or past the scale
        /// is the darkest.
        func shade(of bucket: PracticeLog.DayBucket) -> Int? {
            guard bucket.isActive else { return nil }
            let fraction = bucket.seconds / shadeScaleSeconds
            let step = Int((fraction * Double(Self.shadeCount)).rounded(.up)) - 1
            return min(Self.shadeCount - 1, max(0, step))
        }
    }

    /// **One chosen day** (ADR 0269) — what the figures above the week chart or the month grid turn
    /// into while a day is tapped: the section's own figures, for that day alone. No days count,
    /// because one day is one day.
    struct Day: Equatable, Sendable {
        let interval: DateInterval
        /// The same bucket the chart and the grid draw for this day, so a figure can't disagree with
        /// the bar or the cell it was tapped from.
        let bucket: PracticeLog.DayBucket
        /// Runs that day that went faster than that drill had ever been logged at, at that rhythm.
        let newTempos: Int

        var minutesFigure: PracticeLog.MinutesFigure { .init(seconds: bucket.seconds) }
    }

    /// **All-time** — meaningful from the second session, which is why it ships with the near
    /// horizons. Activity leads; the inventory counts are supporting texture, never the headline,
    /// because they measure library size and can go *down* when a drill is deleted.
    ///
    /// **No hours wall.** It held 10, 50, 100 and 500 hours as marks passed or not yet, and ADR 0260
    /// D2 removed it: it sat directly under the lifetime figure and restated it.
    struct AllTime: Equatable, Sendable {
        let lifetime: PracticeLog.Lifetime
        let inventory: PracticeStats.Summary

        var isEmpty: Bool { lifetime.isEmpty }
    }

    /// The three horizons together.
    struct Summary: Equatable, Sendable {
        let week: Week
        let month: Month
        let allTime: AllTime

        /// Nothing has ever been logged — the fresh-install case each section answers in its own
        /// words rather than showing a wall of zeroes.
        var hasNoHistory: Bool { allTime.isEmpty }
    }

    // MARK: - The one entry point

    /// Roll the log into all three horizons.
    ///
    /// `inventory` is the existing derived count (`PracticeStats.summarize`), passed in rather than
    /// recomputed so the achievement wall and any other consumer can't drift apart. `now` and
    /// `calendar` are parameters, not `.now`/`.current`, so every boundary is testable.
    static func summarize(records: [SessionRecord],
                          inventory: PracticeStats.Summary,
                          now: Date = .now,
                          calendar: Calendar = .current) -> Summary {
        Summary(week: week(records: records, now: now, calendar: calendar),
                month: month(records: records, now: now, calendar: calendar),
                allTime: allTime(records: records, inventory: inventory))
    }

    static func week(records: [SessionRecord], now: Date, calendar: Calendar) -> Week {
        let interval = PracticeLog.weekInterval(containing: now, calendar: calendar)
        let days = PracticeLog.dailyBuckets(records, in: interval, calendar: calendar)
        return Week(interval: interval,
                    days: days,
                    minutes: PracticeLog.totalMinutes(PracticeLog.records(in: interval, from: records)),
                    daysActive: PracticeLog.daysActive(days))
    }

    static func month(records: [SessionRecord], now: Date, calendar: Calendar) -> Month {
        let interval = PracticeLog.monthInterval(containing: now, calendar: calendar)
        let days = PracticeLog.dailyBuckets(records, in: interval, calendar: calendar)
        return Month(interval: interval,
                     days: days,
                     minutes: PracticeLog.totalMinutes(PracticeLog.records(in: interval, from: records)),
                     daysActive: PracticeLog.daysActive(days),
                     bestDay: PracticeLog.bestDay(days),
                     // Measured against the whole log, not against this month — see `TempoRecord`.
                     newTempos: TempoRecord.entries(in: records, within: interval).count)
    }

    /// The day holding `date`, bucketed and measured the way the week and the month are.
    static func day(records: [SessionRecord], containing date: Date, calendar: Calendar) -> Day {
        let interval = PracticeLog.dayInterval(containing: date, calendar: calendar)
        let bucket = PracticeLog.dailyBuckets(records, in: interval, calendar: calendar).first
            ?? PracticeLog.DayBucket(day: interval.start, seconds: 0, runCount: 0)
        return Day(interval: interval,
                   bucket: bucket,
                   // Measured against the whole log, as the month's figure is — see `TempoRecord`.
                   newTempos: TempoRecord.entries(in: records, within: interval).count)
    }

    static func allTime(records: [SessionRecord], inventory: PracticeStats.Summary) -> AllTime {
        AllTime(lifetime: PracticeLog.lifetime(records), inventory: inventory)
    }
}
