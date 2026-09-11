import Foundation

/// **What each skill is, and where it comes from in the player's library** — the text behind a
/// skill's ⓘ (ADR 0216 D5). Pure / Foundation-only.
///
/// The one-line descriptions are **our own words** (the provenance note in
/// `docs/practice-techniques.md`): generic technique names, no third-party prose. They say what a
/// skill *is*, never how well anyone does it (ADR 0070).
///
/// The rest of the text is **derived, not written**: which types work on a skill by default comes
/// from the same `SkillFamilyMap` the planner reads, and what comes first from the taxonomy's
/// prerequisites. So the ⓘ cannot claim a route the planner doesn't take. *By default*, because a
/// drill can be narrowed away from its type's skills or expanded past them (D1).
enum SkillExplainer {

    /// One sentence per taxonomy row. `SkillExplainerTests` holds this to exactly the taxonomy: a
    /// new skill without a line fails, and so does a line for a skill that no longer exists.
    static let lines: [String: String] = [
        // Picking hand
        "pick.alternate": "Strict down–up picking on every note, whichever string it is on.",
        "pick.string-skip": "Picking lines that jump over a string without breaking the down–up pattern.",
        "pick.economy": "Letting the pick carry on in the same direction as it crosses to the next string.",
        "pick.sweep": "One continuous rake of the pick across several strings, one note on each.",
        "pick.tremolo": "Fast, even, repeated picking on a single note.",
        "pick.hybrid": "The pick and your fingers together — the pick on one string, fingers on others.",
        // Fretting hand
        "fret.dexterity": "Each fretting finger moving on its own, evenly and without dragging the others.",
        "fret.stretch": "Covering wider fret spans without the hand locking up.",
        "fret.hammer-on": "Sounding a note by bringing a finger down onto the string instead of picking it.",
        "fret.pull-off": "Sounding a lower note by flicking a finger off the string instead of picking it.",
        "fret.legato": "Hammer-ons and pull-offs joined into smooth runs with little or no picking.",
        "fret.slide": "Moving a fretted note along the string so the pitch glides to where it lands.",
        "fret.bend": "Pushing the string to raise a note's pitch, and arriving at the pitch you meant.",
        "fret.vibrato": "A steady, repeated waver in pitch that keeps a held note alive.",
        // Fretboard knowledge
        "know.notes": "Knowing which note sits at any fret, on any string.",
        "know.intervals": "The distance between two notes, and where each one falls on the neck.",
        "know.chord-construction": "Which notes make a chord and why, so shapes can be built rather than memorised.",
        // Scales & improvisation
        "scale.major-minor": "The major and natural-minor scales, and their shapes across the neck.",
        "scale.pentatonic": "The five-note scales much soloing starts from, in major and minor.",
        "scale.blues": "The minor pentatonic with one added note — the flattened fifth.",
        "scale.modes": "The seven modes of the major scale, each with its own colour.",
        "improv.vocabulary": "Phrases and ideas to reach for when you solo, beyond running the scale.",
        // Rhythm & timing
        "rhythm.chord-changes": "Moving between chord shapes in time, without the gap you can hear.",
        "rhythm.strumming": "Strumming patterns over a steady down–up hand, whatever the rhythm.",
        "rhythm.timing": "Holding a steady pulse, and dividing each beat evenly.",
        "rhythm.syncopation": "Accents placed off the beat, on purpose.",
        // Ear & musicianship
        "ear.relative-pitch": "Hearing the distance between two notes, and naming it.",
        "ear.transcribe": "Working a part out from a recording by ear.",
        "ear.active-listening": "Listening to music for what each part is actually doing.",
        // Repertoire & creativity
        "rep.learn-song": "Getting a song from your library under your fingers, start to finish.",
        "rep.master-song": "Taking a song you already play and making it your own.",
        "create.songwriting": "Turning the chords and lines you know into songs of your own."
    ]

