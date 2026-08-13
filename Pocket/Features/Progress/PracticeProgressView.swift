import SwiftData
import SwiftUI

/// The **Progress screen** (ADR 0117, Slice 2) — the payoff over the practice log: This week, This
/// month, All-time. Pushed from the Journal space, which is already the read-only practice-history
/// destination (ADR 0100); Home's grouped layout is untouched, so ADR 0102's grouping gets churned
/// once, when the deferred year tier and card evolution land together.
///
/// **This year is deliberately not here**, nor is a placeholder for it: a year view over five weeks of
/// history shows one month, and the "wrapped" card it belongs with is worth building against real data
/// (ADR 0117). Neither are **streaks, a weekly goal, a days-active denominator, or a week-over-week
/// delta** — all four are habit-pressure, held together with the mitigations designed to contain them.
///
/// **Never a grade (ADR 0070).** Every measure is effort: minutes, days, sessions, things made. Tempo
/// appears only as a factual log of what was played. Nothing is compared to another player, and a
/// quiet week is described, not judged.
///
/// The view does no arithmetic — it queries, maps to values, and hands them to `PracticeProgress`.
struct PracticeProgressView: View {
    // Unfiltered queries, mapped and windowed in memory — an optional `#Predicate` starves the main
    // thread (`docs/swiftdata-gotchas.md`), and the aggregation is pure by design anyway.
    @Query(sort: \PracticeRun.startedAt) private var runs: [PracticeRun]
    @Query private var loops: [Loop]
    @Query private var exercises: [Exercise]
    @Query private var journalEntries: [JournalEntry]

    private var summary: PracticeProgress.Summary {
        PracticeProgress.summarize(records: runs.map(\.record), inventory: inventory)
    }

    /// The derived inventory counts the achievement wall shows — the existing `PracticeStats` roll-up,
    /// reused rather than recounted so the two can't drift.
    private var inventory: PracticeStats.Summary {
        PracticeStats.summarize(loopMasteryValues: loops.map(\.mastery),
                                exerciseCount: exercises.count,
                                totalNotes: journalEntries.count)
    }

