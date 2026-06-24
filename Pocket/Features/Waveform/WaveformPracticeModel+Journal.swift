import SwiftData
import SwiftUI

// MARK: - Loop journal actions (ADR 0038)

extension WaveformPracticeModel {

    /// Add a dated entry to a loop's practice journal, **snapshotting the loop's
    /// context** — its current `mastery` and `commandTempo` — at the moment of writing.
    /// The snapshot is copied, not referenced, so the entry stays a truthful record as
    /// the loop keeps improving (ADR 0038). Text is trimmed; an all-whitespace entry is
    /// ignored. Returns whether an entry was actually added.
    @discardableResult
    func addJournalEntry(to loop: Loop, text: String, kind: EntryKind) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let entry = JournalEntry(text: trimmed, kind: kind,
                                 masteryAtEntry: loop.mastery,
                                 commandTempoAtEntry: loop.commandTempo)
        context.insert(entry)
        entry.loop = loop          // attach → shows in `loop.journal`, persists
        haptic(.light)
        return true
    }

    /// Edit an existing entry — **text and kind only**. The timestamp and the
    /// mastery/command-tempo snapshot are immutable (ADR 0038), so they're never
    /// touched here. A cleared text leaves the entry unchanged (delete to remove).
    func updateJournalEntry(_ entry: JournalEntry, text: String, kind: EntryKind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entry.text = trimmed       // mutating the @Model persists
        entry.kind = kind
    }

    /// Delete a journal entry. No Undo toast (unlike loops/markers): the journal is a
    /// modal sheet over the practice surface, where the toast would be hidden — the
    /// swipe-to-delete affordance is the deliberate, reversible-by-re-adding action.
    func deleteJournalEntry(_ entry: JournalEntry) {
        context.delete(entry)
        haptic(.light)
    }
}
