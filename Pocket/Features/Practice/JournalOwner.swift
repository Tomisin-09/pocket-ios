import SwiftData
import SwiftUI

/// What a **session** journal entry is written about (ADR 0143) — a routine *sitting*, not a unit.
///
/// A plain value type rather than a model, because a session has no stored identity in this app and
/// doesn't need one: `PracticeLog.Sitting` derives sittings from the log instead of storing them, and
/// the entry's own `uid` + `createdAt` already are the occurrence. What the entry keeps is a **loose
/// copy** of the routine's id and name and of the units practised, so the reflection outlives every
/// one of them (the rule `PracticeRun` states for `routineUID`).
struct SessionJournalContext {
    let routineUID: UUID
    /// The routine's name as it read at the time — stored raw, including empty. The fallback wording
    /// belongs to whichever surface is displaying it, not to the snapshot.
    let routineName: String
    let units: [SessionUnitRef]

    init(routineUID: UUID, routineName: String, units: [SessionUnitRef]) {
        self.routineUID = routineUID
        self.routineName = routineName
        self.units = units
    }

    /// Build the context from the finished player's stages.
    ///
    /// Rests are dropped (nothing was practised), and so are **songs** — a song has no standalone run
    /// surface to link to (ADR 0069 slice 4 / ADR 0142 J5a), so a song pill could only ever be dead
    /// text. Repeats are **deduped by `uid`**, preserving play order: a routine that opens and closes
    /// on the same warm-up practised it once as far as a reader is concerned.
    ///
    /// Titles come from the **stage**, which is where the empty-name fallbacks ("Exercise", "Loop")
    /// already live, so a pill reads exactly as the block did in the player.
    init(routine: Routine, stages: [RoutineStage]) {
        routineUID = routine.uid
        routineName = routine.name
        var seen = Set<UUID>()
        units = stages.compactMap { stage -> SessionUnitRef? in
            if let exercise = stage.exercise {
                return SessionUnitRef(uid: exercise.uid, title: stage.title, kind: .exercise)
            }
            if let loop = stage.loop {
                return SessionUnitRef(uid: loop.uid, title: stage.title, kind: .loop)
            }
            return nil
        }
        .filter { seen.insert($0.uid).inserted }
    }
}

/// What a journal entry belongs to (ADR 0058 / 0143) — a **loop**, an **exercise**, or a whole
/// **session**. Adapts each owner for the shared `JournalSheet` and `JournalWriter`: the entries it
/// holds, and what a freshly written entry snapshots. Loops snapshot mastery + a song-fraction
/// command tempo; exercises snapshot an absolute command BPM and have no mastery (kept honest per
/// ADR 0058/0039); a session has no single tempo at all and snapshots what was practised instead.
enum JournalOwner {
    case loop(Loop)
    case exercise(Exercise)
    /// A routine sitting (ADR 0143). Unlike the other two this owner has **no journal to read** — it
    /// holds no relationship, so `entries` is always empty. It exists only at the write seam (the
    /// session-complete screen) and is never a `JournalSheet` subject; its entries are read on the
    /// aggregated Journal feed like any other.
    case session(SessionJournalContext)
    /// **No owner at all** (ADR 0155) — a note about practice generally, written from the Journal
    /// space or the Metronome. Like `.session` it holds no relationship and has no journal to read,
    /// so it exists only at the write seam; unlike `.session` it carries no context whatsoever,
    /// because there is none to carry.
    case standalone

    /// Entries newest-first — the order the journal lists them in.
    var entriesByRecent: [JournalEntry] {
        switch self {
        case .loop(let loop): loop.journalByRecent
        case .exercise(let exercise): exercise.journalByRecent
        case .session, .standalone: []
        }
    }

