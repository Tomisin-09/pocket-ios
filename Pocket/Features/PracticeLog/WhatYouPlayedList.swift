import SwiftUI

/// **What you played** (ADR 0241) — under a week or a month, the period's practice grouped by kind,
/// each kind opening in place onto the exercises, loops and songs inside it.
///
/// **A list with bars, not a chart.** A day usually holds one to four runs, which is too few marks for
/// a chart to say anything a list doesn't. The bars are one scale across both levels — the largest
/// group is full width — so an item and a group can be read against each other.
///
/// **It narrows; it doesn't navigate.** Tapping a day on the chart above filters this list to that day
/// rather than opening a sheet, so a tap changes something already on screen instead of raising a
/// second surface with two rows in it. The chip that names the day is how you get the period back.
///
/// **Ranked by minutes and nothing else (ADR 0070).** No group is marked as too much or too little.
struct WhatYouPlayedList: View {
    let groups: [PracticeBreakdown.Group]
    /// "Whole week" / "Whole month" — what the list covers when no day is chosen.
    let wholePeriodLabel: String
    /// The day the list is narrowed to, if any.
    let selectedDay: Date?
    let clearDay: () -> Void

    /// Which kinds are open. Starts empty: closed groups are five rows, which keeps the chart and the
    /// month grid below within reach; the items are one tap away.
    @State private var expanded: Set<PracticeRunKind> = []

    private var scale: Double { max(1, groups.first?.seconds ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            if groups.isEmpty {
                Text("Nothing logged that day.")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.vertical, 8)
            }
            ForEach(groups) { group in
                groupRow(group)
                if expanded.contains(group.kind) {
                    items(group)
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
            if let selectedDay {
                Button(action: clearDay) {
                    HStack(spacing: 5) {
                        Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.futura(.caption, weight: .medium))
                    .foregroundStyle(PocketColor.textPrimary)
                    .padding(.leading, 10)
                    .padding(.trailing, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(PocketColor.practiceCircleWash))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .accessibilityHint("Shows the \(wholePeriodLabel.lowercased()) again")
            } else {
                Text(wholePeriodLabel)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .frame(minHeight: 30)
    }

    // MARK: - Rows

    private func groupRow(_ group: PracticeBreakdown.Group) -> some View {
        let isOpen = expanded.contains(group.kind)
        let figure = PracticeLog.MinutesFigure(seconds: group.seconds)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isOpen { expanded.remove(group.kind) } else { expanded.insert(group.kind) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 12)
                    Text(group.kind.groupLabel)
                        .font(.futura(.subheadline, weight: .medium))
                        .foregroundStyle(PocketColor.textPrimary)
                    Spacer(minLength: 8)
                    Text(figure.short)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                ProportionBar(fraction: group.seconds / scale, height: 5, emphasis: 1)
                    .padding(.leading, 20)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(UITestHooks.practiceLogKind)
        .accessibilityLabel("\(group.kind.groupLabel), \(figure.value) \(figure.unit)")
        .accessibilityValue(isOpen ? "Open" : "Closed")
    }

    private func items(_ group: PracticeBreakdown.Group) -> some View {
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
