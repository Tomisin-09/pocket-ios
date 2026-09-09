import SwiftUI

/// The *tighten to your snags* offer (ADR 0200) — the status line's fourth tenant, after the
/// downbeat bar and the A/B strip and before `ModeDescriptionLine`.
///
/// **It is an offer, not a verdict.** It says where the marks are and what loop they suggest, and
/// the accept path auditions the span rather than writing the loop (`tightenToSnags` lifts it into
/// an A/B span, ADR 0041). Nothing here reports on how well anyone played: a count of marks the
/// player made themselves is not a score, and the copy stays on *where*, never on *how many
/// mistakes* (ADR 0070).
///
/// It borrows the slot and gives it straight back — taking the offer or turning it down restores
/// Loop controls / Follow / Grid. That is why it is gated on `offeringSnagTighten` rather than on
/// a proposal existing, which would be true for as long as the marks are.
struct SnagTightenBar: View {
    let count: Int
    let seconds: TimeInterval
    let onTighten: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SnagCatch()
                .stroke(PocketColor.oracle,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 18)
            // "3 snags close together" — where they are, never a tally of how badly it went.
            Text(count == 1 ? "1 snag here" : "\(count) snags close together")
                .font(.futura(.footnote, weight: .medium))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: onTighten) {
                Text("Tighten to \(SnagTightenBar.length(seconds))")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.oracle)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Try a shorter loop around your snags. Nothing is saved until you save it")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
    }

    /// A short spoken length — "1.4s" — in the monospace-free footnote, so it reads as prose in
    /// the sentence rather than as a readout.
    static func length(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", max(0, seconds))
    }
}

#Preview("Snag tighten bar") {
    VStack(spacing: 20) {
        SnagTightenBar(count: 3, seconds: 1.4, onTighten: {}, onDismiss: {})
        SnagTightenBar(count: 1, seconds: 0.5, onTighten: {}, onDismiss: {})
    }
    .padding()
    .background(PocketColor.background)
}
