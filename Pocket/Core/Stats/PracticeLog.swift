import Foundation

/// The pure **aggregation layer** over the practice log (ADR 0117): windowing, day buckets, sittings
/// and lifetime roll-ups over `[SessionRecord]` values.
///
/// UI-free and SwiftData-free on purpose. This is where the off-by-one lives — day boundaries, week
/// starts, the gap that separates one sitting from the next — and that is exactly the code that
/// breaks silently, so it is kept pure and unit-tested (AGENTS.md). Callers run their `@Query`, map to
/// `SessionRecord`, and hand the array here.
///
/// **Two rules the whole layer obeys.** A run is attributed wholly to the day (and window) it
/// *started* on, so one crossing midnight is never split or double-counted. And nothing here computes
/// a target, a denominator or a streak: ADR 0117 holds those with the deferred streak work, so every
/// number below describes what happened and prescribes nothing.
enum PracticeLog {

    /// How long a break has to be before the next run counts as a **new sitting** rather than a
    /// continuation of the current one. Thirty minutes: long enough that a swap of instrument, a
    /// re-tune or a coffee stays one session, short enough that morning and evening practice don't
    /// merge into a single implausible three-hour block.
    static let sittingGap: TimeInterval = 30 * 60

    // MARK: - Windows

    /// The records that fall inside `interval`, by their **start**. Sorted oldest-first, so every
    /// consumer below can assume order without re-sorting.
    static func records(in interval: DateInterval, from records: [SessionRecord]) -> [SessionRecord] {
        records
            .filter { interval.start <= $0.startedAt && $0.startedAt < interval.end }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// The calendar week containing `date`, honouring the calendar's own `firstWeekday` (Monday in
    /// most of the world, Sunday in the US) rather than hard-coding one — the week chart must start
    /// where the player's phone says the week starts.
    static func weekInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        interval(of: .weekOfYear, containing: date, calendar: calendar)
    }

