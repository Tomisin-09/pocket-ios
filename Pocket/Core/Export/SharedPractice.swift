import Foundation

/// What a `.redmoonpractice` file holds — one piece of practice, handed from one player to another
/// (ADR 0188 D3).
///
/// **A discriminator rather than an extension per payload.** The receiving job is described as "a
/// teacher's routine, a friend's exercise": an extension that names the payload would force a second
/// file type, a second `Info.plist` entry and a second door the first time an exercise share ships.
/// One type with a `kind` inside it costs a field now and nothing later.
enum SharedPracticeKind: String, Codable, Sendable, CaseIterable {
    /// A routine and the exercises its blocks name. The only value today.
    case routine
}

/// The payload of a shared practice file (ADR 0188).
///
/// Shares `PracticeArchive`'s record types deliberately — `RoutineRecord`, `RoutineItemRecord` and
/// `ExerciseRecord` are used unchanged, so the shapes a receiver has to understand are the shapes it
/// already understands from an archive. What differs is not the grammar but the **contents**: a share
/// is stripped of the sender's practice (D4) and of anything they measured (D5).
///
/// `Sendable` and free of SwiftData, like every other type in this directory, so the encode can run
/// off the main actor while only the model read stays on it.
struct SharedPractice: Codable, Equatable, Sendable {

    /// Deliberately the **same** number as an archive's. The two files carry the same record shapes,
    /// so a change that breaks one breaks the other, and two independent counters would be two
    /// stories about one format.
    static let currentSchemaVersion = PracticeArchive.currentSchemaVersion

    /// Read before anything else on the way in (ADR 0188 D2): equal proceeds, lower migrates, higher
    /// is refused with a sentence the player can act on.
    var schemaVersion: Int = SharedPractice.currentSchemaVersion

    /// The discriminator, stored raw and read through `kind`.
    ///
    /// A `String` rather than the enum, the same discipline every stored enum in this app follows
    /// (`RoutineItem.kindRaw`, `JournalEntry.kindRaw`): a file written by a later version can name a
    /// payload this one has never heard of, and the reader has to be able to *see* that in order to
    /// say so. An enum column would fail to decode the whole file instead.
    var kindRaw: String = SharedPracticeKind.routine.rawValue

    /// When the file was written, and by which build. Both are for the person opening it later — and
    /// on the untrusted door they are the only provenance there is.
    var exportedAt: Date
    var appVersion: String

    /// The routine, when `kind` is `routine`. Optional so an unknown payload still decodes far enough
    /// to be reported rather than thrown away.
    var routine: RoutineRecord?

    /// Every exercise the routine's blocks name, **inline**.
    ///
    /// A block points at its unit by live relationship and the archive invents ids at DTO time
    /// (`ArchiveBuilder.routineItemRecord`), so a shared routine that only named uids would resolve to
    /// nothing on another device. Carrying them is what makes the file self-contained.
    var exercises: [ExerciseRecord] = []

    /// The blocks whose units cannot travel, named rather than dropped (D4).
    var placeholders: [SharedBlockPlaceholder] = []

    /// The typed payload kind, or `nil` if this file names one this build does not know.
    var kind: SharedPracticeKind? { SharedPracticeKind(rawValue: kindRaw) }

    /// `kindRaw` is written as `kind`: the raw column is an implementation detail of how this app
    /// stores enums, and the file format should not inherit it.
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kindRaw = "kind"
        case exportedAt
        case appVersion
        case routine
        case exercises
        case placeholders
    }
}

/// A block whose unit cannot cross, and what it was (ADR 0188 D4).
///
/// A `loopUID` is meaningless without the song that owns it — `LoopRecord` nests inside `SongRecord`
/// and carries no song key, and a loop's bounds are fractions of a song whose audio never leaves the
/// device (ADR 0148). So the block arrives as exactly what the app already knows how to draw, a block
/// whose unit did not resolve (`RoutineItem.isOrphaned`), and this carries the label to draw it with.
///
/// Silently dropping such a block would hand over a routine quietly shorter than the one that was
/// sent — which is the failure this type exists to prevent.
struct SharedBlockPlaceholder: Codable, Equatable, Sendable {

    /// The `RoutineItemRecord.uid` this describes.
    var itemUID: UUID

    /// What the sender's block pointed at, in words — "Chorus — Slow Bend". For the receiver to read
    /// and fill in with their own material; nothing resolves against it.
    var label: String
}
