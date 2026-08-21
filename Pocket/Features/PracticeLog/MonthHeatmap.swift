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
/// The ramp is **relative to this month's own busiest day**, so the grid describes the month on its
/// own terms. An absolute scale would need a number to be absolute against, and choosing one would be
/// setting a daily goal by the back door (ADR 0117 holds goals with the deferred streaks).
struct MonthHeatmap: View {
    let month: PracticeProgress.Month
    var calendar: Calendar = .current

    private let cellCorner = 3.0
    private let spacing = 4.0
    /// Light → dark, one hue. Opacities rather than four colour assets: `PocketColor.practice` is
    /// already appearance-aware, so the whole ramp follows the theme without a second set of tokens.
    private let rampOpacities = [0.25, 0.45, 0.7, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            grid
            key
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
            RoundedRectangle(cornerRadius: cellCorner)
                .fill(fill(for: bucket))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label(for: bucket))
        } else {
            // A leading/trailing blank so the 1st lands under its real weekday. Not a day, so it
            // carries no colour and no VoiceOver presence.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    private func fill(for bucket: PracticeLog.DayBucket) -> Color {
        guard bucket.isActive else { return PocketColor.surfaceStandard }
        return PocketColor.practice.opacity(rampOpacities[step(for: bucket)])
    }

    /// Which of the four steps a day sits in, relative to the month's busiest day. Any practice at all
    /// reaches at least step 0, so a short day is never invisible.
    private func step(for bucket: PracticeLog.DayBucket) -> Int {
        let fraction = Double(bucket.minutes) / Double(month.peakMinutes)
        let index = Int((fraction * Double(rampOpacities.count)).rounded(.up)) - 1
        return min(rampOpacities.count - 1, max(0, index))
    }

    private func label(for bucket: PracticeLog.DayBucket) -> String {
        let day = bucket.day.formatted(.dateTime.day().month(.wide))
        return bucket.isActive ? "\(day), \(bucket.minutes) minutes" : "\(day), no practice"
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
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    // MARK: - Key

    /// The magnitude scale. Words rather than numbers, because the ramp is relative to the month —
    /// putting minutes on it would imply a fixed scale it doesn't have.
    private var key: some View {
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
        .accessibilityLabel("Shading runs from less practice to more, relative to this month's busiest day")
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
    return MonthHeatmap(month: .init(interval: interval, days: buckets, minutes: 340,
                                     daysActive: 15, bestDay: nil, newTempos: 3))
        .padding()
        .background(PocketColor.background)
}
