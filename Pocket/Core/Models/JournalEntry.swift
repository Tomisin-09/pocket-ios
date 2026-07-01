import Foundation
import SwiftData

/// A single dated entry in a practice journal (ADR 0038). It **snapshots its owner's
/// context** at the moment of writing, so the entry stays a truthful record of where
/// things stood even as the owner keeps moving. The snapshot and timestamp are immutable;
/// only `text` and `kind` are editable.
///
/// The owner is polymorphic (ADR 0058): exactly one of `loop`/`exercise` is set. A **loop**
/// entry snapshots mastery (dots) + `commandTempoAtEntry` (song fraction); an **exercise**
/// entry snapshots `commandBpmAtEntry` (absolute BPM) and has no mastery. Use the
/// `forLoop`/`forExercise` factories so each entry's snapshot stays honest to its owner.
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
    /// an un-promoted exercise at the time. Exercises have no mastery, so `masteryAtEntry`
    /// stays `nil` for them. Additive optional column — pre-0058 loop entries read `nil`.
    var commandBpmAtEntry: Int?

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

    init(text: String, kind: EntryKind, masteryAtEntry: Int?, commandTempoAtEntry: Double?,
         commandBpmAtEntry: Int? = nil, createdAt: Date = Date()) {
        self.uid = UUID()
        self.createdAt = createdAt
        self.text = text
        self.kindRaw = kind.rawValue
        self.masteryAtEntry = masteryAtEntry
        self.commandTempoAtEntry = commandTempoAtEntry
        self.commandBpmAtEntry = commandBpmAtEntry
    }

    /// A **loop** entry — snapshots the loop's mastery (dots) and song-fraction command tempo.
    /// The exercise-only `commandBpmAtEntry` stays `nil` (ADR 0058).
    static func forLoop(text: String, kind: EntryKind, masteryAtEntry: Int?,
                        commandTempoAtEntry: Double?, createdAt: Date = Date()) -> JournalEntry {
        JournalEntry(text: text, kind: kind, masteryAtEntry: masteryAtEntry,
                     commandTempoAtEntry: commandTempoAtEntry, createdAt: createdAt)
    }

    /// An **exercise** entry — snapshots the command in absolute BPM. Exercises have no mastery
    /// and no song fraction, so both loop snapshot fields stay `nil` (ADR 0058).
    static func forExercise(text: String, kind: EntryKind, commandBpmAtEntry: Int?,
                            createdAt: Date = Date()) -> JournalEntry {
        JournalEntry(text: text, kind: kind, masteryAtEntry: nil, commandTempoAtEntry: nil,
                     commandBpmAtEntry: commandBpmAtEntry, createdAt: createdAt)
    }
}
