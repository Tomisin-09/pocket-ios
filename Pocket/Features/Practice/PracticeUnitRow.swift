import SwiftUI

/// One row in a Practice library list (ADR 0046): a trainable unit's title, an optional context
/// line (a loop's song), and its command → reach line. Shared by the exercise and loop libraries
/// so the two read consistently.
struct PracticeUnitRow: View {
    let title: String
    /// Optional second line — a loop's song; `nil`/empty for an exercise (no song).
    var context: String?
    /// The command → reach line, in the unit's own tempo unit (BPM for exercises, % for loops).
    let progress: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
                .foregroundStyle(PocketColor.textPrimary)
            if let context, !context.isEmpty {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(progress)
                .font(.caption)
                .foregroundStyle(PocketColor.practice)
        }
        .padding(.vertical, 2)
    }
}
