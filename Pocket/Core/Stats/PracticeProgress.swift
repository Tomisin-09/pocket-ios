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

    /// Lifetime-hours marks worth noticing. Deliberately sparse and far apart — a wall you pass rather
    /// than a ladder you're being timed on — and expressed in hours, which only ever accumulate.
    static let hourMilestones = [10, 50, 100, 500]

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
        var peakMinutes: Int { max(1, days.lazy.map(\.minutes).max() ?? 0) }
    }

    /// **All-time** — meaningful from the second session, which is why it ships with the near
    /// horizons. Activity leads; the inventory counts are supporting texture, never the headline,
    /// because they measure library size and can go *down* when a drill is deleted.
    struct AllTime: Equatable, Sendable {
        let lifetime: PracticeLog.Lifetime
        let inventory: PracticeStats.Summary
        let milestones: [HoursMilestone]

        var isEmpty: Bool { lifetime.isEmpty }
        /// The next mark ahead, or `nil` once every one is behind you. Stated as a fact about the
        /// wall, never as a goal the player has been set.
        var nextMilestone: Int? { milestones.first { !$0.isReached }?.hours }
    }

    /// One mark on the hours wall.
    struct HoursMilestone: Equatable, Identifiable, Sendable {
        let hours: Int
        let isReached: Bool
        var id: Int { hours }
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

    static func allTime(records: [SessionRecord], inventory: PracticeStats.Summary) -> AllTime {
        let lifetime = PracticeLog.lifetime(records)
        return AllTime(lifetime: lifetime,
                       inventory: inventory,
                       milestones: milestones(forHours: lifetime.hours))
    }

    /// The hours wall at a given lifetime total. Every mark is always present — the ones ahead are
    /// shown unreached rather than hidden, so the wall doesn't rearrange itself as you pass them.
    static func milestones(forHours hours: Int) -> [HoursMilestone] {
        hourMilestones.map { HoursMilestone(hours: $0, isReached: hours >= $0) }
    }
}
