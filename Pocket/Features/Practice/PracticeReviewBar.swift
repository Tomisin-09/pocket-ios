import SwiftUI

/// A compact single-row entry to a unit's **Journal** and **Takes** (ADR 0058 / ADR 0069) — two
/// count pills, each opening its own sheet.
///
/// Replaces the two stacked inline previews on the run-setup screen (device feedback 2026-07-17): as
/// journal entries and takes accumulate, two multi-row previews drowned the setup screen whose job is
/// to *start the run*. A fixed one-row bar keeps both review aids one tap away and bounded — the count
/// is the at-a-glance signal, the content lives in the sheets. Counts show only when non-zero so an
/// untouched unit reads "Journal" / "Takes", not "· 0".
struct PracticeReviewBar: View {
    let journalCount: Int
    let takesCount: Int
    let onJournal: () -> Void
    let onTakes: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PracticeReviewPill(title: "Journal", systemImage: "book.closed",
                               itemCount: journalCount, action: onJournal)
            PracticeReviewPill(title: "Takes", systemImage: "waveform",
                               itemCount: takesCount, action: onTakes)
        }
    }
}

private struct PracticeReviewPill: View {
    let title: String
    let systemImage: String
    let itemCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Teal icon keeps the practice identity; the label is white for contrast (device
                // feedback 2026-07-17 — teal-on-teal-wash read too faint).
                Image(systemName: systemImage)
                    .foregroundStyle(PocketColor.practice)
                Text(title)
                    .foregroundStyle(PocketColor.textPrimary)
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .font(.futura(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(PocketColor.practiceCircleWash))
            .overlay(Capsule().strokeBorder(PocketColor.practice.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(itemCount > 0 ? "\(title), \(itemCount)" : title)
    }
}

#Preview("Review bar") {
    PracticeReviewBar(journalCount: 3, takesCount: 2, onJournal: {}, onTakes: {})
        .padding()
        .preferredColorScheme(.dark)
}
