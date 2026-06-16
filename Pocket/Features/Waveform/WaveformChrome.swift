import SwiftUI

// Shared chrome for the practice screen's panels — the collapsible container and
// the standard panel surface used by the Loops / Markers / Song-info sections.

/// Collapsible panel: chevron + a summary line when collapsed, so the user is
/// never left wondering what's hidden (brief §3.4).
struct CollapsiblePanel<Content: View>: View {
    let title: String
    let summary: String
    @Binding var expanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Spacer()
                    if !expanded {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded { content }
        }
        .padding(14)
        .background(panelBackground)
    }
}

/// Standard panel surface — a hair lighter than the near-black background.
var panelBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.white.opacity(0.04))
}
