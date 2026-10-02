import Foundation

/// What a logged run was (ADR 0117). Stored as its raw `String` on `PracticeRun`, never as a stored
/// SwiftData enum — see that model's note.
///
/// The kind names the **unit** that was practised, not the container: a routine's blocks log as the
/// exercises and loops they actually are, and the routine itself is carried by `routineUID`. That
/// falls straight out of one-row-per-unit-run — there is no such thing as a "routine row" to name.
enum PracticeRunKind: String, Codable, CaseIterable, Equatable, Sendable {
    case exercise
    case loop
    /// Ear-training on a loop (ADR 0104) — the same material, a different job, so it windows with
    /// practice but doesn't muddy a loop's tempo trajectory.
    case earLoop
    /// Improvising over a loop flagged as a backing track (ADR 0135 B3b) — again the same material
    /// doing a different job, so it earns minutes and days on the same reasoning as `.earLoop`.
    /// Carries **no tempo**: a jam isn't practised *at* a tempo you own, and the live percent the
    /// player sets is a comfort setting, not an achievement.
    case improvise
    /// A play-along with the record (ADR 0071). Carries minutes and a day but no tempo — a play-along
    /// runs at the song's own speed, not at a tempo you own.
    case song
    /// Time with the click on the **Metronome screen** (ADR 0242) — practice with nothing else on
    /// screen. Carries **no unit and no tempo**: the click is not a unit you own, and the automator
    /// moves the tempo under you, so no one number is the tempo you practised at. Logged by that
    /// screen only, never by the engine it shares with the exercise screens (which log `.exercise`)
    /// and the previews (which are not practice).
    case metronome
    /// A row written by a newer build than the one reading it. Counts towards time totals; claims
    /// nothing about what it was.
    case other

    // Deliberately **no `recording` case**, though ADR 0117 listed one. That list predates the
    // per-unit-run correction: a practice take is always captured *during* an exercise or loop run
    // (ADR 0069 — `RecordingController` is only ever owned by those two screens), and that run already
    // writes its own row. A second row for the take would double-count the same minutes and inflate
    // the session count, which is exactly the kind of quiet inaccuracy an append-only log can't undo.
    // Takes remain first-class in the Journal timeline; they are simply not separate practice.

    /// How the kind reads in a stats surface. Sentence-case, no exclamation — the Progress register
    /// is a mirror, not an arcade (ADR 0113).
    var label: String {
        switch self {
        case .exercise: "Exercise"
        case .loop: "Loop"
        case .earLoop: "Ear training"
        case .improvise: "Improvising"
        case .song: "Song"
        case .metronome: "Metronome"
        case .other: "Practice"
        }
    }

    /// How the kind heads a group of runs in the Practice log's *What you played* (ADR 0241) — the
    /// plural of `label`, except where the plural is not a word anyone would say: you do "ear
    /// training" and "improvising", not "ear trainings". A `.song` run is named for what it was, a
    /// play-along, since the songs themselves are the rows inside the group.
    var groupLabel: String {
        switch self {
        case .exercise: "Exercises"
        case .loop: "Loops"
        case .earLoop: "Ear training"
        case .improvise: "Improvising"
        case .song: "Play-alongs"
        case .metronome: "Metronome"
        case .other: "Other practice"
        }
    }

    /// Reads a kind this build doesn't know as `.other` instead of throwing (ADR 0242).
    ///
    /// The synthesised decoder for a `String` enum throws on a raw value it has no case for, and in
    /// an archive that one row fails the **whole** restore as corrupt — a backup made on a newer
    /// build, holding a kind added after this one, would be unreadable here. Read as `.other`, its
    /// minutes still count, which is the rule `PracticeRun.kind` already applies to the store. What
    /// is lost is the name: a restore writes that row back as `.other`, and a later update that
    /// learns the kind cannot tell it apart from any other. The minutes are what the log is for.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PracticeRunKind(rawValue: raw) ?? .other
    }
}

/// A logged run as a **plain value** — the unit every stat is computed over (ADR 0117).
///
/// The aggregation layer never sees a `@Model`: the view runs its `@Query`, maps each `PracticeRun`
/// to one of these, and hands the array to `PracticeLog` / `TempoTrajectory`. That keeps the
/// off-by-one-prone code (day boundaries, week starts, sitting gaps) free of SwiftData and SwiftUI
/// and therefore unit-testable, per AGENTS.md — mirroring how `PracticeStats.summarize` already works.
/// `Codable` so the practice log can be exported as-is (ADR 0181). It is already the flat, store-free
/// shape an archive wants, so the export reuses it rather than declaring a parallel DTO that would have
/// to be kept in step with this one.
struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    let durationSeconds: Double
    let kind: PracticeRunKind
    let unitUID: UUID?
    let routineUID: UUID?
    let tempoBPM: Int?
    let tempoPercent: Int?
    let notesPerBeat: Int?
    /// The song a play-along or loop-based run came from (`Song.sourceID`), and the unit's name when
    /// it was logged (ADR 0241). Both `Optional`, which is what lets an archive written before they
    /// existed still decode: the synthesised `Decodable` reads an optional with `decodeIfPresent`,
    /// and a missing non-optional key would fail the **whole** archive, not just this row.
    let songSourceID: String?
    let unitLabel: String?

    init(id: UUID = UUID(),
         startedAt: Date,
         durationSeconds: Double,
         kind: PracticeRunKind,
         unitUID: UUID? = nil,
         routineUID: UUID? = nil,
         tempoBPM: Int? = nil,
         tempoPercent: Int? = nil,
         notesPerBeat: Int? = nil,
         songSourceID: String? = nil,
         unitLabel: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.kind = kind
        self.unitUID = unitUID
        self.routineUID = routineUID
        self.tempoBPM = tempoBPM
        self.tempoPercent = tempoPercent
        self.notesPerBeat = notesPerBeat
        self.songSourceID = songSourceID
        self.unitLabel = unitLabel
    }

    /// When the run ended — derived, never stored (`PracticeRun` keeps the duration instead).
    var endedAt: Date { startedAt.addingTimeInterval(durationSeconds) }

    /// The rhythm the logged BPM was measured in, or `nil` when the drill stated none (ADR 0121).
    var noteRate: NoteRate? { notesPerBeat.map { NoteRate(perBeat: $0) } }
}