    /// All entries (unordered) — used for day-grouping and the empty-state check.
    var entries: [JournalEntry] {
        switch self {
        case .loop(let loop): loop.journal
        case .exercise(let exercise): exercise.journal
        case .session, .standalone: []
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    /// What to call the owner in a composer that isn't already on its screen — the compact capture
    /// sheet says which unit the note lands on (ADR 0142). Falls back to the owner's kind rather than
    /// an empty string, matching `JournalTimeline.ownerLabel`'s handling of an unnamed unit.
    ///
    /// **`.standalone` has no honest value here** (ADR 0155 §5) — it is never a name because it is
    /// never a thing. Both callers that can reach one go through `destinationLine` instead, and
    /// `JournalNoteComposer` (which still reads this) is only ever hosted on a run screen, so it never
    /// sees a standalone owner. The fallback is deliberately a *string* and not a
    /// `preconditionFailure`: this repo's standing trade is that a sentence reading oddly is a far
    /// smaller failure than a crash, and a visibly silly "your Journal's Journal" is a fine bug signal
    /// if a future surface ever wires one through by mistake.
    var displayName: String {
        switch self {
        case .loop(let loop): loop.name.isEmpty ? "this loop" : loop.name
        case .exercise(let exercise): exercise.name.isEmpty ? "this exercise" : exercise.name
        case .session(let context): context.routineName.isEmpty ? "this session" : context.routineName
        case .standalone: "your Journal"
        }
    }

    /// One true **whole sentence** about where a new entry lands and what it snapshots — the compact
    /// composer's footer copy.
    ///
    /// A whole sentence rather than ADR 0142's two assembled fragments (`"Saves to \(displayName)'s
    /// Journal, \(snapshotBlurb)."`), because neither fragment has an honest value for an owner that
    /// is not a thing and records nothing: patching them yields "Saves to your Journal's Journal"
    /// (ADR 0155 §5). One caller, so owning the whole sentence costs nothing.
    var destinationLine: String {
        switch self {
        case .loop, .exercise:
            return "Saves to \(displayName)'s Journal, snapshotting where the unit stands right now."
        case .session:
            return "Saves to \(displayName)'s Journal, snapshotting what you practised in this session."
        case .standalone:
            return "Saves straight to your Journal — not attached to any loop or exercise."
        }
    }
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
            // Snapshot the caption beside the relationship (ADR 0151): the link nullifies when the
            // loop is deleted, and an unattributed note is a worse record than none.
            entry.ownerLabelAtEntry = JournalTimeline.ownerLabel(loop: loop, exercise: nil, song: nil)
        case .exercise(let exercise):
            // Snapshot the measured command in absolute BPM — `nil` when un-promoted, so the
            // entry records "not yet measured" rather than a defaulted value (ADR 0058/0039).
            // …and the rhythm it was measured in beside it (ADR 0121), so the number stays readable
            // after the drill's rhythm moves.
            let entry = JournalEntry.forExercise(text: trimmed, kind: kind,
                                                 commandBpmAtEntry: exercise.commandTempo,
                                                 commandNotesPerBeatAtEntry: exercise.commandNotesPerBeat)
            context.insert(entry)
            entry.exercise = exercise
            entry.ownerLabelAtEntry = JournalTimeline.ownerLabel(loop: nil, exercise: exercise,
                                                                 song: nil)
        case .session(let session):
            // No relationship to assign — a session entry is owned by loose id copies, so it survives
            // the routine and every unit in it being deleted (ADR 0143). Insert and that's all.
            let entry = JournalEntry.forSession(text: trimmed, kind: kind,
                                                routineUID: session.routineUID,
                                                routineName: session.routineName,
                                                units: session.units)
            context.insert(entry)
        case .standalone:
            // No relationship, no snapshot, no caption — the entry declares its ownerlessness with
            // the stored `isStandalone` flag rather than by *not* having an owner, because absence
            // already means `.orphan` (ADR 0155 §1).
            let entry = JournalEntry.forStandalone(text: trimmed, kind: kind)
            context.insert(entry)
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
