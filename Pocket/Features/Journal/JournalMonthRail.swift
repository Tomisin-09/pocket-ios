import SwiftUI

/// The **month rail** above the Journal feed (ADR 0207 D6) — a fixed *Show* chip, then the months
/// the feed can currently reach, scrolling.
///
/// ### Why the Show chip is pinned and does not scroll
///
/// ADR 0190 D8 lets the Journal's filters persist across visits **only** because the screen shows,
/// unopened, that they are in force — otherwise a player returns to a year-old journal showing three
/// rows and reasonably concludes the app lost it. A filter chip that can scroll out of view breaks
/// exactly that guarantee, and would break it *intermittently*, which is worse than breaking it
/// outright. So the chip sits outside the `ScrollView` and only the months move.
///
/// This is why the owner filter moves off the ⋯ menu (amending ADR 0190 D7): the menu satisfied D8
/// through the filled `ellipsis.circle.fill` glyph, and a chip that states the filter in words
/// satisfies it better. The menu keeps *Sort* and *Pinned only*.
///
/// ### What the months are, and what they are not
///
/// **Presence, never volume** — the same line `JournalMonthGrid` draws. A month is listed because it
/// holds something; nothing about a chip says how much. The months come from `visibleDays`, so they
/// already respect the scope, owner and pinned filters: a rail offering a month the filters have
/// emptied would be a door to an empty room.
struct JournalMonthRail: View {

    /// Start-of-month dates in display order (`JournalMonthLayout.months(in:)`), so the rail reads
    /// in the same direction as the list beneath it under either sort.
    let months: [Date]
    /// The ⋯ menu's `showRowTitle` — "Show…" or "Show: Loop or Session".
    let showTitle: String
    /// Whether the owner facet is narrowing anything, which fills the chip.
    let isFiltering: Bool
    let onChooseKinds: () -> Void
    let onPickMonth: (Date) -> Void

    var calendar: Calendar = .current

    var body: some View {
        HStack(spacing: 8) {
            showChip
            // Only the months scroll. See this type's note on ADR 0190 D8 for why the chip cannot.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(months, id: \.self) { month in
                        monthChip(month)
                    }
                }
                .padding(.trailing, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Show

    /// States the filter on its face. ADR 0190 D10 recorded that `.pickerStyle(.menu)` drew a bare
    /// *Show ›* and left the filled glyph and the empty state as the only places the active kinds
    /// were legible; a chip has room for the value, which is the third and best place to carry it.
    private var showChip: some View {
        Button(action: onChooseKinds) {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.futura(.caption2, weight: .semibold))
                Text(showTitle)
                    .font(.futura(.caption, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isFiltering ? PocketColor.background : PocketColor.journal)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(isFiltering ? PocketColor.journal : PocketColor.surfaceStandard)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showTitle)
        .accessibilityHint("Choose which kinds of entry the journal shows")
    }

    // MARK: - Months

    /// **No "you are here" highlight**, deliberately. Marking the month at the top of the feed would
    /// mean tracking scroll position, which iOS 17 offers no cheap way to do — and an indicator that
    /// goes stale the moment you scroll past a month boundary is worse than none, because it is a
    /// statement about where you are that is wrong most of the time. The rail is a set of doors, not
    /// a position readout.
    private func monthChip(_ month: Date) -> some View {
        Button { onPickMonth(month) } label: {
            Text(label(for: month))
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background { Capsule().fill(PocketColor.surfaceStandard) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
        .accessibilityHint("Scrolls the journal to this month")
    }

    /// `"Sep"`, or `"Sep 26"` once the rail spans more than one year.
    ///
    /// Decided from the rail's own contents rather than from today's date: a journal read in January
    /// that ends in December should not relabel itself, and a rule that consults `Date()` gives a
    /// different answer depending on when it is read.
    private func label(for month: Date) -> String {
        spansMultipleYears
            ? month.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            : month.formatted(.dateTime.month(.abbreviated))
    }

    private var spansMultipleYears: Bool {
        Set(months.map { calendar.component(.year, from: $0) }).count > 1
    }
}

#Preview("Month rail") {
    let calendar = Calendar(identifier: .gregorian)
    let months = [(2026, 9), (2026, 8), (2026, 7), (2026, 6), (2026, 4), (2025, 12)]
        .compactMap { calendar.date(from: DateComponents(year: $0.0, month: $0.1, day: 1)) }
    return VStack(spacing: 20) {
        JournalMonthRail(months: months, showTitle: "Show…",
                         isFiltering: false, onChooseKinds: {}, onPickMonth: { _ in })
        JournalMonthRail(months: months, showTitle: "Show: Loop or Session",
                         isFiltering: true, onChooseKinds: {}, onPickMonth: { _ in })
    }
    .padding(.vertical, 24)
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
