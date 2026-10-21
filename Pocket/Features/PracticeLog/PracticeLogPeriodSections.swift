import SwiftUI

/// **A week, any week** (ADR 0241) — the Practice log's first section, which opens on the current week
/// and pages back through every week since you started.
///
/// The figures and *What you played* follow the page that settles; only the bar chart travels with
/// the swipe (see `PeriodPager` for why). Choosing a day narrows the list to it and turns the figures
/// into the day's (ADR 0269), and leaving the page lets the choice go, so a day from one week is never
/// left selected over another.
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
                    // Side by side where they fit, so tapping a bar never moves the chart under your
                    // finger; stacked only once the text is too large for one line.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { figures(week) }
                        VStack(alignment: .leading, spacing: 10) { figures(week) }
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
                                      selectedDay: selectedDay)
                }
            }
        }
        .onChange(of: position) { selectedDay = nil }
    }

    /// The week's figures, or the chosen day's (ADR 0269): its minutes, with the chip that names it in
    /// place of the days count, because one day is one day.
    @ViewBuilder
    private func figures(_ week: PracticeProgress.Week) -> some View {
        if let selectedDay {
            PracticeLogFigure(PracticeProgress.day(records: records, containing: selectedDay,
                                                   calendar: calendar).minutesFigure)
            PracticeLogDayChip(day: selectedDay, unit: "week", clear: clear)
        } else {
            PracticeLogFigure(week.minutesFigure)
            PracticeLogFigure("\(week.daysActive)", week.daysActive == 1 ? "day" : "days")
        }
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

    /// A tap on a practised day chooses it, or lets it go if it was already chosen. It ticks, so the
    /// tap is felt before anything is read (ADR 0269), unless Haptics is off in Sound & feel.
    private func toggle(_ day: Date) {
        haptic(.selection)
        withAnimation(.snappy(duration: 0.2)) {
            selectedDay = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true ? nil : day
        }
    }

    private func clear() {
        withAnimation(.snappy(duration: 0.2)) { selectedDay = nil }
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
                VStack(spacing: 6) {
                    MonthHeatmapWeekdays(calendar: calendar)
                    PeriodPager(starts: starts, position: $position) { start in
                        MonthHeatmap(month: PracticeProgress.month(records: records, now: start, calendar: calendar),
                                     calendar: calendar,
                                     today: now,
                                     selectedDay: start == paging.shown ? selectedDay : nil,
                                     onSelectDay: toggle,
                                     showsHeadingsAndKey: false)
                    }
                }
                MonthHeatmapKey()
                if !month.isEmpty {
                    WhatYouPlayedList(groups: PracticeBreakdown.groups(scoped(to: month.interval), names: names),
                                      wholePeriodLabel: "Whole month",
                                      selectedDay: selectedDay)
                }
            }
        }
        .onChange(of: position) { selectedDay = nil }
    }

    /// The month's figures, or the chosen day's (ADR 0269): its minutes and any new tempo, without the
    /// days count, because one day is one day. The minutes figure stays put and changes its number, so
    /// the eye that tapped the grid sees it change.
    @ViewBuilder
    private func figures(_ month: PracticeProgress.Month, isCurrent: Bool) -> some View {
        if month.isEmpty {
            Text(isCurrent ? "Nothing logged this month yet." : "Nothing logged that month.")
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
        } else {
            let day = selectedDay.map { PracticeProgress.day(records: records, containing: $0, calendar: calendar) }
            let tempos = day?.newTempos ?? month.newTempos
            HStack(spacing: 20) {
                PracticeLogFigure(day?.minutesFigure ?? month.minutesFigure)
                if day == nil {
                    PracticeLogFigure("\(month.daysActive)", month.daysActive == 1 ? "day" : "days")
                }
                if tempos > 0 {
                    PracticeLogFigure("\(tempos)", tempos == 1 ? "new tempo" : "new tempos")
                }
            }
            dayLine(month)
        }
    }

    /// Under the figures: the month's longest day, or the chip naming the chosen day in its place.
    /// Both are always laid out and one is hidden, so the row is the height of the taller and the grid
    /// below doesn't move when you tap it (ADR 0269).
    private func dayLine(_ month: PracticeProgress.Month) -> some View {
        ZStack(alignment: .leading) {
            longestDay(month)
                .opacity(selectedDay == nil ? 1 : 0)
                .accessibilityHidden(selectedDay != nil)
            PracticeLogDayChip(day: selectedDay ?? month.interval.start, unit: "month", clear: clear)
                .opacity(selectedDay == nil ? 0 : 1)
                .allowsHitTesting(selectedDay != nil)
                .accessibilityHidden(selectedDay == nil)
        }
    }

    /// A fact about the month, and no longer the grid's scale — the grid shades against the month's
    /// typical day (ADR 0268). Held back until there are two days to compare.
    @ViewBuilder
    private func longestDay(_ month: PracticeProgress.Month) -> some View {
        if let longest = month.longestDay {
            let figure = PracticeLog.MinutesFigure(seconds: longest.seconds)
            Text("Longest day: \(longest.day.formatted(.dateTime.weekday(.wide).day().month())) "
                 + "· \(figure.value) \(figure.unit)")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
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

    /// A tap on a practised day chooses it, or lets it go if it was already chosen. It ticks, so the
    /// tap is felt before anything is read (ADR 0269), unless Haptics is off in Sound & feel.
    private func toggle(_ day: Date) {
        haptic(.selection)
        withAnimation(.snappy(duration: 0.2)) {
            selectedDay = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true ? nil : day
        }
    }

    private func clear() {
        withAnimation(.snappy(duration: 0.2)) { selectedDay = nil }
    }

    private func scoped(to interval: DateInterval) -> [SessionRecord] {
        guard let selectedDay else { return PracticeLog.records(in: interval, from: records) }
        return PracticeLog.records(in: PracticeLog.dayInterval(containing: selectedDay, calendar: calendar),
                                   from: records)
    }
}
