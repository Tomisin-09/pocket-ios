import SwiftUI

/// **This month, as a calendar** (ADR 0117) — a contribution-style grid, one cell per day, shaded by
/// how long you practised.
///
/// It is the same aggregation as the week chart, bucketed differently, and it answers a different
/// question: not "how much" but "how often". That is the most legible *am I showing up* artefact in
/// the design, and it becomes readable after two or three weeks.
///
/// Chart discipline: magnitude, so the ramp is **one hue, light to dark** — never a second colour and
/// never a rainbow. Four steps is as many as a small cell can carry legibly; a fifth would be a
/// distinction nobody can see at 14pt. Unpractised days are a distinct neutral, not step zero of the
/// ramp, so "nothing" never reads as "a little". Because a shaded cell means nothing without its
/// scale, a *Less → More* key sits under the grid — the one legend here, and a legend about
/// magnitude, not about a target.
///
/// The ramp runs up to **this month's typical practised day**, not its busiest (ADR 0268), so one
/// long day can't turn every ordinary day pale. It is still the month's own measure, not a number
/// anyone chose: an absolute scale would need a number to be absolute against, and choosing one would
/// be setting a daily goal by the back door (ADR 0117 holds goals with the deferred streaks).
///
/// A calendar as well as a chart (ADR 0268): each cell carries its date, today is ringed, and the days
/// still to come are drawn as outlines — a day that hasn't happened yet is not a day without practice.
struct MonthHeatmap: View {
    let month: PracticeProgress.Month
    var calendar: Calendar = .current
    /// Today, for the ring and for which days are still to come. Passed in rather than read from
    /// `.now` so a preview or a test can say what "today" is.
    var today: Date = .now
    /// The day *What you played* is narrowed to (ADR 0241), filled in the grid.
    var selectedDay: Date?
    /// Called with a practised day's start when its cell is tapped. `nil` leaves the grid inert.
    var onSelectDay: ((Date) -> Void)?
    /// Off when the grid pages (ADR 0241): the weekday headings and the key read the same for every
    /// month, so the section draws them once around the pager rather than once per page — a copy on
    /// every page would put one in the tree for each month the lazy strip has built either side of the
    /// one on screen.
    var showsHeadingsAndKey = true

    @Environment(\.colorScheme) private var colorScheme

