import SwiftData
import SwiftUI

/// Saving the routine screen's sandbox, and what a failed save says (ADR 0318).
///
/// The sandbox is a context of its own with autosave off, so a save that fails here is never picked up
/// later: before 0318 the screen left edit mode as if it had saved, and the edit was gone after a
/// relaunch. A failed save now keeps the screen as it was and says *Couldn’t save*. *Try again* saves the
/// sandbox again, and then does what the save was for: leaves edit mode, or opens the player.
extension RoutineDetailView {
    /// What follows a save once it works.
    enum AfterSave { case stored, start }

    /// Save the sandbox. On failure, say so, and remember what was to follow for *Try again*.
    func saveSandbox(then next: AfterSave) -> Bool {
        guard editContext.saveOrLog() else {
            afterSave = next
            saveFailed = true
            return false
        }
        return true
    }

    /// The routine is in the store and the screen leaves edit mode.
    func markStored() {
        existsInStore = true
        isEditing = false
        insertingRests = false
    }

    /// *Try again*: the save alone, since the edit is already in the sandbox, then what it was for.
    func retrySave() {
        guard editContext.saveOrLog() else { saveFailed = true; return }
        markStored()
        switch afterSave {
        case .stored: haptic(.medium)
        case .start: openPlayer()
        }
    }

    // MARK: - Commit / discard

    /// Commit the sandbox and drop back to the read-only view. A brand-new routine with nothing in it
    /// is dismissed rather than saved (an abandoned "New routine" leaves no empty shell).
    ///
    /// "Nothing in it" counts the **description** too (ADR 0177): typing what a session is for and
    /// nothing else is thin, but it is something the player wrote, and dropping it on Save would be
    /// the screen discarding work without saying so.
    func saveEdits() {
        trimDescription()
        if !existsInStore && routine.items.isEmpty && routine.notes.isEmpty
            && routine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            dismiss()
            return
        }
        guard saveSandbox(then: .stored) else { return }
        markStored()
        haptic(.medium)
    }

    /// Discard in-flight edits. A new routine has nothing to return to, so it dismisses; an existing
    /// one rebuilds a clean sandbox from the store and returns to the read-only view.
    func cancelEdits() {
        // Leaving edit mode must leave rest-insert mode with it — the gap rows are an editing
        // affordance, and their only way out is hidden once the add section goes.
        insertingRests = false
        restGuardSlot = nil
        discardUnsavedReferenceImages()
        guard existsInStore else { dismiss(); return }
        rebuildSandbox()
        isEditing = false
        haptic(.light)
    }
}