    /// One line for a skill with no route by default — true of a handful of taxonomy skills, and
    /// the whole point of the freeform fix (D4).
    static let noDefaultRoute = "No kind of drill works on this by default \u{2014} mark any drill or loop "
        + "with it, or write your own practice for it."

    /// The one-line description, or `nil` for an id outside the taxonomy.
    static func line(for skillID: String) -> String? { lines[skillID] }

    /// Where a skill comes from in the player's library by default, as one sentence — every route
    /// the planner takes for it when nobody has said otherwise, in the order a player would reach
    /// for them.
    static func workedOnBy(_ skillID: String) -> String {
        var routes: [String] = []
        let exerciseTypes = SkillAssociation.creatableTemplates(forSkill: skillID)
            .sorted { lhs, rhs in
                (ExerciseTemplate.displayOrder.firstIndex(of: lhs) ?? 0)
                    < (ExerciseTemplate.displayOrder.firstIndex(of: rhs) ?? 0)
            }
            .map(\.displayName)
        if !exerciseTypes.isEmpty {
            routes.append("\(listed(exerciseTypes, joiner: "and")) exercises")
        }
        let directMode = SkillFamilyMap.directLoopMode(forSkill: skillID)
        let tagTypes = SkillAssociation.defaultTemplates(forSkill: skillID)
            .filter { SkillFamilyMap.taggableTemplates.contains($0) }
            .map(\.displayName)
        // An ear skill is served by *any* loop you can hear, which already includes every loop tagged
        // Ear Training — naming both said one fact twice. Improvise is narrower (backing tracks only),
        // so a Scales tag there is a genuinely separate route and stays.
        if !tagTypes.isEmpty, directMode != .ear {
            routes.append("loops tagged \(listed(tagTypes, joiner: "or"))")
        }
        switch directMode {
        case .ear: routes.append("any loop you run in Train your ear")
        case .improvise: routes.append("backing tracks you run in Improvise")
        case .trainer, nil: break
        }
        if TechniqueTaxonomy.mode(skillID)?.isRepertoire == true {
            routes.append("the target song you give a goal")
        }
        guard let last = routes.last else { return noDefaultRoute }
        // The routes get a serial comma, because a route can itself contain "and" ("Picking and
        // Arpeggios exercises") and two bare "and"s in a row read as one list.
        let sentence = routes.count == 1 ? last : routes.dropLast().joined(separator: ", ") + ", and " + last
        return "By default, worked on by \(sentence)."
    }

    /// *"Comes after Economy picking."* — the taxonomy's direct prerequisites, by name. `nil` when
    /// the skill has none. A soft order the planner leans on (ADR 0073 Decision 6), never a gate.
    static func comesAfter(_ skillID: String) -> String? {
        let names = TechniqueTaxonomy.prereqs(skillID).compactMap { TechniqueTaxonomy.info($0)?.name }
        guard !names.isEmpty else { return nil }
        return "Comes after \(listed(names, joiner: "and"))."
    }

    /// The whole ⓘ text for a taxonomy skill: what it is, where it comes from, what comes first.
    static func text(for skillID: String) -> String {
        [line(for: skillID), workedOnBy(skillID), comesAfter(skillID)]
            .compactMap { $0 }
            .joined(separator: "\n\n")
    }

    /// The ⓘ text for a skill the player made (D7): **their** description, then how it is worked
    /// on. With no description, a line that says what it is — never an empty popover.
    static func customText(info: String) -> String {
        let own = info.trimmingCharacters(in: .whitespacesAndNewlines)
        return [own.isEmpty ? "A skill you made." : own,
                "Worked on by any drill or loop you mark with it."]
            .joined(separator: "\n\n")
    }

    /// `["A"]` → "A"; `["A", "B"]` → "A and B"; `["A", "B", "C"]` → "A, B and C".
    static func listed(_ items: [String], joiner: String) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        return items.dropLast().joined(separator: ", ") + " \(joiner) " + last
    }
}
