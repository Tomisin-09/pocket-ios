import SwiftUI

// MARK: - Undo toast (ADR 0019)

// Split out of `WaveformPracticeModel+Actions.swift` to keep that file within the
// length limit. The destructive actions (deleteLoop / deleteMarker) live with the
// other actions; the toast plumbing they call lives here.

extension WaveformPracticeModel {
    /// A transient "Deleted X · Undo" message with the closure that reverses the action.
    struct UndoToast: Identifiable {
        let id = UUID()
        let message: String
        let undo: () -> Void
    }

    /// Show an Undo toast, auto-dismissing after a few seconds. A second destructive
    /// action replaces it — the latest delete is the one you can undo.
    func presentUndo(_ message: String, undo: @escaping () -> Void) {
        undoDismiss?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            undoToast = UndoToast(message: message, undo: undo)
        }
        undoDismiss = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.undoToast = nil }
        }
    }

    /// Tapped Undo — run the restore and dismiss the toast.
    func performUndo() {
        undoDismiss?.cancel()
        let toast = undoToast
        withAnimation(.easeOut(duration: 0.2)) { undoToast = nil }
        toast?.undo()
        haptic(.light)
    }
}
