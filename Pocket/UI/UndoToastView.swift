import SwiftUI

/// Transient "Deleted X · Undo" toast after a destructive action (ADR 0019). A floating pill:
/// the message, then an Undo action. Auto-dismissal is the caller's job (a timer owned by the
/// waveform model, or by `RowDeletionCoordinator` on the list screens); this view just renders
/// and reports the tap.
///
/// Lives in `UI/` rather than the waveform because both destructive surfaces now share it — the
/// waveform's loop/marker deletes (its original home) and every list row's delete via
/// `.pocketRowActions`.
struct UndoToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.active)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Restores the deleted item")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(PocketColor.background.opacity(0.92))
                .overlay(Capsule().strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        )
        .accessibilityElement(children: .combine)
    }
}
