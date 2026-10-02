import SwiftUI

/// **A week, any week** (ADR 0241) — the Practice log's first section, which opens on the current week
/// and pages back through every week since you started.
///
/// The figures and *What you played* follow the page that settles; only the bar chart travels with
/// the swipe (see `PeriodPager` for why). Choosing a day narrows the list to it, and leaving the page
/// lets the choice go, so a day from one week is never left selected over another.
struct PracticeLogWeekSection: View {
    let records: [SessionRecord]
    let starts: [Date]
    let names: PracticeBreakdown.Names
    @Binding var position: Date?
    @Binding var selectedDay: Date?
    var now: Date = .now
    var calendar: Calendar = .current

    var body: some View {
        let paging = PracticeLogPages.Position(starts: starts, position: position)
        let week = PracticeProgress.week(records: records, now: paging.shown ?? now, calendar: calendar)
        VStack(alignment: .leading, spacing: 10) {
            PeriodHeader(title: paging.isCurrent ? "This week" : title(week.interval),
                         unit: "week", position: paging, returnLabel: "This week", goTo: show)
            VStack(alignment: .leading, spacing: 14) {
                if week.isEmpty {
                    // The seven bars still draw. An empty week's *shape* is the honest answer, and
                    // hiding it would make the section reappear and vanish week to week.
                    Text(paging.isCurrent ? "Nothing logged this week yet." : "Nothing logged that week.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    HStack(spacing: 20) {
                        PracticeLogFigure(week.minutesFigure)
                        PracticeLogFigure("\(week.daysActive)", week.daysActive == 1 ? "day" : "days")
                    }
                }
                PeriodPager(starts: starts, position: $position) { start in
                    WeekMinutesChart(week: PracticeProgress.week(records: records, now: start, calendar: calendar),
                                     today: now,
                                     calendar: calendar,
                                     selectedDay: start == paging.shown ? selectedDay : nil,
                                     onSelectDay: toggle)
                }
                if !week.isEmpty {
                    WhatYouPlayedList(groups: PracticeBreakdown.groups(scoped(to: week.interval), names: names),
                                      wholePeriodLabel: "Whole week",
                                      selectedDay: selectedDay,
                                      clearDay: { selectedDay = nil })
                }
            }
        }
        .onChange(of: position) { selectedDay = nil }
    }

    /// "21–27 Sept", or with the year when the week isn't in this one.
    private func title(_ interval: DateInterval) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let thisYear = calendar.isDate(interval.start, equalTo: now, toGranularity: .year)
            && calendar.isDate(lastDay, equalTo: now, toGranularity: .year)
        let style: Date.IntervalFormatStyle = thisYear
            ? .interval.day().month(.abbreviated)
            : .interval.day().month(.abbreviated).year()
        return (interval.start..<lastDay).formatted(style)
    }

    private func show(_ start: Date) {
        withAnimation(.snappy) { position = start }
    }

    private func toggle(_ day: Date) {
        selectedDay = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true ? nil : day
    }

    private func scoped(to interval: DateInterval) -> [SessionRecord] {
        guard let selectedDay else { return PracticeLog.records(in: interval, from: records) }
        return PracticeLog.records(in: PracticeLog.dayInterval(containing: selectedDay, calendar: calendar),
                                   from: records)
    }
}

/// **A month, any month** (ADR 0241) — the second section: its figures, its longest day once there is
/// more than one, the shaded grid, and *What you played*. Pages the same way the week does.
struct PracticeLogMonthSection: View {
    let records: [SessionRecord]
    let starts: [Date]
    let names: PracticeBreakdown.Names
    @Binding var position: Date?
    @Binding var selectedDay: Date?
    var now: Date = .now
    var calendar: Calendar = .current

    var body: some View {
        let paging = PracticeLogPages.Position(starts: starts, position: position)
        let month = PracticeProgress.month(records: records, now: paging.shown ?? now, calendar: calendar)
        VStack(alignment: .leading, spacing: 10) {
            PeriodHeader(title: title(month.interval, isCurrent: paging.isCurrent),
                         unit: "month", position: paging, returnLabel: "This month", goTo: show)
            VStack(alignment: .leading, spacing: 14) {
                figures(month, isCurrent: paging.isCurrent)
                PeriodPager(starts: starts, position: $position) { start in
                    MonthHeatmap(month: PracticeProgress.month(records: records, now: start, calendar: calendar),
                                 calendar: calendar,
                                 selectedDay: start == paging.shown ? selectedDay : nil,
                                 onSelectDay: toggle,
                                 showsKey: false)
                }
                MonthHeatmapKey()
                if !month.isEmpty {
                    WhatYouPlayedList(groups: PracticeBreakdown.groups(scoped(to: month.interval), names: names),
                                      wholePeriodLabel: "Whole month",
                                      selectedDay: selectedDay,
                                      clearDay: { selectedDay = nil })
                }
            }
        }
        .onChange(of: position) { selectedDay = nil }
    }

    @ViewBuilder
    private func figures(_ month: PracticeProgress.Month, isCurrent: Bool) -> some View {
        if month.isEmpty {
            Text(isCurrent ? "Nothing logged this month yet." : "Nothing logged that month.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        } else {
            HStack(spacing: 20) {
                PracticeLogFigure(month.minutesFigure)
                PracticeLogFigure("\(month.daysActive)", month.daysActive == 1 ? "day" : "days")
                if month.newTempos > 0 {
                    PracticeLogFigure("\(month.newTempos)", month.newTempos == 1 ? "new tempo" : "new tempos")
                }
            }
            // The longest day is also the scale the grid is shaded against, which is why the key
            // under the grid doesn't repeat it. Held back until there are two days to compare.
            if let longest = month.longestDay {
                let figure = PracticeLog.MinutesFigure(seconds: longest.seconds)
                Text("Longest day: \(longest.day.formatted(.dateTime.weekday(.wide).day().month())) "
                     + "· \(figure.value) \(figure.unit)")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    /// "This month · October" for now, which a heatmap needs once you've scrolled past the top of the
    /// screen; just "September" for a month behind it, with the year when it isn't this one.
    private func title(_ interval: DateInterval, isCurrent: Bool) -> String {
        let name = interval.start.formatted(.dateTime.month(.wide))
        if isCurrent { return "This month · \(name)" }
        guard calendar.isDate(interval.start, equalTo: now, toGranularity: .year) else {
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
        return name
    }

    private func show(_ start: Date) {
        withAnimation(.snappy) { position = start }
    }

    private func toggle(_ day: Date) {
        selectedDay = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true ? nil : day
    }

    private func scoped(to interval: DateInterval) -> [SessionRecord] {
        guard let selectedDay else { return PracticeLog.records(in: interval, from: records) }
        return PracticeLog.records(in: PracticeLog.dayInterval(containing: selectedDay, calendar: calendar),
                                   from: records)
    }
}
