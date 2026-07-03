import SwiftUI

/// The **"Your progress"** card on the home hub — a first slice of glanceable measures (derived,
/// no new persistence): loops, exercises, loops mastered, and journal notes. Hidden on a fresh
/// library (nothing to count yet) so first launch isn't a wall of zeros. The numbers come from
/// the pure `PracticeStats.summarize`; this is presentation only.
struct PracticeStatsCard: View {
    let summary: PracticeStats.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your progress")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            HStack(spacing: 10) {
                tile(summary.loops, "Loops")
                tile(summary.exercises, "Exercises")
                tile(summary.fullMasteryCount, "Mastered", tint: PocketColor.marker)
                tile(summary.notes, "Notes")
            }
        }
    }

    /// One stat tile — a big number over a plain-word label. `tint` colours the number for the
    /// achievement-flavoured measure (mastered); the rest read in the primary text colour.
    private func tile(_ value: Int, _ label: String,
                      tint: Color = PocketColor.textPrimary) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.pocketMono(.title2).weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.surfaceStandard))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview("Progress card") {
    PracticeStatsCard(summary: .init(loops: 12, exercises: 5, fullMasteryCount: 3, notes: 8))
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
