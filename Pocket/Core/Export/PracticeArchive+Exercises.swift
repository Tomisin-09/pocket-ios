import Foundation

// Exercises and saved chords — the two library types that keep their content as encoded JSON in an
// opaque column, and so the two that `JSONValue` exists for.

/// A drill, with its tempo plan, its rhythm, and whatever content its template renders.
struct ExerciseRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String
    var notes: String
    var tags: [String]
    var presetSlug: String?
    var isFavorite: Bool
    var dateAdded: Date
    var lastPracticed: Date?

    var currentTempo: Int
    var commandTempo: Int?
    var targetTempo: Int
    var targetTempoOverride: Int?

    var beatsPerBar: Int
    var noteValue: Int
    var accentBeats: [Int]
    var subdivisionRaw: String
    var notesPerBeat: Int?
    var commandNotesPerBeat: Int?

    var templateRaw: String
    var instrumentRaw: String

    /// `Exercise.templatePayload`, decoded from its opaque `Data` and nested as real JSON rather than
    /// emitted as base64 — a strum pattern, a fretboard drill, a chord progression or a strum-chord
    /// sheet, depending on the template. Untyped on purpose; see `JSONValue`.
    var template: JSONValue?

    var rampStepBPM: Int
    var rampIntervalCount: Int
    var rampIntervalUnitRaw: String
    var dwellIntervals: Int
    var includeBackoff: Bool
    var rampReachSteps: Int
    var rampBackoffSteps: Int
    var backoffTempoOverride: Int?

    var awayFromInstrument: Bool
    var clickEnabled: Bool
    var clickBPM: Int

    var mastery: Int?
    var masteryTempo: Int?
    var masteryNotesPerBeat: Int?

    /// The songs this drill was linked to (ADR 0111), by `sourceID`. A many-to-many that is written on
    /// this side only — recording it from both ends would put the same fact in the archive twice, with
    /// two chances to disagree.
    var linkedSongIDs: [String]

    var references: [ReferenceLinkRecord]
}

/// A chord voicing the player saved (ADR 0095).
struct SavedChordRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String
    var createdAt: Date

    /// `SavedChord.voicingData`, decoded and nested. The model keeps the voicing's name inside the blob
    /// as well as in its own column and takes care to keep them in step, so the archive carries both
    /// exactly as stored rather than picking a winner.
    var voicing: JSONValue?
}
