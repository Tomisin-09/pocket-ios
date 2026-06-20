import SwiftUI

// Loop capture flow (design brief §4.1 #9): `EditToolbar` is the edit-mode control
// strip (▶ audition · state label · ✗/✓) shown in place of the mode-instructions
// line once a loop is captured (Tap punch-out / Fine selection), with the transport
// greyed/locked. The green ✓ commits (a new loop is created instantly, auto-named,
// and activated — no naming step; ADR 0019), the red ✗ discards. New loops are
// renamed later from their row.

extension WaveformPracticeModel {
    /// A loop being captured, awaiting confirmation. Bounds are mutable so Fine
    /// handles drag them live; `fromFine` shows the blue handles; a non-nil
    /// `editingLoop` means we're adjusting an existing loop, not creating one.
    struct CaptureDraft {
        var start: Double
        var end: Double
        var fromFine: Bool
        var editingLoop: Loop?
    }
}

/// Step 1 — the edit-mode control strip, shown in place of the mode-instructions
/// line while a loop is being created or its range adjusted (the whole transport is
/// greyed/locked meanwhile, so this is the only live control surface). A ▶/⏸ button
/// **auditions** the captured region, a label says which state you're in, and a
/// **Y/N** pill commits (Y → save) or discards (N). Letters, not ✓/✗, so the
/// decision can't be mistaken for the loop's name.
struct EditToolbar: View {
    let isPlaying: Bool
    /// `true` when adjusting an existing loop's range rather than creating a new one.
    let isEditingExisting: Bool
    let onPlayPause: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PocketColor.active)
                    .frame(width: 38, height: 30)
                    .background(Capsule().fill(PocketColor.active.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")

            Text(isEditingExisting ? "Editing loop" : "New loop")
                .font(.footnote.weight(.medium))
                .foregroundStyle(PocketColor.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                iconButton("xmark", tint: PocketColor.danger, action: onCancel)
                    .accessibilityLabel("Discard")
                iconButton("checkmark", tint: PocketColor.confirm, action: onConfirm)
                    .accessibilityLabel(isEditingExisting ? "Save range" : "Save loop")
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(PocketColor.background.opacity(0.9))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            )
        }
    }

    /// A round icon button — the loop-capture confirm/discard pair: red ✗, green ✓.
    private func iconButton(_ systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .heavy))
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
