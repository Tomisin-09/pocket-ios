import Foundation

/// Pure value projections of the library the front-half (`CandidateDeriver`) reasons over. The
/// planner never touches the `@Model`s directly (the "pure logic stays pure" rule, AGENTS.md): the
/// impure `PracticePlanner` builds these from live `Exercise`/`Loop`/`Song` — computing the time
/// estimates that need audio durations — and the deriver stays Foundation-only and unit-testable.

/// A projected exercise: its template (the Path-A family key), self-rated need, recency, and rough
/// minutes. `estimatedMinutes` is filled by the projector (Slice 2 uses a per-exercise default).
struct PlannerExercise: Equatable {
    var uid: UUID
    var template: ExerciseTemplate
    var mastery: Int?
    var lastPracticed: Date?
    var estimatedMinutes: Int
}

/// A projected loop bound to a song (Path B). `songUID` is the owning song's derived planner id
/// (`Song.plannerUID`), so a repertoire goal can gather a target song's loops. `templates` are the
/// skill buckets recognised from the loop's tags (Slice 4, Decision 8) — empty for an untagged loop,
/// so it stays Path-B-only; a recognised tag lets a technique goal's Path A surface it too.
struct PlannerLoop: Equatable {
    var uid: UUID
    var songUID: UUID?
    var mastery: Int?
    var lastPracticed: Date?
    var estimatedMinutes: Int
    var templates: [ExerciseTemplate] = []
}

/// A projected song run (Path B). Keyed by the derived `Song.plannerUID` — Song has no stored `uid`
/// (its identity is the file `SongRef`), so the planner keys song candidates by a deterministic
/// derivation instead of a migration-risky new column.
struct PlannerSong: Equatable {
    var uid: UUID
    var lastPracticed: Date?
    var estimatedMinutes: Int
}

/// The whole projected library handed to `deriveCandidates` — exercises (Path A) plus loops and
/// songs (Path B). All value types; no SwiftData.
struct PlannerLibrary: Equatable {
    var exercises: [PlannerExercise]
    var loops: [PlannerLoop]
    var songs: [PlannerSong]

    init(exercises: [PlannerExercise] = [],
         loops: [PlannerLoop] = [],
         songs: [PlannerSong] = []) {
        self.exercises = exercises
        self.loops = loops
        self.songs = songs
    }
}

/// A pure projection of a `Goal` (Slice 2) — the deriver reads goals as values, never the `@Model`.
/// `targetSongUID` is the target song's derived `plannerUID`, routed by the goal's repertoire skills.
struct PlannerGoal: Equatable {
    var weight: Double
    var skillIDs: [String]
    var targetSongUID: UUID?
    var isMet: Bool

    init(weight: Double = 1.0,
         skillIDs: [String],
         targetSongUID: UUID? = nil,
         isMet: Bool = false) {
        self.weight = weight
        self.skillIDs = skillIDs
        self.targetSongUID = targetSongUID
        self.isMet = isMet
    }
}

/// A **deterministic** UUID derived from a stable string identity — used so the planner can key
/// `Song` candidates (Song has no stored `uid`; its identity is the `SongRef.sourceID`) without a
/// schema migration. Same input string ⇒ same UUID on every run, so the projector and the
/// materialiser agree on a song's id without sharing state. FNV-1a into 128 bits: not
/// cryptographic, just a stable byte-spread — collisions across a personal library are negligible.
enum PlannerID {
    static func uid(from identity: String) -> UUID {
        // Two independent FNV-1a passes (different offset bases) fill the low/high 64 bits so the
        // whole 128-bit space is used rather than a repeated 32-bit hash.
        let low = fnv1a(identity, offset: 0xcbf29ce484222325)
        let high = fnv1a(identity, offset: 0x84222325cbf29ce4)
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((low >> (UInt64(index) * 8)) & 0xff)
            bytes[8 + index] = UInt8((high >> (UInt64(index) * 8)) & 0xff)
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6],
                           bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13],
                           bytes[14], bytes[15]))
    }

    private static func fnv1a(_ string: String, offset: UInt64) -> UInt64 {
        let prime: UInt64 = 0x100000001b3
        var hash = offset
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
