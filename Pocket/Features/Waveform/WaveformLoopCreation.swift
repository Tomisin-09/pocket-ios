import SwiftUI

// Loop capture models + flow (design brief §4.1 #9), in two keyboard-free-then-
// named steps so the naming field is never hidden behind the keyboard:
//
//   1. `ConfirmPopup` — an icon-only ✓/✗ pill floating over the waveform once a
//      loop is captured (Tap punch-out / Fine selection). Deliberately has no
//      text or range, so it never reads as an editable name — it just commits or
//      discards the highlighted region.
//   2. `LoopNameSheet` — a native sheet (manages its own keyboard inset) that
//      opens on ✓ to name the loop.

extension WaveformPracticeView {
    /// A loop being captured, awaiting confirmation. Bounds are mutable so Fine
    /// handles drag them live; `fromFine` shows the blue handles; a non-nil
    /// `editingLoopID` means we're adjusting an existing loop, not creating one.
    struct CaptureDraft {
        var start: Double
        var end: Double
        var fromFine: Bool
        var editingLoopID: WaveformMock.Loop.ID?
    }

    /// A confirmed loop awaiting a name (drives the naming sheet).
    struct NamingDraft: Identifiable {
        let id = UUID()
        var start: Double
        var end: Double
    }
}

/// Step 1 — an icon-only ✓/✗ pill that floats over the waveform to commit or
/// discard the highlighted region. `isEditing` only changes the accessibility
/// label (✓ saves a range edit vs. opens naming); there is no on-pill text.
struct ConfirmPopup: View {
    /// `true` when adjusting an existing loop's range rather than creating one.
    let isEditing: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            iconButton("xmark", tint: PocketColor.danger, action: onCancel)
                .accessibilityLabel("Discard")
            iconButton("checkmark", tint: PocketColor.active, action: onConfirm)
                .accessibilityLabel(isEditing ? "Save range" : "Name loop")
        }
        .padding(3)
        .background(
            Capsule()
                .fill(PocketColor.background.opacity(0.9))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    private func iconButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

/// Step 2 — name the loop. A native sheet, so the keyboard never occludes it.
struct LoopNameSheet: View {
    /// The captured range, preformatted (e.g. `0:42–1:08`).
    let range: String
    /// Save with the entered name (empty → caller falls back to the range).
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Name this loop", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
                Section("Range") {
                    LabeledContent("Loop") {
                        Text(range).font(.pocketMono(.body))
                    }
                }
            }
            .navigationTitle("New loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .presentationDetents([.height(240)])
        .onAppear { nameFocused = true }
    }

    private func save() {
        onSave(name)
        dismiss()
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
