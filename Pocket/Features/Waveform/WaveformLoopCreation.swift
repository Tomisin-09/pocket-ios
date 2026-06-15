import SwiftUI

/// Inline loop-creation panel (design brief §4.1 #9). Slides in below the
/// transport the moment a loop is captured, so the loop can be **named on
/// capture** before it lands in the Loops panel. Speed/repeats default from the
/// current session and are refined later in the edit sheet; naming is the focus
/// here.
struct LoopCreationPanel: View {
    /// The captured range, preformatted (e.g. `0:42–1:08`).
    let range: String
    /// Save with the entered name (empty → caller falls back to the range).
    let onSave: (String) -> Void
    let onDiscard: () -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("New loop")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer()
                Text(range)
                    .font(.pocketMono(.footnote))
                    .foregroundStyle(PocketColor.marker)
            }

            TextField("Name this loop", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { onSave(name) }

            HStack {
                Button("Discard", role: .cancel) { onDiscard() }
                    .foregroundStyle(PocketColor.textSecondary)
                Spacer()
                Button("Save loop") { onSave(name) }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketColor.active)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PocketColor.active.opacity(0.5), lineWidth: 1)
                )
        )
        .onAppear { nameFocused = true }
    }
}
