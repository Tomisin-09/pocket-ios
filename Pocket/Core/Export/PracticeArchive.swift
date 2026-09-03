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
    /// added — which is why `RoutineItemRecord.orphanLabel`, an additive optional, did not move it.
    ///
    /// **`SchemaVersionGate` reads it** (ADR 0188 D2), and is the only thing that does: equal
    /// proceeds, lower migrates, higher is refused. It was written into every file for two slices
    /// before anything read it, exactly so that this reader could tell what it was looking at
    /// instead of guessing from which keys happen to be present.
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

extension PracticeArchive {
    /// Every reference picture in the archive, by leaf name (ADR 0167 phase 2).
    ///
    /// Gathered from all four owners because references nest under whichever one holds them — there
    /// is no flat list to read. Deduplicated: an image belongs to exactly one owner, so a repeat
    /// would mean the tree is wrong, and staging it twice would only hide that.
    ///
    /// **Unlike take audio, pictures are not optional.** The take toggle exists because recordings
    /// are the bulk of a library and an export of them can be hundreds of megabytes; five capped
    /// JPEGs per owner are not that, and a second switch for them would be a choice offered for no
    /// reason (`docs/design-brief.md` §3.5).
    var referenceAttachmentFileNames: [String] {
        var seen = Set<String>()
        let nested = songs.flatMap { $0.references + $0.loops.flatMap(\.references) }
            + exercises.flatMap(\.references)
            + routines.flatMap(\.references)
        return nested.map(\.attachmentFileName)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
