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

    /// Whether a run screen shows this bar: stopped, and standing on its own. A running screen has no
    /// room for review, and inside a routine the block isn't the place to browse its history.
    ///
    /// Also the rule for the toolbar's quick-note pencil, **inverted** (ADR 0221 D7): the bar's
    /// Journal opens a journal that writes, so the pencil shows exactly where the bar doesn't —
    /// running, or in a routine — and capture stays one tap away in every state (ADR 0142 J1) without
    /// being offered twice on one screen. One predicate, so the two can't overlap or both go missing.
    ///
    /// `nonisolated` because it is pure: on CI's toolchain a `View`'s static members are main-actor
    /// isolated, and a plain unit test could not call it.
    nonisolated static func isShown(isRunning: Bool, inRoutine: Bool) -> Bool { !isRunning && !inRoutine }

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
