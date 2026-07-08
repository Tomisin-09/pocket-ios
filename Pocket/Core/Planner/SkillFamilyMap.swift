import Foundation

/// The **coarse** bridge from an `ExerciseTemplate` to the fine-grained taxonomy skills its
/// exercises can stand in for (Decision 4) — pure data. There is **no per-exercise skill tagging**
/// in V2: an exercise is classified only by its template, so a "sweep picking" goal surfaces *all*
/// the user's Picking exercises, not sweep-specifically (an accepted V2 tradeoff, refinable later
/// with optional tags). This is the map the deriver's Path A consults to answer "which of my
/// exercises can serve skill X".
enum SkillFamilyMap {

    /// Skills each template's exercises can serve. Deliberately generous at the coarse level.
    /// Templates that carry no technique skill are absent: **Basic** is a plain click drill and
    /// **Warm-up** is structural (LRU-placed, never due-scored — Decision 3), so neither ever
    /// resolves a technique goal.
    static let skillsByTemplate: [ExerciseTemplate: [String]] = [
        .picking: ["pick.alternate", "pick.string-skip", "pick.economy",
                   "pick.sweep", "pick.tremolo", "pick.hybrid"],
        .legato: ["fret.hammer-on", "fret.pull-off", "fret.legato",
                  "fret.slide", "fret.dexterity", "fret.stretch"],
        .scales: ["scale.major-minor", "scale.pentatonic", "scale.blues",
                  "scale.modes", "improv.vocabulary"],
        // Arpeggio drills lean on the picking hand's sweep / economy motion.
        .arpeggios: ["pick.sweep", "pick.economy"],
        .chords: ["rhythm.chord-changes", "know.chord-construction"],
        .strumming: ["rhythm.strumming", "rhythm.chord-changes"],
        .strumChords: ["rhythm.strumming", "rhythm.chord-changes", "rhythm.timing"],
        .rhythm: ["rhythm.timing", "rhythm.syncopation", "rhythm.strumming"],
        .fingerstyle: ["fret.dexterity", "rhythm.chord-changes"],
        .earTraining: ["ear.relative-pitch", "ear.transcribe", "ear.active-listening"],
        .theory: ["know.notes", "know.intervals", "know.chord-construction", "create.songwriting"]
    ]

    /// The distinct templates whose exercises can serve `skillID` — the query the deriver runs to
    /// resolve a technique skill (Path A). Empty when no template covers the skill.
    static func templates(forSkill skillID: String) -> [ExerciseTemplate] {
        skillsByTemplate.compactMap { template, skills in skills.contains(skillID) ? template : nil }
    }

    /// Whether an exercise of `template` can serve `skillID`.
    static func template(_ template: ExerciseTemplate, serves skillID: String) -> Bool {
        skillsByTemplate[template]?.contains(skillID) ?? false
    }
}