    private let cellCorner = 3.0
    private let spacing = 4.0
    /// Light → dark, one hue. Opacities rather than four colour assets: `PocketColor.practice` is
    /// already appearance-aware, so the whole ramp follows the theme without a second set of tokens.
    /// The floor is 0.4 rather than 0.25 (ADR 0268): at 0.25 the palest shade sat closer to the empty
    /// neutral than to the next shade up (contrast 1.2 in both appearances), which made a short day
    /// read as a day off. From 0.4 every neighbouring pair, the neutral included, differs by 1.37–1.71.
    static let rampOpacities = [0.4, 0.6, 0.8, 1.0]
    private var rampOpacities: [Double] { Self.rampOpacities }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeadingsAndKey { MonthHeatmapWeekdays(calendar: calendar) }
            grid
            if showsHeadingsAndKey { MonthHeatmapKey() }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        cellView(cell)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ bucket: PracticeLog.DayBucket?) -> some View {
        if let bucket {
            if bucket.isActive, let onSelectDay {
                Button { onSelectDay(bucket.day) } label: { cell(bucket) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label(for: bucket))
                    .accessibilityAddTraits(isSelected(bucket) ? .isSelected : [])
            } else {
                cell(bucket)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label(for: bucket))
            }
        } else {
            // A blank so the 1st lands under its real weekday, and the padding rows that hold every
            // month at six (ADR 0241). Not a day, so no colour and no VoiceOver presence. A square
            // hidden rather than `Color.clear`, so a blank sizes exactly as a day does.
            square
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private var square: some View {
        RoundedRectangle(cornerRadius: cellCorner)
            .fill(PocketColor.surfaceStandard)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private func cell(_ bucket: PracticeLog.DayBucket) -> some View {
        let shade = month.shade(of: bucket)
        let selected = isSelected(bucket)
        let isToday = calendar.isDate(bucket.day, inSameDayAs: today)
        return RoundedRectangle(cornerRadius: cellCorner)
            .fill(fill(shade: shade, selected: selected, toCome: isToCome(bucket)))
            .overlay {
                // Every ring is drawn inside the cell rather than around it: the grid sits in a paging
                // scroll view, and a ring drawn outside the frame would be clipped at the grid's edges.
                if isToday {
                    RoundedRectangle(cornerRadius: cellCorner)
                        .strokeBorder(PocketColor.textPrimary, lineWidth: 2)
                } else if isToCome(bucket) {
                    RoundedRectangle(cornerRadius: cellCorner)
                        .strokeBorder(PocketColor.surfaceBorder, lineWidth: 1)
                }
            }
            .overlay(alignment: .topLeading) {
                // In the corner, not the centre: the shade is what the cell is for, and the date is
                // its caption. Scales down rather than spilling at the accessibility text sizes.
                Text("\(calendar.component(.day, from: bucket.day))")
                    .font(.futura(.caption2, weight: isToday || selected ? .semibold : nil))
                    .foregroundStyle(numberColour(shade: shade, selected: selected))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    private func isSelected(_ bucket: PracticeLog.DayBucket) -> Bool {
        selectedDay.map { calendar.isDate($0, inSameDayAs: bucket.day) } ?? false
    }

    /// A day after today. Drawn as an outline, because a day that hasn't happened is not a day off —
    /// filled with the unpractised neutral, the rest of the month read as a run of absences.
    private func isToCome(_ bucket: PracticeLog.DayBucket) -> Bool {
        bucket.day > calendar.startOfDay(for: today)
    }

    /// The chosen day is **filled** with ink, as a calendar marks the date you picked, because the
    /// ring now means today (ADR 0268). Only a practised day can be chosen, so a fill never hides a
    /// day off — and the day's figures are in the list it narrows, just below.
    private func fill(shade: Int?, selected: Bool, toCome: Bool) -> Color {
        if selected { return PocketColor.textPrimary }
        if let shade { return PocketColor.practice.opacity(rampOpacities[shade]) }
        return toCome ? .clear : PocketColor.surfaceStandard
    }

    /// The date over its own fill. The ramp runs towards the practice colour, which is light in the
    /// dark appearance and dark in the light one, so the page's background takes over from ink one
    /// shade earlier in the dark — the crossover that keeps every shade above 4:1 (ADR 0268).
    private func numberColour(shade: Int?, selected: Bool) -> Color {
        if selected { return PocketColor.background }
        guard let shade else { return PocketColor.textSecondary }
        let crossover = colorScheme == .dark ? 2 : 3
        return shade >= crossover ? PocketColor.background : PocketColor.textPrimary
    }

    private func label(for bucket: PracticeLog.DayBucket) -> String {
        var parts = [bucket.day.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if calendar.isDate(bucket.day, inSameDayAs: today) { parts.append("today") }
        if bucket.isActive {
            let figure = PracticeLog.MinutesFigure(seconds: bucket.seconds)
            parts.append("\(figure.value) \(figure.unit)")
        } else if !isToCome(bucket) {
            parts.append("no practice")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Rows

    /// The month laid out in weeks, `nil` padding the first and last rows so every column is one
    /// weekday. Honours the calendar's own `firstWeekday`, so the grid starts where the phone's week
    /// starts rather than on a hard-coded Monday.
    private var rows: [[PracticeLog.DayBucket?]] {
        guard let first = month.days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.day)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [PracticeLog.DayBucket?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: month.days.map { Optional($0) })
        // Always six rows, the most any month needs (ADR 0241). The grid pages, and a paging strip
        // takes the height of what it holds — so a five-row October beside a six-row November would
        // make the screen jump on every swipe.
        while cells.count < 42 || cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

/// The weekday initials over the month grid's columns (ADR 0268), in the calendar's own week order —
/// the same headings, from the same tested rotation, as the Journal's month grid. Hidden from
/// VoiceOver: every cell already says its weekday.
struct MonthHeatmapWeekdays: View {
    var calendar: Calendar = .current

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(JournalMonthLayout.weekdayInitials(calendar: calendar).enumerated()),
                    id: \.offset) { _, initial in
                Text(initial)
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The month grid's magnitude scale. Words rather than numbers, because the ramp is relative to the
/// month — putting minutes on it would imply a fixed scale it doesn't have, and a number on the
/// darkest swatch would read as a target to reach (ADR 0268).
struct MonthHeatmapKey: View {
    private var rampOpacities: [Double] { MonthHeatmap.rampOpacities }

    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
            RoundedRectangle(cornerRadius: 2)
                .fill(PocketColor.surfaceStandard)
                .frame(width: 10, height: 10)
            ForEach(rampOpacities, id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(PocketColor.practice.opacity(opacity))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.futura(.caption2))
        .foregroundStyle(PocketColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shading runs from less practice to more. The darkest is a typical day "
                            + "of practice for that month, or longer")
    }
}

#Preview("Month — a few weeks in") {
    let calendar = Calendar.current
    let interval = PracticeLog.monthInterval(containing: .now, calendar: calendar)
    let days = PracticeLog.days(in: interval, calendar: calendar)
    let pattern = [0.0, 20, 35, 0, 12, 48, 25]
    let buckets = days.enumerated().map { index, day in
        let minutes = index < 20 ? pattern[index % pattern.count] : 0
        return PracticeLog.DayBucket(day: day, seconds: minutes * 60, runCount: minutes > 0 ? 2 : 0)
    }
    let today = days.indices.contains(19) ? days[19] : Date.now
    return MonthHeatmap(month: .init(interval: interval, days: buckets, minutes: 340,
                                     daysActive: 15, bestDay: nil, newTempos: 3),
                        today: today,
                        selectedDay: days.indices.contains(5) ? days[5] : nil)
        .padding()
        .background(PocketColor.background)
}
