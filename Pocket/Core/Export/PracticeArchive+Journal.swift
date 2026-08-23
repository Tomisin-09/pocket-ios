import Foundation

// What the player wrote, and what they recorded.

/// One entry in the journal — a reflection on a unit, on a whole session, on the metronome, or on
/// nothing at all (ADR 0155).
///
/// The owner columns are exported exactly as the model keeps them, and the model keeps them in two
/// different ways on purpose: `loop` and `exercise` are relationships, so they nullify when the unit is
/// deleted and the entry survives as an orphan; `routineUID` is a **loose id** with the routine's name
/// snapshotted beside it, so deleting a routine cannot delete the reflection written about a session it
/// appeared in. Both shapes cross into the archive unchanged.
struct JournalEntryRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var createdAt: Date
    var text: String
    var kindRaw: String

    var masteryAtEntry: Int?
    var commandTempoAtEntry: Double?
    var commandBpmAtEntry: Int?
    var commandNotesPerBeatAtEntry: Int?

    var loopUID: UUID?
    var exerciseUID: UUID?
    var routineUID: UUID?
    var routineNameAtEntry: String?
    var ownerLabelAtEntry: String?

    /// `JournalEntry.practisedUnitsRaw`, decoded and nested — the units a session entry says were
    /// practised, snapshotted with their titles as they read at the time.
    var practisedUnits: JSONValue?

    var isStandalone: Bool?

    var isMetronome: Bool?
    var metronomeBpmAtEntry: Int?
    var metronomeBeatsAtEntry: Int?
    var metronomeNoteValueAtEntry: Int?
    var metronomeSubdivisionRaw: String?
    var metronomeWithdrawalRaw: String?
}

/// A practice take, and the moments pinned inside it.
///
/// The audio is a **separate file** in the archive's `takes/` directory, named by `fileName` — the same
/// leaf the app stores it under. That is the join: a reader matching this record to its recording does
/// it by that name, and an archive exported without audio still carries every word written about every
/// take, along with the name of the file that is missing.
///
/// Owners are ids, because a take outlives its loop (ADR 0151): the relationships nullify rather than
/// cascade precisely so that deleting a loop does not destroy a recording of someone playing.
struct RecordingRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var createdAt: Date
    var duration: TimeInterval
    var title: String?

    /// What the take was like as a whole — a field on the take, not a `JournalEntry` (ADR 0174), which
    /// is why it travels here rather than in `journal`.
    var note: String?

    var fileName: String
    var ownerLabelAtTake: String?

    var loopUID: UUID?
    var exerciseUID: UUID?
    var songSourceID: String?

    var moments: [TakeNoteRecord]
}

/// A note pinned to a point in a take (ADR 0175).
///
/// `time` is an offset into the audio, so it only means anything alongside the take's file — and a trim
/// rebases these, which is why the archive keeps the moment's own `createdAt` as well: the time says
/// where in the take, the date says when it was written, and a trim moves one without touching the other.
struct TakeNoteRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var time: TimeInterval
    var text: String
    var createdAt: Date
}
