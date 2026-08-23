import Foundation

// The session half: what a player planned to do, and what they are aiming at.

/// A saved routine and its blocks.
struct RoutineRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var name: String

    /// What the session is *for*, in the player's own words (ADR 0177). Distinct from `references`,
    /// which say where it came *from*.
    var notes: String

    var dateAdded: Date
    var lastPracticed: Date?
    var isFavorite: Bool
    var presetSlug: String?

    var items: [RoutineItemRecord]
    var references: [ReferenceLinkRecord]
}

/// One block of a routine.
///
/// A block points at its unit rather than containing it: the same exercise appears in several routines
/// and outlives all of them, and its relationships are `nullify` for that reason. So the unit is written
/// as an id and resolved on the way back in — and a block whose unit was deleted exports with all three
/// ids `nil`, which is exactly the orphan the app already knows how to draw.
struct RoutineItemRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var order: Int
    var kindRaw: String
    var reps: Int
    var plannedMinutes: Int?
    var usesAuthoredLength: Bool

    /// Whether this block captures a take while it runs (ADR 0179).
    ///
    /// `RoutineItem.canRecordTake` is deliberately **not** exported alongside it: that is derived from
    /// the block's unit — every loop mode qualifies, a freeform exercise and a song block do not — and
    /// writing a derivation into the archive would freeze today's rule into a file that outlives it.
    var recordsTake: Bool

    var loopRunModeRaw: String

    var exerciseUID: UUID?
    var loopUID: UUID?
    var songSourceID: String?
}

/// A goal for the current stretch of practice (ADR 0113), weighting what the planner reaches for.
struct GoalRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var title: String
    var weight: Double
    var skillIDs: [String]
    var targetSongID: String?
    var isMet: Bool
    var dateAdded: Date
}

/// A goal that outlives the session (ADR 0171). Carries `order` rather than `weight`: its rank drives
/// the order the planner visits things in, which is not the same axis as a weight.
struct LongTermGoalRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var title: String
    var skillIDs: [String]
    var order: Int
    var targetSongID: String?
    var isMet: Bool
    var dateAdded: Date
}

/// The local artist profile (ADR 0113). At most one exists.
///
/// The raw columns are exported as stored. They back typed enums whose cases may be added to, and an
/// archive that resolved them to display strings would lose the value the app actually reads.
struct ProfileRecord: Codable, Equatable, Sendable {
    var uid: UUID
    var artistName: String?
    var createdAt: Date
    var experienceRaw: String?
    var genresRaw: [String]
    var dreamRaw: String?
    var minutesPerDayRaw: String?
    var preferredInstrumentRaw: String?
}
