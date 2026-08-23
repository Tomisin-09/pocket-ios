import Foundation

/// Everything a player has built, as a plain value tree — the payload of `practice.json` inside an
/// exported archive (ADR 0181).
///
/// **No `@Model` conforms to `Codable`, and none should.** SwiftData will not persist a `Codable`
/// attribute, the models carry installation-scoped state that must never leave the device
/// (`Song.bookmark`), and a class graph with cascade *and* nullify relationships has no single correct
/// serialisation. So the archive is a separate DTO tree, built by `ArchiveBuilder`, and the rules about
/// what may cross into it live there.
///
/// `Sendable` throughout, and free of SwiftData and SwiftUI, so the expensive half of an export —
/// encoding, staging, zipping — runs off the main actor while only the read stays on it.
///
/// ### Identity
///
/// Every type carries its model's stable business `uid`, never `persistentModelID` (ADR 0090). The one
/// exception is `Song`, which has no `uid` at all: it is keyed on `sourceID`, the same identity the
/// audio file on disk is named for.
///
/// ### Shape
///
/// Cascade relationships nest (a song owns its loops, a routine owns its blocks, a take owns its
/// moments) because the owner's deletion takes them with it, so they have no life of their own to
/// record. Nullify relationships are written as ids, because both ends outlive each other.
struct PracticeArchive: Codable, Equatable, Sendable {

    /// The archive format's own version, bumped when a field changes meaning rather than when one is
    /// added. Nothing in the app reads it today — it exists so that an importer, whenever it is built,
    /// can tell what it is looking at instead of guessing from which keys happen to be present.
    static let currentSchemaVersion = 1

    var schemaVersion: Int = PracticeArchive.currentSchemaVersion

    /// When the export was taken, and the build that took it. Both are for the person reading the file
    /// months later — an archive that cannot say when it is from is hard to trust against a newer one.
    var exportedAt: Date
    var appVersion: String

    /// Whether take audio was included. An archive without it is still a complete record of everything
    /// *written*; this flag is what tells a reader that the absence of a `takes/` directory was a
    /// choice rather than a loss.
    var includesTakeAudio: Bool

    var songs: [SongRecord] = []
    var exercises: [ExerciseRecord] = []
    var savedChords: [SavedChordRecord] = []

    var routines: [RoutineRecord] = []
    var goals: [GoalRecord] = []
    var longTermGoals: [LongTermGoalRecord] = []
    var practiceRuns: [SessionRecord] = []

    var journal: [JournalEntryRecord] = []
    var takes: [RecordingRecord] = []

    var profile: ProfileRecord?
}
