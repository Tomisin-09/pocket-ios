import SwiftUI

/// A **selected/unselected capsule chip** — the app's one treatment for a control whose state you
/// have to be able to read at a glance.
///
/// It exists because tinting a `Label`'s text is not enough signal on its own. The waveform's
/// **Follow** toggle (v2 close-out N1) is the case that proves it: its only on/off cue was
/// `textPrimary` vs `textSecondary`, and its *effect* doesn't show until the next pinch — so a
/// control that was working read as a dead button. A filled capsule says "on" without waiting for
/// the gesture that would reveal it.
///
/// **Both states are the same size.** Padding is fixed and the font weight is *not* varied, only the
/// fill, stroke and foreground. Chips sit in rows next to other controls (Follow has the **Grid**
/// button beside it), and a chip that grows on selection shoves its neighbour sideways under the
/// player's finger. This is the one thing not to copy from `RoutineBlockDoneView.tagChip`, which
/// bolds when selected because nothing sits to its right.
///
/// Styling of the content itself — font, symbol, layout — belongs to the caller: this is a state
/// treatment, not a text style.
struct ToggleChip<Content: View>: View {
    let isOn: Bool
    var tint: Color = PocketColor.practice
    /// Fires *before* the chip's own haptic, so callers never add their own.
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button {
            action()
            haptic(.light)
        } label: {
            content()
                .foregroundStyle(isOn ? tint : PocketColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isOn ? tint.opacity(0.18) : PocketColor.surfaceStandard))
                .overlay(Capsule().stroke(isOn ? tint : PocketColor.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

#Preview("Toggle chips") {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            ToggleChip(isOn: false) {} content: {
                Label("Follow", systemImage: "scope").font(.futura(.footnote, weight: .medium))
            }
            ToggleChip(isOn: true) {} content: {
                Label("Follow", systemImage: "scope").font(.futura(.footnote, weight: .medium))
            }
        }
        // The two states are deliberately the same width — overlaying them should show no shift.
        HStack(spacing: 8) {
            ToggleChip(isOn: false, tint: PocketColor.library) {} content: {
                Text("E♭").font(.futura(.body))
            }
            ToggleChip(isOn: true, tint: PocketColor.library) {} content: {
                Text("E♭").font(.futura(.body))
            }
        }
    }
    .padding()
    .background(PocketColor.background)
}
