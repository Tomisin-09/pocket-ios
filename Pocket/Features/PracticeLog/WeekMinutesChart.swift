import SwiftUI

/// **This week's practice, as a shape** (ADR 0117) — seven daily bars of minutes.
///
/// The chart exists because the *shape* teaches more than any single number: four short days reads
/// differently from one long one, and no total can say that. The minutes total lives beside it, so the
/// bars are free to carry only the pattern.
///
/// Chart discipline: one series, so no legend — the section title names it. Empty days are **drawn**
/// (as a flat stub) rather than skipped, because a gap is information. Exactly one direct label, on
/// the busiest bar; a number over every bar would turn a shape back into a table. The axis is a row of
/// weekday initials and nothing else — no gridlines, no y-axis, no scale, since the bars are relative
/// to each other and an absolute scale would invite comparison against a target that doesn't exist.
///
/// **No target line, no average, no last-week ghost** (ADR 0117): each would make a bad week read as a
/// verdict, which is the thing this design refuses to do.
struct WeekMinutesChart: View {
    let week: PracticeProgress.Week
    /// Today, so the current day's label can be marked. Passed in rather than read from `.now` so the
    /// view is deterministic in previews and tests.
    var today: Date = .now
    var calendar: Calendar = .current

    /// Bar geometry. The stub is what a zero day draws — visible enough to say "this day exists and
    /// nothing happened", quiet enough not to read as a small amount of practice.
    private let barHeight = 96.0
    private let stubHeight = 3.0
    private let corner = 4.0

    /// The busiest day, which is the only bar that gets a value label.
    private var peakDay: Date? {
        week.days.filter(\.isActive).max { lhs, rhs in
            lhs.seconds == rhs.seconds ? lhs.day > rhs.day : lhs.seconds < rhs.seconds
        }?.day
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(week.days) { day in
                column(day)
            }
        }
    }

    private func column(_ day: PracticeLog.DayBucket) -> some View {
        VStack(spacing: 6) {
            Text(day.day == peakDay ? "\(day.minutes)" : " ")
                .font(.pocketMono(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
            ZStack(alignment: .bottom) {
                // The full-height slot keeps every column the same height, so the baseline is a
                // straight line whether or not a day was practised.
                Color.clear.frame(height: barHeight)
                UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner)
                    .fill(day.isActive ? PocketColor.practice : PocketColor.surfaceStandard)
                    .frame(height: height(for: day))
            }
            Text(weekdayInitial(day.day))
                .font(.futura(.caption2, weight: isToday(day.day) ? .semibold : .regular))
                .foregroundStyle(isToday(day.day) ? PocketColor.textPrimary : PocketColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day))
    }

    /// A practised day is scaled against the week's own peak; an unpractised one draws the stub. The
    /// minimum keeps a one-minute day from rendering as nothing at all, which would misreport it as a
    /// day off.
    private func height(for day: PracticeLog.DayBucket) -> Double {
        guard day.isActive else { return stubHeight }
        let fraction = Double(day.minutes) / Double(week.peakMinutes)
        return max(corner * 2, barHeight * fraction)
    }

    private func isToday(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: today)
    }

    /// One letter, in the device's own locale — "M" here is "L" in French. Taken from the calendar's
    /// very-short symbols rather than a hard-coded English table.
    private func weekdayInitial(_ day: Date) -> String {
        let index = calendar.component(.weekday, from: day) - 1
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private func accessibilityLabel(_ day: PracticeLog.DayBucket) -> String {
        let name = day.day.formatted(.dateTime.weekday(.wide))
        guard day.isActive else { return "\(name), no practice" }
        return "\(name), \(day.minutes) minutes"
    }
}

#Preview("Week — a mixed week") {
    let calendar = Calendar.current
    let week = PracticeLog.weekInterval(containing: .now, calendar: calendar)
    let days = PracticeLog.days(in: week, calendar: calendar)
    let minutes = [18.0, 0, 32, 7, 0, 45, 12]
    let buckets = zip(days, minutes).map {
        PracticeLog.DayBucket(day: $0, seconds: $1 * 60, runCount: $1 > 0 ? 2 : 0)
    }
    return WeekMinutesChart(week: .init(interval: week, days: buckets, minutes: 114, daysActive: 5))
        .padding()
        .background(PocketColor.background)
}

#Preview("Week — nothing yet") {
    let calendar = Calendar.current
    let week = PracticeLog.weekInterval(containing: .now, calendar: calendar)
    let buckets = PracticeLog.days(in: week, calendar: calendar).map {
        PracticeLog.DayBucket(day: $0, seconds: 0, runCount: 0)
    }
    return WeekMinutesChart(week: .init(interval: week, days: buckets, minutes: 0, daysActive: 0))
        .padding()
        .background(PocketColor.background)
}
