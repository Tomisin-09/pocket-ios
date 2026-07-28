import SwiftUI

/// The two ways a fretboard drill's content is authored (ADR 0107): the generative editor, or the
/// hand-drawn canvas. Shared by the create form (`ConfigureExerciseForm`) and the edit-shape sheet
/// (`ExerciseShapeSheet`) so the one gated toggle below serves both.
enum AuthoringMode: Hashable { case generate, draw }

/// The **generate-or-draw** authoring toggle (ADR 0107) with the Red Moon Pro gate baked in (ADR
/// 0112). "Draw your own" is a Pro capability **even on a free-tier family** (e.g. Warm-up), so for a
/// free player the Draw segment is **greyed out**, carries a **PRO** badge, and taps to the **paywall**
/// instead of switching. Pro players get an ordinary two-way toggle.
///
/// A custom two-segment control rather than a native segmented `Picker`, which can neither disable nor
/// annotate a single segment. Styled to read like the app's segmented controls (surface fill, an
/// emphasised selected segment) via `PocketColor` + Futura.
struct AuthoringModePicker: View {
    @Binding var mode: AuthoringMode

    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

    var body: some View {
        HStack(spacing: 4) {
            segment(.generate, label: "Generate")
            segment(.draw, label: "Draw your own")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 9).fill(PocketColor.surfaceStandard))
    }

    private func segment(_ value: AuthoringMode, label: String) -> some View {
        let selected = mode == value
        let locked = value == .draw && !isPro
        return Button {
            if locked {
                presentPaywall(.drawYourOwn)
            } else {
                mode = value
                haptic(.light)
            }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.futura(.subheadline, weight: selected ? .semibold : .regular))
                if locked { proBadge }
            }
            .foregroundStyle(segmentTint(selected: selected, locked: locked))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selected ? PocketColor.surfaceEmphasis : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(locked ? "Red Moon Pro" : "")
    }

    private func segmentTint(selected: Bool, locked: Bool) -> Color {
        if locked { return PocketColor.textSecondary.opacity(0.5) }
        return selected ? PocketColor.textPrimary : PocketColor.textSecondary
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.futura(.caption2, weight: .bold))
            .foregroundStyle(PocketColor.background)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(PocketColor.practice))
    }
}

#Preview("Free — draw locked") {
    struct Harness: View {
        @State private var mode: AuthoringMode = .generate
        var body: some View {
            AuthoringModePicker(mode: $mode)
                .padding()
                .environment(\.isPro, false)
        }
    }
    return Harness().background(PocketColor.background)
}

#Preview("Pro — both open") {
    struct Harness: View {
        @State private var mode: AuthoringMode = .draw
        var body: some View {
            AuthoringModePicker(mode: $mode)
                .padding()
                .environment(\.isPro, true)
        }
    }
    return Harness().background(PocketColor.background)
}
