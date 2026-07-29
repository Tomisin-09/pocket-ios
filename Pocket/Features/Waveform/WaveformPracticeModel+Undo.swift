import SwiftUI

// MARK: - Undo toast (ADR 0019)

// Split out of `WaveformPracticeModel+Actions.swift` to keep that file within the
// length limit. The destructive actions (deleteLoop / deleteMarker) live with the
// other actions; the toast plumbing they call lives here.

extension WaveformPracticeModel {
    /// A transient "Deleted X · Undo" message with the closure that reverses the action —
    /// and, since ADR 0125, the closure that **finalises** it. Deletes here are deferred
    /// (the row hides, the object is destroyed only once the window closes), so the toast
    /// owns both halves: `undo` un-hides, `commit` destroys.
    struct UndoToast: Identifiable {
        let id = UUID()
        let message: String
        let undo: () -> Void
        var commit: (() -> Void)?
    }

    /// Show an Undo toast, auto-dismissing after a few seconds. A second destructive
    /// action replaces it — the latest delete is the one you can undo — and **commits**
    /// the one it replaces, so a superseded delete still happens.
    func presentUndo(_ message: String, undo: @escaping () -> Void, commit: (() -> Void)? = nil) {
        let outgoing = undoToast
        undoDismiss?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            undoToast = UndoToast(message: message, undo: undo, commit: commit)
        }
        outgoing?.commit?()
        undoDismiss = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.expireUndo()
        }
    }

    /// The window closed untouched — the delete stands.
    private func expireUndo() {
        let toast = undoToast
        withAnimation(.easeOut(duration: 0.2)) { undoToast = nil }
        toast?.commit?()
    }

    /// Tapped Undo — run the restore and dismiss the toast. The commit is deliberately
    /// *not* run: that's the whole point.
    func performUndo() {
        undoDismiss?.cancel()
        let toast = undoToast
        withAnimation(.easeOut(duration: 0.2)) { undoToast = nil }
        toast?.undo()
        haptic(.light)
    }

    /// Leaving the screen with a delete still deferred — finalise it rather than carry a
    /// half-deleted list into the next visit. Nothing is ever *lost* by a missed commit
    /// (the worst case is a delete that didn't happen), so this is a tidy-up, not a
    /// correctness requirement.
    func commitDeferredDeletes() {
        undoDismiss?.cancel()
        let toast = undoToast
        undoToast = nil
        toast?.commit?()
    }
}
