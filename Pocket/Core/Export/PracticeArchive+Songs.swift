import Foundation

// The library half of the archive: a song and the annotations it cascades to, plus the reference-link
// record every owner shares. See `PracticeArchive` for the identity and nesting rules.

/// A song, its loops, its markers and its links.
///
/// **Keyed on `sourceID`** — `Song` is the one model with no `uid` (every other one has). That is also
/// the name its audio file carries in `Application Support/Songs/`, so the key that identifies the row
/// is the key that finds the file.
///
/// Two fields are excluded on purpose:
///
/// - **`bookmark`** is a security-scoped bookmark, meaningful only to the installation that minted it.
///   Exporting it would carry a value that is guaranteed dead wherever the archive is read — and the
///   whole reason ADR 0148 keeps its own copies is that bookmarks do not survive.
/// - **`amplitudes`** is the 512-bucket waveform envelope, re-extracted from the audio in a second.
///   Derived data, and at 512 `Double`s per song it would dominate a file whose point is the writing.
struct SongRecord: Codable, Equatable, Sendable {
    var sourceID: String
    var sourceRaw: String

    var title: String
    var artist: String
    var album: String
    var genre: String
    var year: Int?
    var key: String
    var comment: String
    var collections: [String]

    var bpm: Int?
    var preciseBPM: Double?
    var downbeatSeconds: TimeInterval?
    var extraDownbeatSeconds: [TimeInterval]
    var beatsPerBar: Int
    var noteValue: Int
    var showsGridlines: Bool

    var duration: TimeInterval
    var dateAdded: Date?
    var lastPracticed: Date?
    var lastPracticedSpeed: Double?

    /// The leaf name of the owned audio copy, or `nil` for a song whose audio was never adopted. The
    /// file itself is **not** in the archive: song audio is the player's own imported media, which they
    /// already hold, and copying a library of it into an export would multiply the file size for
    /// something no other device needs in order to read this one.
    var audioFileName: String?

    var loops: [LoopRecord]
    var markers: [MarkerRecord]
    var references: [ReferenceLinkRecord]
    /// The song's snags (ADR 0205). Nests here rather than under `LoopRecord` because that is where
    /// the model puts them: a snag is cascade-owned by its `Song` and only *tagged* with a loop, so
    /// that 2:01 is 2:01 whether or not the loop armed at the time still exists (ADR 0200). Nesting
    /// it under a loop would make the archive assert an ownership the store does not have, and would
    /// silently drop every mark made with no loop armed.
    ///
    /// **Additive, with a declaration default**, so an archive written before this decodes with an
    /// empty list rather than failing — the `schemaVersion` stays at 1 because no field changed
    /// meaning (`PracticeArchive.currentSchemaVersion`).
    var snags: [SnagRecord] = []
}

/// A practice loop over a region of a song, with every authored setting that governs how it runs.
struct LoopRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String

    /// Fractions of the song's duration, not seconds — the model's own units, kept so the archive says
    /// what the store says rather than a derivation that would drift if a duration were ever corrected.
    var start: Double
    var end: Double

    var speed: Double
    var repeats: Int
    var loopTypeRaw: String
    var tags: [String]
    /// The skills this loop states (ADR 0216 D1). `Optional` for `ExerciseRecord.folders`' reason —
    /// an archive written before 0216 has no key, and a missing non-optional array fails the decode.
    var skillIDs: [String]?
    var isFavorite: Bool
    var isBackingTrack: Bool

    var lastPracticedSpeed: Double?
    var mastery: Int?
    var masteryAtSpeed: Double?
    var focus: Int?
    var commandTempo: Double?
    var targetSpeedOverride: Double?

    var automatorEnabled: Bool
    var automatorTargetSpeed: Double
    var automatorStepCount: Int
    var automatorLoopsPerStep: Int

    var rampWarmupSteps: Int
    var rampReachSteps: Int
    var rampBackoffSteps: Int
    var rampRepsPerStep: Int
    var rampDwellIntervals: Int
    var includeBackoff: Bool
    var backoffSpeedOverride: Double?

    var colorIndex: Int?
    var customColorHex: String?

    var references: [ReferenceLinkRecord]
    /// Every recorded edit to this loop's span (ADR 0205). Nests, because `Loop.spanChanges` is
    /// `.cascade` (ADR 0199 D5) — with the loop gone there is no span for a row to be about.
    ///
    /// Additive with a declaration default, like `SongRecord.snags`.
    var spanChanges: [LoopSpanChangeRecord] = []
}

/// A place the player fluffed it (ADR 0200) — a point on the song, and the cheapest thing in the
/// library to make.
///
/// **`loopUID` is a loose id copy, not a relationship**, and it is written as the id it is. It
/// resolves on the way back in because a restore preserves the loop's own `uid` rather than minting
/// one (`ArchiveRestoreWriter+Library.loop(from:)`); a mark whose loop is not in the archive keeps
/// the id and simply shows no caption, which is what the app already does for a deleted loop.
struct SnagRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var markedAt: Date
    var seconds: TimeInterval
    var speed: Double?
    var loopUID: UUID?
}

/// One recorded edit to a loop's span (ADR 0199).
///
/// Both pairs of bounds travel, because each row is self-contained by design — it answers "widen
/// back to where it was" without walking the chain. `songDuration` travels too: it is the duration
/// **at write time**, which is what lets a span read back in seconds after a relink (ADR 0152), and
/// recomputing it from the song's current duration on restore would quietly rewrite history.
struct LoopSpanChangeRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var changedAt: Date
    var start: Double
    var end: Double
    var previousStart: Double
    var previousEnd: Double
    var speed: Double?
    var songDuration: TimeInterval?
}

/// A named point in a song.
struct MarkerRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var seconds: TimeInterval
    var label: String
}

/// Where something was learned (ADR 0167) — cascade-owned by a song, loop, exercise or routine alike,
/// so it nests under whichever one holds it and carries no owner of its own.
struct ReferenceLinkRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var title: String
    var note: String
    var urlString: String
    var order: Int
    var dateAdded: Date
    var kindRaw: String
    /// The leaf name of this reference's picture, staged under `references/` in the zip (ADR 0167
    /// phase 2), or empty for a link. Written even though nothing imports it yet, for the reason the
    /// whole archive exists: an export that named a picture it did not carry — or carried one it did
    /// not name — would be a record the player cannot put back together.
    ///
    /// **`Optional`, not `String` with a default** (ADR 0212, obeying ADR 0205 D5). This field was
    /// added after ADR 0181 defined the format, so an archive can predate it, and a declaration
    /// default does not survive a missing key — the synthesized `Decodable` calls
    /// `decode(_:forKey:)` and throws `keyNotFound`, which would fail the *whole* backup on one
    /// absent string. `Optional` is the one shape the synthesizer decodes with `decodeIfPresent`.
    /// It cannot take a `KeyedDecodingContainer` overload the way the additive collections do,
    /// because a `String` overload would default every missing string in every `Codable` type in
    /// the app to `""` — the blast radius D5 refuses. Read it through `?? ""`; absent and empty
    /// both mean *this reference is a link, not a picture*, and nothing distinguishes them.
    var attachmentFileName: String?
}
