import Foundation

/// How a skill is usually practised — the taxonomy `default mode` column
/// (`docs/practice-techniques.md`) and the routing key the planner selects a resolution path with
/// (ADR 0015 S3 / Decision 5): the four technique modes resolve to the user's **exercises**
/// (Path A, via `SkillFamilyMap`), `repertoire` resolves to a goal's **target song** (Path B).
/// Pure / Foundation-only.
enum SkillMode: String, Equatable, Codable {
    case loopDrill
    case speedRamp
    case metronome
    case offGuitar
    case repertoire

    /// Whether this mode resolves via the goal's target song (Path B) rather than the exercise
    /// family map (Path A). Only `repertoire` is song-routed.
    var isRepertoire: Bool { self == .repertoire }
}

/// Coarse pedagogical difficulty — the taxonomy `Difficulty` column. ADR 0016 orders prerequisites
/// by it; carried here so the table round-trips the doc. Pure.
enum SkillDifficulty: String, Equatable, Codable {
    case beg
    case int
    case adv
}

/// One row of the technique taxonomy — the code form of a `docs/practice-techniques.md` entry.
/// `id` is the stable `SkillID` a `Goal` stores as a plain string (never a stored enum — the
/// SwiftData enum-attribute migration rule). Pure value type.
struct SkillInfo: Equatable {
    var id: String
    var name: String
    var difficulty: SkillDifficulty
    var mode: SkillMode
    var prereqs: [String]
}

/// The technique taxonomy as a pure, Foundation-only table (V2 planner Slice 2) — the code mirror
/// of `docs/practice-techniques.md`, the controlled vocabulary of **skills** the planner reasons
/// about. The deriver consults this for a skill's resolution `mode` and `prereqs`. It is code/data,
/// never a `@Model`: a `Goal` references rows by string id only (the enum-attribute rule).
enum TechniqueTaxonomy {

    /// Compact row factory so each entry stays on one readable line (and under the line-length cap).
    private static func skill(_ id: String, _ name: String, _ difficulty: SkillDifficulty,
                              _ mode: SkillMode, _ prereqs: [String] = []) -> SkillInfo {
        SkillInfo(id: id, name: name, difficulty: difficulty, mode: mode, prereqs: prereqs)
    }

    /// Every taxonomy row, grouped as in the doc. Order is display-friendly, not significant.
    static let all: [SkillInfo] = [
        // Picking-hand technique
        skill("pick.alternate", "Alternate picking", .beg, .speedRamp),
        skill("pick.string-skip", "String skipping", .int, .speedRamp, ["pick.alternate"]),
        skill("pick.economy", "Economy picking", .int, .speedRamp, ["pick.alternate"]),
        skill("pick.sweep", "Sweep picking", .adv, .speedRamp, ["pick.economy"]),
        skill("pick.tremolo", "Tremolo picking", .int, .speedRamp, ["pick.alternate"]),
        skill("pick.hybrid", "Hybrid picking", .adv, .loopDrill, ["pick.alternate"]),
        // Fretting-hand / legato
        skill("fret.dexterity", "Finger dexterity & independence", .beg, .speedRamp),
        skill("fret.stretch", "Finger stretching", .int, .loopDrill, ["fret.dexterity"]),
        skill("fret.hammer-on", "Hammer-ons", .beg, .speedRamp, ["fret.dexterity"]),
        skill("fret.pull-off", "Pull-offs", .beg, .speedRamp, ["fret.dexterity"]),
        skill("fret.legato", "Combined legato runs", .int, .speedRamp, ["fret.hammer-on", "fret.pull-off"]),
        skill("fret.slide", "Slides", .beg, .loopDrill, ["fret.dexterity"]),
        skill("fret.bend", "Bends (incl. pitch accuracy)", .int, .loopDrill),
        skill("fret.vibrato", "Vibrato", .int, .loopDrill, ["fret.bend"]),
        // Fretboard knowledge
        skill("know.notes", "Note names across the fretboard", .beg, .offGuitar),
        skill("know.intervals", "Intervals", .int, .offGuitar, ["know.notes"]),
        skill("know.chord-construction", "Building chords from theory", .int, .offGuitar, ["know.intervals"]),
        // Scales & improvisation
        skill("scale.major-minor", "Major / natural-minor scales", .beg, .loopDrill, ["know.notes"]),
        skill("scale.pentatonic", "Pentatonic scales", .beg, .loopDrill, ["know.notes"]),
        skill("scale.blues", "Blues scale", .int, .loopDrill, ["scale.pentatonic"]),
        skill("scale.modes", "Modes", .adv, .loopDrill, ["scale.major-minor"]),
        skill("improv.vocabulary", "Soloing / improv vocabulary", .int, .repertoire, ["scale.pentatonic"]),
        // Rhythm & timing
        skill("rhythm.chord-changes", "Clean chord changes", .beg, .loopDrill),
        skill("rhythm.strumming", "Strumming patterns", .beg, .metronome),
        skill("rhythm.timing", "Metronome timing & subdivisions", .beg, .metronome),
        skill("rhythm.syncopation", "Syncopation", .int, .metronome, ["rhythm.timing"]),
        // Ear & musicianship
        skill("ear.relative-pitch", "Relative pitch / interval recognition", .beg, .offGuitar),
        skill("ear.transcribe", "Transcribing by ear", .int, .offGuitar, ["ear.relative-pitch"]),
        skill("ear.active-listening", "Active listening", .beg, .offGuitar),
        // Repertoire & creativity
        skill("rep.learn-song", "Learning a song", .beg, .repertoire),
        skill("rep.master-song", "Mastering one song deeply", .int, .repertoire, ["rep.learn-song"]),
        skill("create.songwriting", "Songwriting", .int, .offGuitar, ["know.chord-construction"])
    ]

    /// Row lookup by `SkillID`. Built once from `all`; duplicate ids keep the first (there are none).
    private static let byID: [String: SkillInfo] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// The full row for a skill id, or `nil` when the id isn't in the taxonomy (an unknown goal
    /// skill is silently skipped by the deriver, not a crash).
    static func info(_ id: String) -> SkillInfo? { byID[id] }

    /// A skill's resolution mode, or `nil` when unknown.
    static func mode(_ id: String) -> SkillMode? { byID[id]?.mode }

    /// A skill's direct prerequisites (one level; the deriver stages on direct prereqs only — a
    /// bounded, testable V2 choice), or `[]` when unknown.
    static func prereqs(_ id: String) -> [String] { byID[id]?.prereqs ?? [] }
}
