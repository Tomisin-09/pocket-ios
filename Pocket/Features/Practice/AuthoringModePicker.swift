import SwiftUI

/// The two ways a fretboard drill's content is authored (ADR 0107): the generative editor, or the
/// hand-drawn canvas. Shared by the create form (`ConfigureExerciseForm`) and the edit-shape sheet
/// (`ExerciseShapeSheet`) so the one toggle below serves both.
enum AuthoringMode: Hashable { case generate, draw }

/// The **generate-or-draw** authoring toggle (ADR 0107). Both segments are always open.
///
/// A custom two-segment control rather than a native segmented `Picker`: it was built when "Draw your
/// own" had to be disabled and badged on its own, which a native `Picker` cannot do to one segment,
/// and it is kept because it is what the create form and the edit-shape sheet already look like.
/// Styled to read like the app's segmented controls (surface fill, an emphasised selected segment)
/// via `PocketColor` + Futura.
struct AuthoringModePicker: View {
    @Binding var mode: AuthoringMode

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
        return Button {
            mode = value
            haptic(.light)
        } label: {
            Text(label)
                .font(.futura(.subheadline, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? PocketColor.textPrimary : PocketColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selected ? PocketColor.surfaceEmphasis : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Authoring mode") {
    struct Harness: View {
        @State private var mode: AuthoringMode = .generate
        var body: some View {
            AuthoringModePicker(mode: $mode)
                .padding()
        }
    }
    return Harness().background(PocketColor.background)
}
