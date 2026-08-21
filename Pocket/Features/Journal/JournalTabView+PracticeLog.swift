import SwiftUI

/// The Journal's way into the **Practice log** (ADR 0176), split out of `JournalTabView` to keep that
/// file under the 400-line cap — the same reason `+Deletion` exists.
extension JournalTabView {

    /// The way into ADR 0117's counted-up screen (ADR 0176): a quiet row above the timeline, on the
    /// **free** side of the paywall where the Journal already lives (ADR 0144).
    ///
    /// **Why a plain row and not a live summary.** A strip carrying this week's minutes would be the
    /// two-tier "promise / payoff" design ADR 0117 drafted for Home — but it would also put a number
    /// permanently above a timeline whose whole job is words, and hand a fresh install a zero to read
    /// before it has read anything else. The row states where the counting lives and says nothing
    /// about how much of it there is.
    ///
    /// **Hidden while searching.** A search is a question about the timeline, and a fixed navigation
    /// row is not part of the answer; it would sit above "No matches" claiming the screen still has
    /// somewhere to go.
    var practiceLogRow: some View {
        Button {
            showingPracticeLog = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.journal)
                    .frame(width: 24)
                Text("Practice log")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Stated, not inferred: the shoot reaches this figure by `app.buttons["Practice log"]`, and a
        // label assembled from the row's children would change the moment the chevron or the glyph does.
        .accessibilityLabel("Practice log")
        .accessibilityHint("Minutes, days and tempos, counted up")
        .overlay(alignment: .bottom) {
            Divider().padding(.horizontal, 20)
        }
    }

}
