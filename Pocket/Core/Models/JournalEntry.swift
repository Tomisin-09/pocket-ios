import Foundation
import SwiftData

/// Which kind of owner an entry belongs to — the **single** discriminator, replacing the
/// hand-written `entry.exercise != nil` tests that used to decide it at each render site (ADR 0143).
/// Those tests were only ever right because there were exactly two owners: a session entry sets
/// *neither* relationship, and every one of them would have been rendered as a loop entry.
enum JournalEntryOwnerKind {
    case exercise
    case loop
    /// A whole routine session (ADR 0143) — owned by no unit, identified by a loose `routineUID`.
    case session
    /// A note that belongs to **nothing** and says so (ADR 0155) — written from the Journal space or
    /// the Metronome, about practice generally rather than about a unit. Renders exactly like
    /// `.orphan` today; it is a distinct case because identical rendering is not identical meaning,
    /// and there is no backfill for a distinction that was never recorded.
    case standalone
    /// A sitting at the **free-play metronome** (ADR 0160) — ownerless like `.standalone`, but with a
    /// complete context of its own (tempo, meter, subdivision, withdrawal) that it snapshots and
    /// renders. Reverses ADR 0155 §8's refusal: what that decision objected to was a *fragment* of a
    /// unit's context with no unit behind it, and a full description of a click is not that.
    case metronome
    /// The owner was deleted and the relationship nullified. Nothing to render a snapshot from.
    case orphan
}

/// A single dated entry in a practice journal (ADR 0038). It **snapshots its owner's
/// context** at the moment of writing, so the entry stays a truthful record of where
/// things stood even as the owner keeps moving. The snapshot and timestamp are immutable;
/// only `text` and `kind` are editable.
///
/// The owner is polymorphic (ADR 0058 / 0143), and `ownerKind` is the one place that decides which:
/// - a **loop** entry snapshots mastery (dots) + `commandTempoAtEntry` (song fraction);
/// - an **exercise** entry snapshots `commandBpmAtEntry` (absolute BPM) and has no mastery;
/// - a **session** entry (ADR 0143) belongs to a routine *sitting* rather than a unit, and snapshots
///   the routine's name and the units practised — it has no single tempo to record, which is exactly
///   why it needed fields of its own rather than borrowing a unit's.
///
/// Use the `forLoop`/`forExercise`/`forSession` factories so each entry's snapshot stays honest to
/// its owner.
@Model
final class JournalEntry {
    /// Stable business id — list diffing / undo, like `Loop`/`Marker`.
    var uid: UUID
    /// When the entry was written. Entries list newest-first.
    var createdAt: Date
    /// The user's annotation — the only free-text field, and editable after creation.
    var text: String

    /// Context snapshot — the loop's `mastery` copied at creation and never updated; `nil`
    /// when the loop was unrated at the time (ADR 0039). Denormalised on purpose (ADR 0038):
    /// the entry must not drift as the loop improves. Optional so an entry written against an
    /// unrated loop records "unrated," not a defaulted `0`. (Pre-0039 entries keep their
    /// stored value — they were genuinely written under the old defaulted semantics.)
    var masteryAtEntry: Int?
    /// Context snapshot — the loop's `commandTempo` copied at creation, never updated; `nil`
    /// when never measured at the time (ADR 0039). Optional for the same reason as
    /// `masteryAtEntry`. Loop-only — a **song fraction**; exercises snapshot `commandBpmAtEntry`.
    var commandTempoAtEntry: Double?

    /// Context snapshot for an **exercise** entry — the exercise's command in **absolute BPM**
    /// copied at creation, never updated (ADR 0058). A distinct field, *not* the loop's
    /// `commandTempoAtEntry`, so a BPM is never stored in a `Double` documented as a song
    /// fraction (the defaulted-semantics lie ADR 0039 removed). `nil` for loop entries and for
    /// an un-promoted exercise at the time. Additive optional column — pre-0058 loop entries read
    /// `nil`.
    ///
    /// **Exercise entries snapshot `masteryAtEntry` too** (ADR 0169). This comment used to say they
    /// had no mastery to snapshot; that was true under ADR 0058 and stopped being true on 2026-07-08
    /// when ADR 0072 gave `Exercise` a `mastery`, and was never revisited — so exercise entries kept
    /// the tempo and silently dropped the rating while loop entries kept both. Entries written before
    /// the fix genuinely don't know theirs and are **not** back-filled: the snapshot is immutable
    /// (ADR 0038), and inventing today's rating for a note written months ago would be the exact
    /// defaulted-semantics lie ADR 0039 removed.
    var commandBpmAtEntry: Int?

