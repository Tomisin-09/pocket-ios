import SwiftUI

// Loop capture models + flow (design brief §4.1 #9), in two keyboard-free-then-
// named steps so the naming field is never hidden behind the keyboard:
//
//   1. `ConfirmBar` — slides in below the transport once a loop is captured
//      (Tap close / Fine selection). Just the range + ✓/✗, no keyboard, so the
//      range can be verified (and re-heard) before committing.
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

/// Step 1 — confirm the captured range (or, when adjusting, the new bounds).
struct ConfirmBar: View {
    let range: String
    /// `true` when adjusting an existing loop's range rather than creating one.
    let isEditing: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(isEditing ? "Adjust range" : "New loop")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(range)
                .font(.pocketMono(.footnote))
                .foregroundStyle(PocketColor.marker)
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(PocketColor.danger)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Discard")
            Button(action: onConfirm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(PocketColor.active)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isEditing ? "Save range" : "Name loop")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PocketColor.active.opacity(0.5), lineWidth: 1)
                )
        )
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
