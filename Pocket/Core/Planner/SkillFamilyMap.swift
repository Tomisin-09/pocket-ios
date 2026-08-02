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

    // MARK: - Loop skill tags (V2 planner Slice 4, Decision 8)

    /// The `ExerciseTemplate` **skill buckets** offered as suggested `Loop.tags` — every template
    /// that carries technique skills (so `.basic` / `.warmup` are excluded, exactly as above), in the
    /// canonical `ExerciseTemplate.allCases` display order. A user tags a loop with one of these
    /// (by its `displayName`) so a technique goal's Path A can also surface that loop — untagged
    /// loops are unaffected (they still resolve only via Path B). Same ~10 coarse buckets as the
    /// exercise family map, so the vocabulary never overwhelms.
    static let taggableTemplates: [ExerciseTemplate] =
        ExerciseTemplate.allCases.filter { skillsByTemplate[$0] != nil }

    /// The suggested tag **strings** — the display names of `taggableTemplates`, the canonical forms
    /// the recogniser round-trips.
    static let suggestedLoopTags: [String] = taggableTemplates.map(\.displayName)

    // MARK: - Loops that serve a skill by what they *are* (ADR 0135 B6 / 0139 O2)

    /// The mode a loop must be run in to serve a skill **directly** — with no tag, no template, and
    /// no bookkeeping from the player.
    ///
    /// Loops now reach skills three ways, and the third is this one: by **tag** (ADR 0074, above),
    /// by **flag** (`isBackingTrack`, ADR 0135), and by **capability** (any loop you can hear can be
    /// sung back, ADR 0139). The pattern was arrived at twice by accident before it was named; this
    /// table is it stated once. Which loops actually qualify is not decided here — that is
    /// `LoopModeAccess`, the same predicate the run screens gate on.
    ///
    /// Both entries close a **zero-candidate hole**, and both holes were invisible for the same
    /// reason: a goal whose other skills resolve still looks like it works. `ear.*` mapped to
    /// `ExerciseTemplate.earTraining`, which left `creatable` when ear training shipped as a loop
    /// mode instead (ADR 0104); `improv.vocabulary` is `.repertoire`, so it resolved to nothing at
    /// all unless the goal named a target song — which "Improvise in a style" deliberately doesn't.
    static let directLoopModes: [String: LoopRunMode] = [
        "ear.relative-pitch": .ear,
        "ear.transcribe": .ear,
        "ear.active-listening": .ear,
        "improv.vocabulary": .improvise
    ]

    /// The mode a loop must run in to serve `skillID` directly, or `nil` when the skill has no such
    /// route (every skill that resolves through exercises or a target song).
    static func directLoopMode(forSkill skillID: String) -> LoopRunMode? {
        directLoopModes[skillID]
    }

    /// Recognise a free-form loop tag as one of the skill buckets, or `nil` when it isn't one.
    /// Case-insensitive match against a taggable template's `displayName` (the form the tag editor
    /// suggests), so "Picking" / "picking" both resolve to `.picking` but arbitrary tags
    /// ("chorus", "needs-work") stay unrecognised and don't route a loop into Path A.
    static func recognizedTemplate(for tag: String) -> ExerciseTemplate? {
        let folded = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !folded.isEmpty else { return nil }
        return taggableTemplates.first { $0.displayName.lowercased() == folded }
    }
}