    /// The **rhythm** that BPM was measured in — notes per beat — snapshotted beside it (ADR 0121).
    /// Without it an old entry's "80 BPM" is unreadable the moment the drill's rhythm moves: the
    /// number is preserved, but what it counted is not. `nil` for loop entries, for an un-promoted
    /// exercise, and for entries written before this existed — those genuinely don't know, and are
    /// rendered as a bare BPM rather than being back-stamped with a rhythm nobody recorded (the
    /// snapshot is immutable, ADR 0038). Additive optional column.
    var commandNotesPerBeatAtEntry: Int?

    /// Backing storage for `kind` — a plain `String`, **not** the enum itself (the
    /// SwiftData enum-attribute migration rule; see `Loop.loopTypeRaw`). Empty/unknown
    /// reads as `.note`. Declaration default so the column always has a value.
    var kindRaw: String = EntryKind.default.rawValue

    /// Typed view over `kindRaw`; unrecognised/empty reads as the default (`.note`).
    var kind: EntryKind {
        get { EntryKind(raw: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    /// The loop this entry belongs to (cascade-owned by `Loop.journal`), or `nil` for an
    /// exercise entry. Exactly one of `loop`/`exercise` is set — an entry has a **single
    /// owner** (ADR 0058).
    var loop: Loop?

    /// The exercise this entry belongs to (cascade-owned by `Exercise.journal`), or `nil` for
    /// a loop entry. Additive optional relationship — pre-0058 loop entries read `nil` (no
    /// store wipe, CoreData 134110 rule / ADR 0012). See `loop` for the single-owner rule.
    var exercise: Exercise?

    /// The `uid` of the routine a **session** entry reflects on (ADR 0143); `nil` for a unit-owned
    /// entry. A **loose copy**, deliberately not a relationship — deleting a routine must not delete
    /// the reflection written about it, the same rule `PracticeRun.routineUID` states. Additive
    /// optional with **no declaration default**, so lightweight migration is exempt from the
    /// CoreData 134110 mandatory-attribute rule.
    var routineUID: UUID?

    /// The routine's name at write time — a session entry's owner caption. Snapshotted rather than
    /// looked up through `routineUID`, so a renamed or deleted routine still labels its entries
    /// truthfully (ADR 0038). `nil` for a unit-owned entry.
    var routineNameAtEntry: String?

    /// The unit's caption at write time — the loop or exercise counterpart to `routineNameAtEntry`,
    /// kept so a note that **outlives** its unit still says what it was about (ADR 0151). `loop` and
    /// `exercise` nullify on deletion, so without this a surviving note loses its attribution
    /// entirely. `nil` for session entries (which have `routineNameAtEntry`) and for notes written
    /// before this shipped. Additive optional with **no declaration default** (CoreData 134110).
    var ownerLabelAtEntry: String?

    /// Backing storage for `practisedUnits` — JSON in a plain `String`, **not** a `Codable` array
    /// attribute (the SwiftData non-primitive-attribute rule; see `kindRaw`). `nil` for a unit-owned
    /// entry and for a session with nothing playable in it.
    var practisedUnitsRaw: String?

    /// The units this session was made of (ADR 0143) — the entry's "you practised…" header, and the
    /// links under it. Reading an unparseable payload yields an empty list, never a trap.
    var practisedUnits: [SessionUnitRef] {
        get { SessionUnitRef.decode(practisedUnitsRaw) }
        set { practisedUnitsRaw = SessionUnitRef.encode(newValue) }
    }

    /// Marks an entry that belongs to **nothing** (ADR 0155) — set once at creation, never cleared.
    ///
    /// A stored flag rather than "no owner is set", which would be free but wrong: **absence is
    /// already taken.** ADR 0151 spent it on `.orphan`, the state of a note whose unit was deleted and
    /// whose relationship nullified. Deriving a second meaning from the same absent state is the
    /// mistake ADR 0143 was written to correct. Additive optional with **no declaration default**, so
    /// lightweight migration is exempt from the CoreData 134110 mandatory-attribute rule — and `nil`
    /// on every pre-0155 row is correct, since every entry written before this is owned or orphaned.
    var isStandalone: Bool?

    /// Marks an entry written at the **metronome** (ADR 0160) — set once at creation, never cleared.
    ///
    /// Its own byte rather than `metronomeBeatsAtEntry != nil`, which would classify the entry for
    /// free. That test isn't the *absence* mistake `isStandalone` avoids — a non-nil column is a
    /// positive fact — it is a worse relative of it: it makes the entry's **kind** a function of its
    /// **payload**, so a column that later becomes optional-within-the-kind, or a bug in the write
    /// order, silently turns a metronome note into an orphan. The kind is what the whole render path
    /// branches on (ADR 0143). Additive optional, **no declaration default** (CoreData 134110).
    ///
    /// A metronome entry leaves `isStandalone` nil: the two flags **partition** rather than nest, so
    /// no entry needs `ownerKind`'s ordering to decide which of two true flags counts. Nothing outside
    /// `ownerKind` may read either.
    var isMetronome: Bool?

    /// Context snapshot for a **metronome** entry (ADR 0160 §2) — the click rate at the moment the
    /// composer opened. `nil` for every other owner kind.
    var metronomeBpmAtEntry: Int?

    /// Context snapshot — the meter's numerator (clicks per bar). Stored as the two `Int`s a
    /// `TimeSignature` is built from, **never the struct itself**: a custom type as a SwiftData
    /// attribute crashes on migration on device only, where in-memory tests miss it entirely
    /// (`docs/swiftdata-gotchas.md`; `Loop.loopTypeRaw` is the precedent).
    var metronomeBeatsAtEntry: Int?

    /// Context snapshot — the meter's denominator. See `metronomeBeatsAtEntry` for why it's an `Int`.
    var metronomeNoteValueAtEntry: Int?

    /// Backing storage for the entry's subdivision — `Subdivision.rawValue`, a plain `String`.
    /// **`.none` is `""`**, so an empty string is a recorded "no subdivision" and `nil` is "never
    /// recorded"; the read path must not collapse the two.
    var metronomeSubdivisionRaw: String?

    /// Backing storage for the entry's click withdrawal — `ClickWithdrawal.rawValue`. The tier that
    /// was **in force** (`activeWithdrawal`), not the one configured, so a note written mid-ramp
    /// doesn't claim a withdrawal the player never heard (ADR 0160 §4).
    var metronomeWithdrawalRaw: String?

    /// The metronome sitting this entry snapshotted, or `nil` when it isn't a metronome entry (or
    /// predates the columns). Rebuilt from the raw columns, never stored as a value.
    var metronomeContext: MetronomeJournalContext? {
        MetronomeJournalContext(beats: metronomeBeatsAtEntry, noteValue: metronomeNoteValueAtEntry,
                                bpm: metronomeBpmAtEntry, subdivisionRaw: metronomeSubdivisionRaw,
                                withdrawalRaw: metronomeWithdrawalRaw)
    }

    /// **The** owner discriminator — read this rather than testing a relationship for `nil` by hand.
    /// Order matters: the two unit relationships win, so an entry can never be mistaken for a session
    /// just because a `routineUID` was also stamped on it — and the standalone flag is read *last*, so
    /// a standalone note can never be mistaken for an owned one either (ADR 0155 §1).
    var ownerKind: JournalEntryOwnerKind {
        if exercise != nil { return .exercise }
        if loop != nil { return .loop }
        if routineUID != nil { return .session }
        if isMetronome == true { return .metronome }
        if isStandalone == true { return .standalone }
        return .orphan
    }

    init(text: String, kind: EntryKind, masteryAtEntry: Int?, commandTempoAtEntry: Double?,
         commandBpmAtEntry: Int? = nil, commandNotesPerBeatAtEntry: Int? = nil,
         createdAt: Date = Date()) {
        self.uid = UUID()
        self.createdAt = createdAt
        self.text = text
        self.kindRaw = kind.rawValue
        self.masteryAtEntry = masteryAtEntry
        self.commandTempoAtEntry = commandTempoAtEntry
        self.commandBpmAtEntry = commandBpmAtEntry
        self.commandNotesPerBeatAtEntry = commandNotesPerBeatAtEntry
    }

    /// A **loop** entry — snapshots the loop's mastery (dots) and song-fraction command tempo.
    /// The exercise-only `commandBpmAtEntry` stays `nil` (ADR 0058).
    static func forLoop(text: String, kind: EntryKind, masteryAtEntry: Int?,
                        commandTempoAtEntry: Double?, createdAt: Date = Date()) -> JournalEntry {
        JournalEntry(text: text, kind: kind, masteryAtEntry: masteryAtEntry,
                     commandTempoAtEntry: commandTempoAtEntry, createdAt: createdAt)
    }

    /// An **exercise** entry — snapshots the command in absolute BPM and the self-rating beside it
    /// (ADR 0058; mastery added by ADR 0169). `commandTempoAtEntry` stays `nil`: that field is
    /// documented as a *song fraction*, and an exercise has no song to be a fraction of.
    ///
    /// `masteryAtEntry` is defaulted so the preview and seed call sites that state no rating still
    /// read as before; the one real caller (`JournalOwner`) passes the exercise's rating.
    static func forExercise(text: String, kind: EntryKind, commandBpmAtEntry: Int?,
                            commandNotesPerBeatAtEntry: Int? = nil,
                            masteryAtEntry: Int? = nil,
                            createdAt: Date = Date()) -> JournalEntry {
        JournalEntry(text: text, kind: kind, masteryAtEntry: masteryAtEntry, commandTempoAtEntry: nil,
                     commandBpmAtEntry: commandBpmAtEntry,
                     commandNotesPerBeatAtEntry: commandNotesPerBeatAtEntry, createdAt: createdAt)
    }

    /// A **session** entry (ADR 0143) — owned by a routine sitting rather than a unit. Every tempo
    /// and mastery snapshot stays `nil`: a session spans several units at several tempos, so there is
    /// no one number that would be true, and inventing one would be exactly the defaulted-semantics
    /// lie ADR 0039 removed. What it snapshots instead is the routine's name and what was practised.
    static func forSession(text: String, kind: EntryKind, routineUID: UUID,
                           routineName: String, units: [SessionUnitRef],
                           createdAt: Date = Date()) -> JournalEntry {
        let entry = JournalEntry(text: text, kind: kind, masteryAtEntry: nil,
                                 commandTempoAtEntry: nil, createdAt: createdAt)
        entry.routineUID = routineUID
        entry.routineNameAtEntry = routineName
        entry.practisedUnits = units
        return entry
    }

    /// A **standalone** entry (ADR 0155) — about practice generally rather than about any unit.
    /// Every snapshot field stays `nil`, and that is the whole point: there is nothing here to be
    /// honest *about*, and half a snapshot (a tempo with no unit attached to it) is the lending of
    /// false context this ADR exists to stop. `ownerLabelAtEntry` stays `nil` too, so the feed
    /// renders no caption.
    static func forStandalone(text: String, kind: EntryKind,
                              createdAt: Date = Date()) -> JournalEntry {
        let entry = JournalEntry(text: text, kind: kind, masteryAtEntry: nil,
                                 commandTempoAtEntry: nil, createdAt: createdAt)
        entry.isStandalone = true
        return entry
    }

    /// A **metronome** entry (ADR 0160) — written at the free-play click, which owns no unit but has a
    /// complete context of its own. Every unit snapshot field stays `nil` (there is no mastery, no
    /// song fraction, and no *command* — nothing here was promoted or measured, which is why this does
    /// not reuse `commandBpmAtEntry`), and the four metronome values are stored as raw columns.
    ///
    /// `isStandalone` is deliberately left `nil`: the flags partition, and `ownerKind` reads
    /// `isMetronome` first.
    static func forMetronome(text: String, kind: EntryKind, context: MetronomeJournalContext,
                             createdAt: Date = Date()) -> JournalEntry {
        let entry = JournalEntry(text: text, kind: kind, masteryAtEntry: nil,
                                 commandTempoAtEntry: nil, createdAt: createdAt)
        entry.isMetronome = true
        entry.metronomeBpmAtEntry = context.bpm
        entry.metronomeBeatsAtEntry = context.timeSignature.beats
        entry.metronomeNoteValueAtEntry = context.timeSignature.noteValue
        entry.metronomeSubdivisionRaw = context.subdivision.rawValue
        entry.metronomeWithdrawalRaw = context.withdrawal.rawValue
        return entry
    }
}