    /// The calendar month containing `date` — the heatmap's window.
    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        interval(of: .month, containing: date, calendar: calendar)
    }

    /// The calendar day containing `date`.
    static func dayInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        interval(of: .day, containing: date, calendar: calendar)
    }

    /// Shared span lookup. `Calendar.dateInterval(of:for:)` is `Optional` for the exotic cases (a
    /// skipped day in a lunar calendar); falling back to the single day containing `date` keeps every
    /// caller total rather than pushing an optional window through the whole layer.
    private static func interval(of component: Calendar.Component,
                                 containing date: Date,
                                 calendar: Calendar) -> DateInterval {
        if let found = calendar.dateInterval(of: component, for: date) { return found }
        let start = calendar.startOfDay(for: date)
        return DateInterval(start: start,
                            end: calendar.date(byAdding: .day, value: 1, to: start) ?? start)
    }

    // MARK: - Day buckets

    /// One day's worth of practice — the unit both the week bar chart and the month heatmap render.
    struct DayBucket: Equatable, Identifiable, Sendable {
        /// Start of the day, in the aggregating calendar.
        let day: Date
        let seconds: Double
        /// How many runs landed on this day — the heatmap's secondary texture.
        let runCount: Int

        var id: Date { day }
        /// Rounded from the day's own total, never by summing rounded runs — three 40-second runs are
        /// two minutes, not three.
        var minutes: Int { PracticeLog.minutes(seconds) }
        var isActive: Bool { runCount > 0 }
    }

    /// Every day start in `interval`, oldest first — the axis a chart draws even where nothing was
    /// practised. A week always yields seven entries so the chart keeps its shape on a quiet week.
    static func days(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return result
    }

    /// Bucket `records` by day across the whole of `interval` — **including empty days**, which is the
    /// point: a bar chart with gaps in it says something a list of active days can't.
    static func dailyBuckets(_ records: [SessionRecord],
                             in interval: DateInterval,
                             calendar: Calendar = .current) -> [DayBucket] {
        let windowed = self.records(in: interval, from: records)
        var seconds: [Date: Double] = [:]
        var counts: [Date: Int] = [:]
        for record in windowed {
            let day = calendar.startOfDay(for: record.startedAt)
            seconds[day, default: 0] += record.durationSeconds
            counts[day, default: 0] += 1
        }
        return days(in: interval, calendar: calendar).map { day in
            DayBucket(day: day, seconds: seconds[day] ?? 0, runCount: counts[day] ?? 0)
        }
    }

    /// How many days in the window saw any practice — reported as a **bare count**. ADR 0117 holds the
    /// "4 of 7" denominator with the deferred streak work: a denominator states a target of seven, and
    /// a target is habit-pressure under another name.
    static func daysActive(_ buckets: [DayBucket]) -> Int {
        buckets.lazy.filter(\.isActive).count
    }

    /// The busiest day in the window, or `nil` when nothing was practised. Ties resolve to the
    /// **earliest** day, so a re-render can't shuffle which one is called "best".
    static func bestDay(_ buckets: [DayBucket]) -> DayBucket? {
        buckets.filter(\.isActive).max { lhs, rhs in
            lhs.seconds == rhs.seconds ? lhs.day > rhs.day : lhs.seconds < rhs.seconds
        }
    }

    // MARK: - Sittings

    /// A **practice sit** — one or more unit-runs with no long break between them. Derived, never
    /// stored: the log records units, and this is how session-level stats are recovered from it.
    struct Sitting: Equatable, Identifiable, Sendable {
        let startedAt: Date
        let endedAt: Date
        /// Time actually spent *running*, not wall-clock start-to-end — the gaps between blocks of a
        /// routine are not practice, and counting them would inflate every total.
        let seconds: Double
        let runCount: Int

        var id: Date { startedAt }
        var minutes: Int { PracticeLog.minutes(seconds) }
    }

    /// Group runs into sittings on time. Two runs belong to the same sit when the second starts within
    /// `gap` of the **end** of the previous one — measured from the end, so a long block followed
    /// immediately by another stays one sitting however long the first ran.
    static func sittings(_ records: [SessionRecord], gap: TimeInterval = sittingGap) -> [Sitting] {
        let ordered = records.sorted { $0.startedAt < $1.startedAt }
        var result: [Sitting] = []
        var start: Date?
        var end = Date.distantPast
        var seconds = 0.0
        var count = 0

        func flush() {
            guard let start, count > 0 else { return }
            result.append(Sitting(startedAt: start, endedAt: end, seconds: seconds, runCount: count))
        }

        for record in ordered {
            if start != nil, record.startedAt.timeIntervalSince(end) <= gap {
                end = max(end, record.endedAt)
                seconds += record.durationSeconds
                count += 1
            } else {
                flush()
                start = record.startedAt
                end = record.endedAt
                seconds = record.durationSeconds
                count = 1
            }
        }
        flush()
        return result
    }

    // MARK: - Roll-ups

    /// The all-time read: hours, sittings, runs, and the date practice started. `since` is `nil` on an
    /// empty log — the All-time surface has to say something honest on a fresh install rather than
    /// invent a start date of "now".
    struct Lifetime: Equatable, Sendable {
        var totalSeconds: Double = 0
        var sittingCount: Int = 0
        var runCount: Int = 0
        var since: Date?

        var isEmpty: Bool { runCount == 0 }
        var minutes: Int { PracticeLog.minutes(totalSeconds) }
        /// Whole hours — the headline framing ("87 hours"). Derived from `minutes`, **not** from the
        /// raw seconds, so all-time speaks the same rounded minutes the week and month do. Truncating
        /// the seconds instead made the two disagree on screen: a lifetime ten seconds short of two
        /// hours rounds to "120 minutes" in the month section and floored to "1 hour" right below it,
        /// which reads as all-time being *smaller* than the month inside it. Same input, one rounding
        /// rule, one answer. The cost is that a milestone can light up to 30 seconds early — far
        /// cheaper than a headline that contradicts the section above it.
        var hours: Int { minutes / 60 }
        /// Minutes past the whole hour, for the "2 hours 55 minutes" reading. Hours alone discard up
        /// to 59 minutes, which is invisible at 87 hours and half the number at two.
        var remainingMinutes: Int { minutes % 60 }
    }

    static func lifetime(_ records: [SessionRecord], gap: TimeInterval = sittingGap) -> Lifetime {
        guard !records.isEmpty else { return Lifetime() }
        return Lifetime(totalSeconds: totalSeconds(records),
                        sittingCount: sittings(records, gap: gap).count,
                        runCount: records.count,
                        since: records.min { $0.startedAt < $1.startedAt }?.startedAt)
    }

    /// Total seconds across the given records — the one place duration is summed.
    static func totalSeconds(_ records: [SessionRecord]) -> Double {
        records.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Total minutes across the given records, rounded once from the summed seconds.
    static func totalMinutes(_ records: [SessionRecord]) -> Int {
        minutes(totalSeconds(records))
    }

    /// Seconds → whole minutes, rounded to nearest. The single rounding rule, so a day bucket, a
    /// sitting and a window total can't disagree about what 90 seconds is.
    static func minutes(_ seconds: Double) -> Int {
        Int((max(0, seconds) / 60).rounded())
    }

    // MARK: - Recency

    /// When each **unit** was last practised — the map the planner ranks recency on (ADR 0137).
    ///
    /// This is the log's second job. Every stat above describes *how much*; this one answers *how long
    /// ago*, for one unit at a time, because `Loop` carries no `lastPracticed` field of its own and the
    /// planner would otherwise rank every loop as never-practised forever.
    ///
    /// **Rows with no `unitUID` are skipped.** A play-along logs `nil` — `Song` is identified by its
    /// `SongRef`, not a business `uid` (ADR 0117) — and a row that names no unit can say nothing about
    /// one. Songs keep their own stored `lastPracticed`; nothing here is needed for them.
    ///
    /// **Every kind counts, and the mode is not distinguished** (ADR 0137 D2a): an `.earLoop` row makes
    /// its loop less due as a trainer, and an `.improvise` row will too. The question is *when did you
    /// last work on this material*, not *in which mode* — per-kind recency would let a loop you sang
    /// back yesterday claim to be untouched and resurface it against one you genuinely haven't seen.
    ///
    /// **Completed runs only**, which is the whole log: a hand-stopped run writes no row
    /// (`PracticeLogWriter`), so this measures work done rather than screens opened (D4). Opening a
    /// drill and bailing does not reset its dueness.
    ///
    /// Latest wins. Built in one pass rather than by sorting — the caller hands over the entire log.
    static func lastPracticedByUnit(_ records: [SessionRecord]) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        for record in records {
            guard let unitUID = record.unitUID else { continue }
            if let seen = result[unitUID], seen >= record.startedAt { continue }
            result[unitUID] = record.startedAt
        }
        return result
    }
}
