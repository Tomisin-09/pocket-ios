import SwiftUI

/// The month grid behind **Jump to…** (ADR 0207 D5), replacing the graphical `DatePicker`.
///
/// ### Why this is hand-built
///
/// `DatePicker` exposes no per-day decoration hook on iOS 17 or 18, and the whole point of this
/// control is that a day **says whether it holds anything before you commit to it**. ADR 0190 D9's
/// jump landed at-or-before and told you a day was empty only afterwards; `docs/backlog.md` proposed
/// a caption as the cheap way out, and the caption answers one day at a time.
///
/// ### Why this is not the heatmap ADR 0190 D9 refused
///
/// D9's stronger objection was never ADR 0070 — it was that `MonthHeatmap` lives one tap away in the
/// same tab, shaded by *minutes practised*, and two identical-looking grids counting different things
/// is worse than one grid. That objection survives the change from shading to marking, so this grid
/// answers it in its own visual language, and every part of that is deliberate:
///
/// - a **stroked ring**, never a filled cell;
/// - **no opacity ramp** — a day either holds something or it does not, and the mark is binary;
/// - **no Less→More key**, because there is no scale. Its absence is the clearest possible statement
///   that nothing here is being measured, which is precisely what separates navigation from a
///   compliance chart.
///
/// **Presence, never volume.** A day that holds nine entries and a day that holds one look identical.
/// The count is a fact and would be harmless in a sentence; drawn *as a gradient across a month* it
/// becomes a picture of how often you wrote, which is the thing ADR 0070 does not allow the app to
/// have an opinion about.
///
/// ### What it costs
///
/// A hand-built grid owns the correctness `DatePicker` was providing: the first-weekday rotation,
/// leap Februaries, and every accessibility label. The arithmetic is all in the pure
/// `JournalMonthLayout` and tested there; this file is layout and nothing else.
struct JournalMonthGrid: View {

    /// Start-of-day keys for every day the feed can currently reach — `JournalTabView.visibleDays`.
    /// Filtered days are absent, so the grid never offers a day the active filters have removed.
    let daysWithEntries: Set<Date>
    /// The month on show. Bound, so ‹ › and the caller stay in step.
    @Binding var month: Date
    /// Called with the day the player picked. Only ever a day that holds something.
    let onPick: (Date) -> Void

    var calendar: Calendar = .current

    var body: some View {
        VStack(spacing: 12) {
            header
            VStack(spacing: 6) {
                weekdayHeadings
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            cell(date)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            stepButton(-1, systemImage: "chevron.left", label: "Previous month")
            Spacer(minLength: 0)
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer(minLength: 0)
            stepButton(1, systemImage: "chevron.right", label: "Next month")
        }
    }

    /// A step that would leave the journal's own span is **disabled, not hidden** — a control that
    /// vanishes at the edge moves everything beside it, and the grid's header would jump by the
    /// width of a chevron every time you reached the oldest month.
    private func stepButton(_ step: Int, systemImage: String, label: String) -> some View {
        let target = JournalMonthLayout.month(after: month, by: step,
                                              within: Array(daysWithEntries), calendar: calendar)
        return Button {
            if let target { month = target }
        } label: {
            Image(systemName: systemImage)
                .font(.futura(.body, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(target == nil ? PocketColor.textSecondary.opacity(0.4) : PocketColor.journal)
        .disabled(target == nil)
        .accessibilityLabel(label)
    }

    // MARK: - Grid

    private var weeks: [[Date?]] { JournalMonthLayout.weeks(of: month, calendar: calendar) }

    private var weekdayHeadings: some View {
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

    /// One day.
    ///
    /// **Only a day that holds something is a control.** That is what lets the sheet drop ADR 0190
    /// D9's at-or-before footnote entirely: you can no longer pick a day the feed cannot reach, so
    /// there is no rule left to explain. A day with nothing stays legible — dimmed, labelled, and
    /// inert — rather than being blanked, because a calendar with holes in it reads as broken.
    @ViewBuilder private func cell(_ date: Date?) -> some View {
        if let date {
            let key = calendar.startOfDay(for: date)
            let hasEntries = daysWithEntries.contains(key)
            let number = calendar.component(.day, from: date)

            if hasEntries {
                Button { onPick(key) } label: {
                    dayLabel(number, marked: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(date.formatted(.dateTime.day().month(.wide))), has entries")
            } else {
                dayLabel(number, marked: false)
                    .accessibilityLabel("\(date.formatted(.dateTime.day().month(.wide))), no entries")
            }
        } else {
            // A cell belonging to a neighbouring month — **a hidden day label, never `Color.clear`.**
            // `Color` is greedy in *both* axes, so at the `.large` detent each blank expanded to fill
            // whatever height the sheet offered: the two weeks that contain blanks were flung to the
            // top and bottom of the sheet while the four full weeks stayed tight together. A hidden
            // label occupies exactly what a real day occupies, at every Dynamic Type size, because it
            // *is* one.
            dayLabel(0, marked: false)
                .hidden()
                .accessibilityHidden(true)
        }
    }

    /// `minWidth`/`minHeight` rather than a fixed square or an `aspectRatio`: the number grows with
    /// Dynamic Type, and a cell pinned to a square clips it at the accessibility sizes.
    private func dayLabel(_ number: Int, marked: Bool) -> some View {
        Text("\(number)")
            .font(.futura(.subheadline))
            .foregroundStyle(marked ? PocketColor.textPrimary : PocketColor.textSecondary.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background {
                // The ring, and only for a marked day. Stroked, never filled — see this type's note
                // on why that distinction is the whole argument.
                Circle()
                    .strokeBorder(PocketColor.journal, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                    .opacity(marked ? 1 : 0)
            }
    }
}

#Preview("Month grid — August 2026") {
    // A month with a realistic scatter: some days hold entries, most do not.
    let calendar = Calendar(identifier: .gregorian)
    let marked = [2, 3, 9, 14, 15, 16, 26, 30].compactMap {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: $0))
    }
    return JournalMonthGrid(daysWithEntries: Set(marked),
                            month: .constant(calendar.date(from: DateComponents(year: 2026,
                                                                                month: 8,
                                                                                day: 1)) ?? .now),
                            onPick: { _ in })
        .padding(.vertical, 24)
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