    var body: some View {
        ScrollView {
            let summary = summary
            VStack(alignment: .leading, spacing: 30) {
                if summary.hasNoHistory {
                    noHistoryYet
                } else {
                    weekSection(summary.week)
                    monthSection(summary.month)
                    allTimeSection(summary.allTime)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .readableWidth()
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .background(PocketColor.background.ignoresSafeArea())
    }

    // MARK: - Nothing logged yet

    /// The fresh-install answer. One calm statement rather than three empty sections — a screen the
    /// player navigated to can't hide the way the old derived card did, so the first impression has to
    /// be *made* rather than avoided. It says what will fill it and stops; no call to action, no
    /// encouragement, nothing to feel behind on.
    private var noHistoryYet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing here yet")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Finish a drill and it starts keeping count — how long you played, which days, and "
                 + "the tempos you played at. It's a record of the work, not a mark for it.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - This week

    private func weekSection(_ week: PracticeProgress.Week) -> some View {
        HomeSection(title: "This week") {
            VStack(alignment: .leading, spacing: 14) {
                if week.isEmpty {
                    // The seven bars still draw. An empty week's *shape* is the honest answer, and
                    // hiding it would make the section reappear and vanish week to week.
                    Text("Nothing logged this week yet.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    HStack(spacing: 20) {
                        figure("\(week.minutes)", "minutes")
                        figure("\(week.daysActive)", week.daysActive == 1 ? "day" : "days")
                    }
                }
                WeekMinutesChart(week: week)
            }
        }
    }

    // MARK: - This month

    private func monthSection(_ month: PracticeProgress.Month) -> some View {
        HomeSection(title: monthTitle(month)) {
            VStack(alignment: .leading, spacing: 14) {
                if month.isEmpty {
                    Text("Nothing logged this month yet.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    HStack(spacing: 20) {
                        figure("\(month.minutes)", "minutes")
                        figure("\(month.daysActive)", month.daysActive == 1 ? "day" : "days")
                        if month.newTempos > 0 {
                            figure("\(month.newTempos)", month.newTempos == 1 ? "new tempo" : "new tempos")
                        }
                    }
                    if let best = month.bestDay {
                        Text("Longest day: \(best.day.formatted(.dateTime.weekday(.wide).day().month())) "
                             + "· \(best.minutes) minutes")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                MonthHeatmap(month: month)
            }
        }
    }

    /// "This month" carries its name, since a heatmap of an unnamed month is ambiguous once you've
    /// scrolled past the top of the screen.
    private func monthTitle(_ month: PracticeProgress.Month) -> String {
        "This month · \(month.interval.start.formatted(.dateTime.month(.wide)))"
    }

    // MARK: - All-time

    private func allTimeSection(_ allTime: PracticeProgress.AllTime) -> some View {
        HomeSection(title: "All-time") {
            VStack(alignment: .leading, spacing: 16) {
                lifetimeLine(allTime.lifetime)
                milestoneWall(allTime.milestones)
                inventoryWall(allTime.inventory)
            }
        }
    }

    /// The headline: time played and sessions, and when it started.
    ///
    /// Under an hour it reads in minutes; past that, hours **and** the minutes past the hour. Both the
    /// hours and the remainder come off the same rounded minute total the week and month sections use
    /// (`PracticeLog.Lifetime`), so this line can never print a smaller number than the month above it.
    private func lifetimeLine(_ lifetime: PracticeLog.Lifetime) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 20) {
                if lifetime.hours > 0 {
                    figure("\(lifetime.hours)", lifetime.hours == 1 ? "hour" : "hours")
                    // Dropped at a round hour — "2 hours 0 minutes" is noise, not precision.
                    if lifetime.remainingMinutes > 0 {
                        figure("\(lifetime.remainingMinutes)",
                               lifetime.remainingMinutes == 1 ? "minute" : "minutes")
                    }
                } else {
                    figure("\(lifetime.minutes)", lifetime.minutes == 1 ? "minute" : "minutes")
                }
                figure("\(lifetime.sittingCount)",
                       lifetime.sittingCount == 1 ? "session" : "sessions")
            }
            if let since = lifetime.since {
                Text("Since you started, \(since.formatted(.dateTime.day().month(.wide).year()))")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    /// The hours wall. Every mark is always shown — the ones ahead sit unfilled rather than hidden, so
    /// the wall doesn't rearrange as you pass them. Stated as a wall you walk past, never as a set of
    /// goals: nothing here says *by when*, and an unreached mark is neutral, not outstanding.
    private func milestoneWall(_ milestones: [PracticeProgress.HoursMilestone]) -> some View {
        HStack(spacing: 8) {
            ForEach(milestones) { milestone in
                VStack(spacing: 3) {
                    Text("\(milestone.hours)")
                        .font(.pocketMono(.subheadline).weight(.semibold))
                    Text("hours")
                        .font(.futura(.caption2))
                }
                .foregroundStyle(milestone.isReached ? PocketColor.practice : PocketColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(milestone.isReached ? PocketColor.practiceCircleWash : PocketColor.surfaceSubtle))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(milestone.isReached
                                    ? "\(milestone.hours) hours, reached"
                                    : "\(milestone.hours) hours, not yet")
            }
        }
    }

    /// The inventory counts — **supporting texture, never the headline**. They measure library size
    /// rather than effort and can go *down* when a drill is deleted, which is exactly why ADR 0117
    /// demoted them from the home card to the bottom of the all-time wall.
    private func inventoryWall(_ inventory: PracticeStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you've built")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 10) {
                tile(inventory.exercises, "Exercises")
                tile(inventory.loops, "Loops")
                tile(inventory.fullMasteryCount, "Mastered")
                tile(inventory.notes, "Notes")
            }
        }
    }

    // MARK: - Shared pieces

    /// A value with its unit — the screen's one figure style, so week / month / all-time read as the
    /// same kind of statement at three scales.
    private func figure(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.pocketMono(.title2).weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .contentTransition(.numericText())
            Text(unit)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(unit)")
    }

    /// One inventory tile — deliberately the same shape as the old home card's, since these are the
    /// same numbers, now in the place they belong.
    private func tile(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.pocketMono(.title3).weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(label)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(PocketColor.surfaceStandard))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
