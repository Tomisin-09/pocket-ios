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

/// Shown over the practice surface while a song's audio opens (brief §5 — every
/// state is designed). Dims the screen and absorbs touches so the half-ready
/// controls can't be tapped, and the user sees progress instead of a frozen app.
struct AudioLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(PocketColor.active)
                Text("Loading song…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .padding(28)
            .background(panelBackground)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading song")
    }
}

/// "Fit" pill shown in the waveform's top-trailing corner while zoomed in — the
/// explicit reset back to the whole song (1× zoom). Double-tap is reserved for
/// seek, so reset is its own control (ADR 0010 page-mode).
struct ZoomResetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Fit", systemImage: "arrow.left.and.right")
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(PocketColor.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(PocketColor.background.opacity(0.85))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fit whole song")
        .accessibilityHint("Resets zoom to show the entire song")
    }
}

/// Transient "Deleted X · Undo" toast after a destructive action (ADR 0019). A
/// floating pill at the bottom of the cockpit: the message, then an Undo action.
/// Auto-dismisses on a timer (owned by the model); this view just renders + acts.
struct UndoToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.active)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Restores the deleted item")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(PocketColor.background.opacity(0.92))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        )
        .accessibilityElement(children: .combine)
    }
}
