import Foundation

/// The curated bridge from a declared **genre** to the taxonomy **skills** that genre leans on
/// (ADR 0113 Slice 3). It exists so the planner's emphasis mix (`PracticeEmphasis`) can tilt a
/// session toward the styles the player picked in the intake without inventing a genre axis in the
/// skill taxonomy: each genre just names the handful of existing `SkillID`s that most define its
/// sound.
///
/// Deliberately **coarse and hand-picked** — a tight, evocative shortlist per genre beats an
/// exhaustive one (the same instinct as `GoalTemplate`). Every id here MUST be a real
/// `TechniqueTaxonomy` row; that invariant is unit-tested so a taxonomy rename can't leave a dangling
/// emphasis. Pure / Foundation-only.
enum GenreSkillMap {

    /// The skills each genre emphasises, in a display-friendly order. Not exhaustive — the two or
    /// three techniques that most characterise the style, so emphasis stays a nudge, not a syllabus.
    static let byGenre: [MusicGenre: [String]] = [
        .rock: ["pick.alternate", "scale.pentatonic", "fret.bend", "rhythm.strumming",
                "rhythm.chord-changes"],
        .blues: ["scale.blues", "scale.pentatonic", "fret.bend", "fret.vibrato",
                 "improv.vocabulary"],
        .pop: ["rhythm.chord-changes", "rhythm.strumming", "scale.major-minor"],
        .folkAcoustic: ["rhythm.chord-changes", "rhythm.strumming", "fret.dexterity",
                        "scale.major-minor"],
        .jazz: ["know.chord-construction", "scale.modes", "improv.vocabulary", "know.intervals"],
        .funkSoul: ["rhythm.syncopation", "rhythm.strumming", "rhythm.timing", "pick.hybrid"],
        .rnbNeoSoul: ["know.chord-construction", "rhythm.syncopation", "fret.slide", "scale.modes"],
        .metal: ["pick.alternate", "pick.tremolo", "pick.sweep", "fret.legato", "scale.modes"],
        .singerSongwriter: ["rhythm.chord-changes", "rhythm.strumming", "create.songwriting",
                            "scale.major-minor"]
    ]

    /// The skills a single genre emphasises (empty only if a future genre is added without a mapping —
    /// which the "every genre maps" test forbids).
    static func skillIDs(for genre: MusicGenre) -> [String] {
        byGenre[genre] ?? []
    }
}
