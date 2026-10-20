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
    /// A second line, for a delete that keeps something (ADR 0264 D2): *"Its 2 references stay in
    /// References"*. The toast grows to two lines for it and stays one line without.
    var detail: String?
    /// What Undo does, for VoiceOver. The song map's Undo takes back what it made (ADR 0232 D17).
    var hint = "Restores the deleted item"
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.active)
            }
            .buttonStyle(.plain)
            .accessibilityHint(hint)
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
