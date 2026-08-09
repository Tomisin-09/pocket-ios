import SwiftUI

// Loop creation control strips (design brief §4.1 #9): the A/B span strip (ADR 0041)
// and the downbeat-placement strip (ADR 0024), each shown in place of the
// mode-instructions line for their respective flow.

/// The **A/B span** strip (ADR 0041), shown in place of the mode-instructions line
/// while a span is in play. Unlike `EditToolbar` there's no ✗/✓ gate and the
/// transport stays live: while forming it just prompts for B; once A↔B is set it
/// carries ▶ audition · the span times · **Save as loop** · **✕** clear. Saving
/// promotes the ephemeral span to a real loop; ✕ drops it and plays on through.
struct ABSpanBar: View {
    let isPlaying: Bool
    /// `false` while only A is placed (awaiting B) — hides the ▶/Save until set.
    let isSet: Bool
    /// `true` while range-editing a saved loop — Save writes back ("Save changes").
    let isEditing: Bool
    let label: String
    let onAudition: () -> Void
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isSet {
                Button(action: onAudition) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.futura(size: 14, weight: .semibold))
                        .foregroundStyle(PocketColor.active)
                        .frame(width: 38, height: 30)
                        .background(Capsule().fill(PocketColor.active.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")
            }

            Text(label)
                .font(.futura(.footnote, weight: .medium))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)

            Spacer()

            if isSet {
                Button(action: onSave) {
                    Text(isEditing ? "Save changes" : "Save as loop")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.confirm)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(PocketColor.confirm.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(PocketColor.confirm.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEditing ? "Save loop changes" : "Save loop")
            }

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.futura(size: 14, weight: .heavy))
                    .foregroundStyle(PocketColor.danger)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(PocketColor.danger.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear loop")
        }
    }
}

/// The "set the 1" control strip (ADR 0024), shown in place of the mode-instructions
/// line while the downbeat is being placed on the waveform. Two ways to land it: **play
/// along and tap the 1** (the dedicated transport + "Tap the 1" capture here, since the
/// main transport is locked during placement) or **drag the handle** onto a peak. The
/// **✗/✓** pill discards or commits.
struct DownbeatBar: View {
    let isPlaying: Bool
    let onTogglePlay: () -> Void
    let onCapture: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void
    /// The song already has a 1, so ✓ means **correct from here** rather than *set it* — and
    /// the rarer "replace the original" intent needs its own way out (ADR 0154).
    var hasAnchor: Bool = false
    /// How many corrections are already stored; drives the clear affordance.
    var correctionCount: Int = 0
    var onMove: () -> Void = {}
    var onClearCorrections: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "1.circle")
                    .font(.futura(size: 14, weight: .semibold))
                    .foregroundStyle(PocketColor.fine)
                Text(hasAnchor ? "Mark where the 1 has drifted to"
                               : "Play and tap the 1 — or drag the handle")
                    .font(.futura(.footnote, weight: .medium))
                    .foregroundStyle(PocketColor.textSecondary)

                if hasAnchor {
                    Spacer(minLength: 4)
                    // The rare intent, kept as plain text so it can't be mistaken for the
                    // primary action — most returns to this bar are corrections, not do-overs.
                    Button("Move the 1", action: onMove)
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.fine)
                        .buttonStyle(.plain)
                        .accessibilityHint("Replaces the original 1 instead of correcting from here")
                }
            }

            if correctionCount > 0 {
                HStack(spacing: 6) {
                    Text("^[\(correctionCount) correction](inflect: true)")
                        .font(.futura(.caption2, weight: .medium))
                        .foregroundStyle(PocketColor.textSecondary)
                    Button("Clear", action: onClearCorrections)
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.danger)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear all corrections")
                }
            }

            HStack(spacing: 8) {
                iconButton(isPlaying ? "pause.fill" : "play.fill",
                           tint: PocketColor.textPrimary, action: onTogglePlay)
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button(action: onCapture) {
                    Label("Tap the 1", systemImage: "hand.tap.fill")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.fine)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(PocketColor.fine.opacity(0.18)))
                        .overlay(Capsule().strokeBorder(PocketColor.fine.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set the 1 at the playhead")

                Spacer()

                HStack(spacing: 4) {
                    iconButton("xmark", tint: PocketColor.danger, action: onCancel)
                        .accessibilityLabel("Discard downbeat")
                    iconButton("checkmark", tint: PocketColor.confirm, action: onConfirm)
                        .accessibilityLabel(hasAnchor ? "Correct the 1 from here" : "Save downbeat")
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(PocketColor.background.opacity(0.9))
                        .overlay(Capsule().strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
                )
            }
        }
    }

    private func iconButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.futura(size: 14, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

/// A text field with a trailing clear (✕) button that appears once it has text.
struct ClearableTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $text)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear text")
            }
        }
    }
}
