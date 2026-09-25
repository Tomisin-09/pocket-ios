import Foundation

// Exercises and saved chords — the two library types that keep their content as encoded JSON in an
// opaque column, and so the two that `JSONValue` exists for.

/// A drill, with its tempo plan, its rhythm, and whatever content its template renders.
struct ExerciseRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String
    var notes: String
    var tags: [String]

    /// The folders this drill is filed in (ADR 0210 D8), canonical paths.
    ///
    /// **Optional, and that is load-bearing.** A non-optional `[String]` with a declaration default
    /// does nothing on the way in: Swift's synthesized `Decodable` calls `decode(_:forKey:)` and
    /// throws `keyNotFound`, so **every archive written before this field would fail to decode
    /// entirely** — not lose the folders, fail. `Optional` is exempt (`decodeIfPresent`).
    ///
    /// And deliberately **no `KeyedDecodingContainer` overload for `[String]`**: ADR 0205 D5 forbids
    /// a generic over `[T]` because it would default every missing array everywhere, and `[String]`
    /// is barely narrower — it would silently cover `tags` and `collections` too. Optional makes the
    /// overload unnecessary, which is the whole point.
    ///
    /// `tags` above keeps being written, populated with these folders' leaf names, so a build
    /// without folders still shows a received drill something meaningful.
    var folders: [String]?
    /// The skills this drill states (ADR 0216 D1) — taxonomy ids, and `custom:<uid>` for skills the
    /// player made. `Optional` for `folders`' reason above: an archive written before 0216 has no key,
    /// and a non-optional array would fail the whole decode. Absent and empty both mean *follows its
    /// type*.
    var skillIDs: [String]?
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
    /// The phase switches, the warm-up count and the per-phase holds (ADR 0221). **All Optional**, for
    /// `folders`' reason: a file from a build before 0221 has none of these keys, and a non-optional
    /// field would fail the whole decode. Absent reads as today's shape — every phase on, one interval
    /// per rung, and a warm-up count derived from `rampStepBPM` (a `nil` `rampWarmupSteps` is exactly
    /// what the model stores for an exercise that has never been saved since).
    var includeWarmup: Bool?
    var includeReach: Bool?
    var rampWarmupSteps: Int?
    var rampWarmupHold: Int?
    var rampReachHold: Int?
    var rampBackoffHold: Int?

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

/// A progression the player wrote (ADR 0218 D10).
struct SavedProgressionRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String
    var createdAt: Date

    /// `SavedProgression.stepsData` — the steps and the key they were written in — decoded and nested,
    /// exactly as stored, the way a saved chord's voicing is.
    var payload: JSONValue?
}

extension Exercise {
    /// Land a record's phase shape (ADR 0221) on a drill hydrated from it — the one mapping both
    /// doors use, a restore and a received file, so the two can't read the same file differently.
    ///
    /// A missing key reads as the model's own default, which is the shape the drill had before 0221
    /// existed. `rampWarmupSteps` stays `nil` when absent, so `warmupSteps` derives it from
    /// `rampStepBPM` — the stride the file does carry — exactly as it would on the sender's phone.
    func applyPhaseShape(from record: ExerciseRecord) {
        includeWarmup = record.includeWarmup ?? true
        includeReach = record.includeReach ?? true
        rampWarmupSteps = record.rampWarmupSteps
        rampWarmupHold = record.rampWarmupHold ?? 1
        rampReachHold = record.rampReachHold ?? 1
        rampBackoffHold = record.rampBackoffHold ?? 1
    }
}
