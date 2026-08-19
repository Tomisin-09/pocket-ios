import Foundation

/// A curated **goal template** (Decision 7) — the in-house starting points the goal editor offers,
/// matching ADR 0015 S1's own examples. Each pre-seeds a sensible `skillIDs` set (from the
/// taxonomy) the user then trims; a repertoire template additionally asks for a target song. All
/// copy is authored in-house — encode the method, not anyone's content. Pure / Foundation-only;
/// the invariant that every `skillIDs` entry is a real taxonomy id is unit-tested.
struct GoalTemplate: Identifiable, Equatable {
    var id: String
    var title: String
    var blurb: String
    var skillIDs: [String]
    /// Whether this template resolves via a target song (Path B) — its skills are repertoire skills
    /// that need a song attached to produce candidates.
    var requiresTargetSong: Bool
    var iconName: String

    /// Build a fresh `Goal` from this template (neutral weight, no target yet). Impure only in that
    /// it constructs a `@Model`; the seeded data is all pure.
    func makeGoal() -> Goal {
        Goal(title: title, skillIDs: skillIDs)
    }
}

/// The offered goal templates, in menu order — mirrors ADR 0015 S1's four canonical intents.
enum GoalTemplateLibrary {
    static let all: [GoalTemplate] = [
        GoalTemplate(id: "play-song",
                     title: "Play a specific song",
                     blurb: "Learn a song from your library end-to-end.",
                     skillIDs: ["rep.learn-song", "rep.master-song"],
                     requiresTargetSong: true,
                     iconName: "music.note"),
        GoalTemplate(id: "build-speed",
                     title: "Build speed",
                     blurb: "Push picking and legato technique faster, cleanly.",
                     skillIDs: ["pick.alternate", "pick.economy", "fret.legato"],
                     requiresTargetSong: false,
                     iconName: "gauge.with.dots.needle.67percent"),
        GoalTemplate(id: "improvise",
                     title: "Improvise in a style",
                     blurb: "Grow soloing vocabulary over scales you know.",
                     skillIDs: ["scale.pentatonic", "scale.blues", "improv.vocabulary"],
                     requiresTargetSong: false,
                     iconName: "waveform"),
        GoalTemplate(id: "timing",
                     title: "Tighten your timing",
                     blurb: "Sit in the pocket — steady time, syncopation, cleaner strumming.",
                     skillIDs: ["rhythm.timing", "rhythm.syncopation", "rhythm.strumming"],
                     requiresTargetSong: false,
                     iconName: "metronome"),
        GoalTemplate(id: "chord-changes",
                     title: "Clean up your chord changes",
                     blurb: "Move between shapes without the gap you can hear.",
                     skillIDs: ["rhythm.chord-changes", "know.chord-construction"],
                     requiresTargetSong: false,
                     iconName: "hand.raised"),
        GoalTemplate(id: "ear",
                     title: "Train your ear",
                     blurb: "Hear intervals, lift parts off records, listen with intent.",
                     skillIDs: ["ear.relative-pitch", "ear.transcribe", "ear.active-listening"],
                     requiresTargetSong: false,
                     iconName: "ear"),
        GoalTemplate(id: "fretboard",
                     title: "Learn the fretboard",
                     blurb: "Know what note you are on, and what it is doing.",
                     skillIDs: ["know.notes", "know.intervals", "scale.major-minor"],
                     requiresTargetSong: false,
                     iconName: "square.grid.3x3"),
        GoalTemplate(id: "fretting-hand",
                     title: "Strengthen your fretting hand",
                     blurb: "Reach, independence and stamina — the hand, not the speed.",
                     skillIDs: ["fret.dexterity", "fret.stretch", "fret.hammer-on", "fret.pull-off"],
                     requiresTargetSong: false,
                     iconName: "hand.point.up.left"),
        GoalTemplate(id: "write",
                     title: "Write your own music",
                     blurb: "Turn the chords and lines you know into something of yours.",
                     skillIDs: ["create.songwriting", "know.chord-construction", "improv.vocabulary"],
                     requiresTargetSong: false,
                     iconName: "pencil.and.outline"),
        GoalTemplate(id: "general",
                     title: "General progress",
                     blurb: "A balanced mix of timing, scales, and clean changes.",
                     skillIDs: ["rhythm.timing", "scale.major-minor", "rhythm.chord-changes"],
                     requiresTargetSong: false,
                     iconName: "sparkles")
    ]

    /// A template by id, or `nil` when unknown.
    static func template(_ id: String) -> GoalTemplate? { all.first { $0.id == id } }
}
