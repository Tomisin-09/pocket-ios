import SwiftUI

// Loop capture models + flow (design brief §4.1 #9), in two keyboard-free-then-
// named steps so the naming field is never hidden behind the keyboard:
//
//   1. `EditToolbar` — the edit-mode control strip (▶ audition · state label ·
//      Y/N) shown in place of the mode-instructions line once a loop is captured
//      (Tap punch-out / Fine selection), with the transport greyed/locked. Y commits
//      / opens naming, N discards — letters, so the decision never reads as a name.
//   2. `LoopNameSheet` — a native sheet (manages its own keyboard inset) that
//      opens on Y (for a new loop) to name it.

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

    /// A confirmed loop awaiting a name (drives the naming sheet).
    struct NamingDraft: Identifiable {
        let id = UUID()
        var start: Double
        var end: Double
    }
}

/// Step 1 — the edit-mode control strip, shown in place of the mode-instructions
/// line while a loop is being created or its range adjusted (the whole transport is
/// greyed/locked meanwhile, so this is the only live control surface). A ▶/⏸ button
/// **auditions** the captured region, a label says which state you're in, and a
/// **Y/N** pill commits (Y → save / open naming) or discards (N). Letters, not ✓/✗,
/// so the decision can't be mistaken for the loop's name.
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
                letterButton("N", tint: PocketColor.danger, action: onCancel)
                    .accessibilityLabel("Discard")
                letterButton("Y", tint: PocketColor.active, action: onConfirm)
                    .accessibilityLabel(isEditingExisting ? "Save range" : "Name loop")
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(PocketColor.background.opacity(0.9))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            )
        }
    }

    private func letterButton(_ letter: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

/// Step 2 — name the new loop. Just a name (its range is already shown on the
/// waveform); a native sheet, so the keyboard never occludes it. Editing an existing
/// loop uses the fuller `LoopEditSheet`.
struct LoopNameSheet: View {
    /// Save with the entered name (empty → caller falls back to the range string).
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
        .presentationDetents([.height(180)])
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
