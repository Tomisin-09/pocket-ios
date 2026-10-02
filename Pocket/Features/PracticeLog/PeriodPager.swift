import SwiftUI

/// A row of calendar periods you swipe between (ADR 0241) — the oldest on the left, the current one on
/// the right, opening on the current one, so a swipe to the right reaches further back.
///
/// **Only the chart pages.** The figures above it and *What you played* below it follow the page that
/// settles, rather than travelling inside each page, because their height varies from one period to
/// the next and a paging scroll view takes the height of what it holds — a pager of mixed heights
/// would make the whole screen jump as you swipe. The chart is the same height in every period (the
/// month grid always keeps six rows for this reason), so the strip never changes size.
///
/// A horizontal `ScrollView` rather than a page-style `TabView`: it is lazy, so years of history cost
/// only the pages on screen, and it sizes to its content rather than needing a fixed height.
struct PeriodPager<Page: View>: View {
    /// Every period's start, oldest first. The last is the current period.
    let starts: [Date]
    /// The period showing, by its start — `nil` until the pager has settled anywhere, which reads as
    /// the current period.
    @Binding var position: Date?
    @ViewBuilder let page: (Date) -> Page

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(starts, id: \.self) { start in
                    page(start)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $position)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
    }
}

/// The header of a section you can page through: its period, a way back to now when you have left
/// it, and the two step buttons.
///
/// **Buttons as well as the swipe.** A swipe can't be seen, so nobody would find it without being
/// told, and VoiceOver needs a control it can land on. The title is styled exactly as `HomeSection`'s,
/// which these sections used before they could page — the header is the only part that changed.
struct PeriodHeader: View {
    let title: String
    /// What the buttons step through — "week" or "month" — for their spoken labels.
    let unit: String
    let position: PracticeLogPages.Position
    /// "This week" / "This month": the one-tap return, shown only once you've left the current period.
    let returnLabel: String
    let goTo: (Date) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.futura(.caption, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !position.isCurrent, let now = position.starts.last {
                Button(returnLabel) { goTo(now) }
                    .font(.futura(.footnote, weight: .medium))
                    .foregroundStyle(PocketColor.practice)
                    .buttonStyle(.plain)
            }
            step("chevron.left", label: "Earlier \(unit)", to: position.earlier)
            step("chevron.right", label: "Later \(unit)", to: position.later)
        }
    }

    private func step(_ symbol: String, label: String, to target: Date?) -> some View {
        Button {
            if let target { goTo(target) }
        } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(PocketColor.surfaceStandard))
                // A 30-point circle drawn, a 44-point target touched.
                .contentShape(Circle().inset(by: -7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(PocketColor.textPrimary)
        .disabled(target == nil)
        .opacity(target == nil ? 0.3 : 1)
        .accessibilityLabel(label)
    }
}

/// A value with its unit — the Practice log's one figure style, so week, month and all-time read as
/// the same kind of statement at three scales.
struct PracticeLogFigure: View {
    let value: String
    let unit: String

    init(_ value: String, _ unit: String) {
        self.value = value
        self.unit = unit
    }

    init(_ figure: PracticeLog.MinutesFigure) {
        self.init(figure.value, figure.unit)
    }

    var body: some View {
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
}
