import SwiftUI

/// Empty-state content for the collapsible panels (brief §5 — every state is
/// designed, not just the happy path). Quiet and unhurried: a dimmed glyph, a
/// title, and a one-line hint that teaches the *real* interaction.
struct EmptyPanelMessage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(PocketColor.textSecondary)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PocketColor.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
