import SwiftUI

/// **What you played** (ADR 0241) — under a week or a month, the period's practice grouped by kind,
/// each kind opening in place onto the exercises, loops and songs inside it.
///
/// **Or by song (ADR 0295).** A switch under the header regroups the same runs by the song they were
/// on, each song opening onto the kinds of work its time went on. The choice is kept, and the week's
/// list and the month's share it, so the screen is never grouped two ways at once.
///
/// **A list with bars, not a chart.** A day usually holds one to four runs, which is too few marks for
/// a chart to say anything a list doesn't. The bars are one scale across both levels — the largest
/// group is full width — so an item and a group can be read against each other.
///
/// **It narrows; it doesn't navigate.** Tapping a day on the chart above filters this list to that day
/// rather than opening a sheet, so a tap changes something already on screen instead of raising a
/// second surface with two rows in it. The way back to the whole period is the chip above the chart
/// (`PracticeLogDayChip`, ADR 0269); here the header only says which day the list is showing.
///
/// **Ranked by minutes and nothing else (ADR 0070).** No group is marked as too much or too little.
struct WhatYouPlayedList: View {
    /// The period's runs, or the chosen day's.
    let records: [SessionRecord]
    let names: PracticeBreakdown.Names
    /// "Whole week" / "Whole month" — what the list covers when no day is chosen.
    let wholePeriodLabel: String
    /// The day the list is narrowed to, if any.
    let selectedDay: Date?

    @AppStorage(PracticeBreakdown.Grouping.storageKey)
    private var grouping = PracticeBreakdown.Grouping.standard

    /// Which rows are open, by row id. Starts empty: closed rows keep the chart and the month grid
    /// below within reach; the items are one tap away. A kind's id and a song's never collide, so
    /// switching the grouping shows the new rows closed.
    @State private var expanded: Set<String> = []

    var body: some View {
        let rows = PracticeBreakdown.rows(records, names: names, grouping: grouping)
        let scale = max(1, rows.first?.seconds ?? 1)
        VStack(alignment: .leading, spacing: 2) {
            header
            groupingPicker
            if rows.isEmpty {
                Text("Nothing logged that day.")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.vertical, 8)
            }
            ForEach(rows) { row in
                groupRow(row, scale: scale)
                if expanded.contains(row.id) {
                    items(row, scale: scale)
                }
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PocketColor.surfaceSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("What you played")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer(minLength: 8)
            // Says which day, and nothing more: the chip that clears it sits with the figures above
            // the chart, where the tap was (ADR 0269).
            Text(selectedDay.map { $0.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)) }
                 ?? wholePeriodLabel)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .frame(minHeight: 30)
    }

    /// *By kind* or *By song*. A segmented control, because there are two answers and both should be
    /// in view: a menu would hide that the list can be read the other way.
    private var groupingPicker: some View {
        Picker("Group what you played", selection: $grouping) {
            ForEach(PracticeBreakdown.Grouping.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(UITestHooks.practiceLogGrouping)
        .padding(.bottom, 6)
    }

    // MARK: - Rows

    @ViewBuilder
    private func groupRow(_ group: PracticeBreakdown.Row, scale: Double) -> some View {
        let isOpen = expanded.contains(group.id)
        let figure = PracticeLog.MinutesFigure(seconds: group.seconds)
        let spoken = [group.title, group.detail, "\(figure.value) \(figure.unit)"]
            .compactMap { $0 }.joined(separator: ", ")
        if group.items.isEmpty {
            // Nothing inside to open — the metronome's runs belong to no unit (ADR 0242). So the row
            // is the whole entry: not a button, and no chevron, because a control that opens onto
            // nothing is worse than no control.
            groupRowContent(group, figure: figure, scale: scale, chevron: nil)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(UITestHooks.practiceLogKind)
                .accessibilityLabel(spoken)
        } else {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if isOpen { expanded.remove(group.id) } else { expanded.insert(group.id) }
                }
            } label: {
                groupRowContent(group, figure: figure, scale: scale, chevron: isOpen)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(UITestHooks.practiceLogKind)
            .accessibilityLabel(spoken)
            .accessibilityValue(isOpen ? "Open" : "Closed")
        }
    }

    /// A group's name, minutes and bar. `chevron` is whether the group is open, or `nil` for a group
    /// with nothing to open — which keeps the chevron's width, so its name still lines up with the
    /// names above and below it.
    private func groupRowContent(_ group: PracticeBreakdown.Row,
                                 figure: PracticeLog.MinutesFigure,
                                 scale: Double,
                                 chevron isOpen: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .rotationEffect(.degrees(isOpen == true ? 90 : 0))
                    .frame(width: 12)
                    .opacity(isOpen == nil ? 0 : 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.title)
                        .font(.futura(.subheadline, weight: .medium))
                        .italic(group.isUnnamed)
                        .foregroundStyle(group.isUnnamed ? PocketColor.textSecondary : PocketColor.textPrimary)
                    if let detail = group.detail {
                        Text(detail)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Text(figure.short)
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            ProportionBar(fraction: group.seconds / scale, height: 5, emphasis: 1)
                .padding(.leading, 20)
        }
        .padding(.vertical, 8)
    }

    private func items(_ group: PracticeBreakdown.Row, scale: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(group.items) { item in
                let figure = PracticeLog.MinutesFigure(seconds: item.seconds)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.futura(.subheadline))
                                .italic(item.isUnnamed)
                                .foregroundStyle(item.isUnnamed ? PocketColor.textSecondary : PocketColor.textPrimary)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.futura(.caption))
                                    .foregroundStyle(PocketColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(figure.short)
                            .font(.pocketMono(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    ProportionBar(fraction: item.seconds / scale, height: 3, emphasis: 0.6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel([item.name, item.detail, "\(figure.value) \(figure.unit)"]
                    .compactMap { $0 }.joined(separator: ", "))
            }
        }
        .padding(.leading, 20)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .transition(.opacity)
    }
}

/// A thin horizontal bar, filled to `fraction` of the available width. Decoration for sighted readers
/// only — every row states its minutes in words beside it.
private struct ProportionBar: View {
    let fraction: Double
    let height: CGFloat
    let emphasis: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PocketColor.surfaceStandard)
                Capsule()
                    .fill(PocketColor.practice.opacity(emphasis))
                    .frame(width: max(height, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
