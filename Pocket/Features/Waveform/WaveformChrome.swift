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
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Spacer()
                    if !expanded {
                        Text(summary)
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.futura(.footnote, weight: .semibold))
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

/// Standard panel surface — a hair off the background, in either appearance.
var panelBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(PocketColor.surfaceStandard)
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
                    .font(.futura(.subheadline, weight: .medium))
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

/// Shown when the song's audio could not be opened (bookmark no longer resolves,
/// file unreadable) — an honest notice instead of a silently dead transport
/// (audit 2026-07-05). Non-blocking: loops/markers stay browsable underneath.
struct AudioUnavailableNotice: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Couldn't load this song's audio")
                .font(.futura(.subheadline, weight: .medium))
                .foregroundStyle(PocketColor.textPrimary)
            Text("The file may have moved or been deleted. Re-import it to practice again.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(panelBackground)
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
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
                .font(.futura(.caption2, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(PocketColor.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(PocketColor.background.opacity(0.85))
                        .overlay(Capsule().strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fit whole song")
        .accessibilityHint("Resets zoom to show the entire song")
    }
}

// `UndoToastView` moved to `UI/UndoToastView.swift` — the waveform's loop/marker deletes and
// every list row's delete (`.pocketRowActions`) now render the same pill.
