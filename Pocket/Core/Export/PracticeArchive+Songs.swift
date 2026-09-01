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
    var attachmentFileName: String = ""
}
