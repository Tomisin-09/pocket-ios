import SwiftData
import SwiftUI

/// The unit a journal entry belongs to (ADR 0058) — a **loop** or an **exercise**. Adapts the
/// two owners for the shared `JournalSheet` and `JournalWriter`: the entries it holds, and what a
/// freshly written entry snapshots. Loops snapshot mastery + a song-fraction command tempo;
/// exercises snapshot an absolute command BPM and have no mastery (kept honest per ADR 0058/0039).
enum JournalOwner {
    case loop(Loop)
    case exercise(Exercise)

    /// Entries newest-first — the order the journal lists them in.
    var entriesByRecent: [JournalEntry] {
        switch self {
        case .loop(let loop): loop.journalByRecent
        case .exercise(let exercise): exercise.journalByRecent
        }
    }

    /// All entries (unordered) — used for day-grouping and the empty-state check.
    var entries: [JournalEntry] {
        switch self {
        case .loop(let loop): loop.journal
        case .exercise(let exercise): exercise.journal
        }
    }

    var isEmpty: Bool { entries.isEmpty }
}

/// The single write path for journal entries (ADR 0058), shared by the Practice run screens.
/// Owner-aware: it builds each entry through the matching `JournalEntry.forLoop`/`forExercise`
/// factory so a loop's song-fraction snapshot and an exercise's absolute-BPM snapshot never
/// cross. Pure of haptics/UI — callers fire feedback — so the trim + attach logic stays testable.
enum JournalWriter {

    /// Add a dated entry to the owner's journal, **snapshotting the owner's context** at the
    /// moment of writing (copied, not referenced, so it stays truthful as the unit improves).
    /// Text is trimmed; an all-whitespace entry is ignored. Returns whether an entry was added.
    @discardableResult
    static func add(to owner: JournalOwner, text: String, kind: EntryKind,
                    into context: ModelContext) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        switch owner {
        case .loop(let loop):
            let entry = JournalEntry.forLoop(text: trimmed, kind: kind,
                                             masteryAtEntry: loop.mastery,
                                             commandTempoAtEntry: loop.commandTempo)
            context.insert(entry)
            entry.loop = loop
        case .exercise(let exercise):
            // Snapshot the measured command in absolute BPM — `nil` when un-promoted, so the
            // entry records "not yet measured" rather than a defaulted value (ADR 0058/0039).
            let entry = JournalEntry.forExercise(text: trimmed, kind: kind,
                                                 commandBpmAtEntry: exercise.commandTempo)
            context.insert(entry)
            entry.exercise = exercise
        }
        return true
    }

    /// Edit an existing entry — **text and kind only**. The timestamp and snapshot are immutable
    /// (ADR 0038), so they're never touched. A cleared text leaves the entry unchanged.
    static func update(_ entry: JournalEntry, text: String, kind: EntryKind) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entry.text = trimmed
        entry.kind = kind
    }

    /// Delete a journal entry from the store.
    static func delete(_ entry: JournalEntry, from context: ModelContext) {
        context.delete(entry)
    }
}
