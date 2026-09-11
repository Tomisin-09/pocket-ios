import Foundation

/// **Which skills a unit works on — and, for a skill nothing in the library works on, what could**
/// (ADR 0216). Pure / Foundation-only, per the "pure logic stays pure" rule.
///
/// Slice 1 is the *read* half: an exercise's skills are still exactly its type's
/// `SkillFamilyMap` row, and a loop's are still whatever its recognised bucket tags carry
/// (ADR 0074). What this adds is a stable, display-ordered way to ask those questions, and the
/// **fix** the goal editor offers when a skill reaches nothing.
///
/// Every order here comes from `ExerciseTemplate.displayOrder` or the taxonomy, never from
/// `SkillFamilyMap.skillsByTemplate` directly — that table is a `Dictionary`, so anything read off
/// its iteration order would reshuffle between launches.
enum SkillAssociation {

    /// The skills an exercise of `template` works on **by default** — its family-map row, in the
    /// row's own order. Empty for Basic, Warm-up and Freeform, which carry no technique skill.
    static func defaultSkills(for template: ExerciseTemplate) -> [String] {
        SkillFamilyMap.skillsByTemplate[template] ?? []
    }

    /// The exercise types that work on `skillID` by default, in library display order. Includes the
    /// retired types (Fingerstyle, Rhythm, Ear Training, Theory): drills made under them still exist
    /// and still serve.
    static func defaultTemplates(forSkill skillID: String) -> [ExerciseTemplate] {
        ExerciseTemplate.displayOrder.filter { SkillFamilyMap.template($0, serves: skillID) }
    }

    /// The types a player can still **create** that work on `skillID` by default, in create-menu
    /// order.
    static func creatableTemplates(forSkill skillID: String) -> [ExerciseTemplate] {
        ExerciseTemplate.creatable.filter { SkillFamilyMap.template($0, serves: skillID) }
    }

    /// The skills a loop works on through its recognised bucket tags (ADR 0074), each paired with
    /// the tag's type so the screen can say where it came from. Deduplicated on the skill — a loop
    /// tagged both *Picking* and *Arpeggios* lists sweep picking once, credited to the first tag.
    static func tagSkills(forTags tags: [String]) -> [(skillID: String, template: ExerciseTemplate)] {
        var seen: Set<String> = []
        var result: [(skillID: String, template: ExerciseTemplate)] = []
        for tag in tags {
            guard let template = SkillFamilyMap.recognizedTemplate(for: tag) else { continue }
            for skillID in defaultSkills(for: template) where seen.insert(skillID).inserted {
                result.append((skillID, template))
            }
        }
        return result
    }

    // MARK: - The fix for a skill that reaches nothing

    /// What the goal editor offers under a skill that reaches nothing in the player's library.
    enum Fix: Equatable {
        /// A type the player can create works on it by default — offer to make one.
        case makeExercise(ExerciseTemplate)
        /// A loop serves it by being run in this mode (ADR 0139 O2). Said, not navigated to: a song
        /// is too deep to reach from inside a goal sheet.
        case runLoopIn(LoopRunMode)
        /// A repertoire skill — the goal's own **Target song** row is the fix, already on screen.
        case pickTargetSong
        /// Only a retired type works on it (`know.*` via Theory, syncopation via Rhythm), so the one
        /// live route is a loop carrying that type's bucket tag (ADR 0074).
        case tagLoop(ExerciseTemplate)
        /// Nothing the player can make works on it by default today. Not `none`: a case by that name
        /// is one `Optional` comparison away from meaning something else.
        case nothing
    }

    /// The single fix to offer for `skillID`, in order of how directly it answers the skill: a drill
    /// you can make, then a way to run a loop, then a target song, then a loop tag.
    static func fix(for skillID: String) -> Fix {
        if let template = preferredTemplate(forSkill: skillID) { return .makeExercise(template) }
        if let mode = SkillFamilyMap.directLoopMode(forSkill: skillID) { return .runLoopIn(mode) }
        if TechniqueTaxonomy.mode(skillID)?.isRepertoire == true { return .pickTargetSong }
        if let tag = defaultTemplates(forSkill: skillID).first(where: SkillFamilyMap.taggableTemplates.contains) {
            return .tagLoop(tag)
        }
        return .nothing
    }

    /// The creatable type that works on `skillID` **most centrally**: the one whose family-map row
    /// lists the skill earliest, ties broken by create-menu order. So *Clean chord changes* offers
    /// Chords (where it leads the row) rather than Strumming (where it follows strumming itself), and
    /// *Sweep picking* offers Arpeggios, whose row is built around it.
    static func preferredTemplate(forSkill skillID: String) -> ExerciseTemplate? {
        let candidates = creatableTemplates(forSkill: skillID)
        return candidates.enumerated().min { lhs, rhs in
            let left = defaultSkills(for: lhs.element).firstIndex(of: skillID) ?? .max
            let right = defaultSkills(for: rhs.element).firstIndex(of: skillID) ?? .max
            return left == right ? lhs.offset < rhs.offset : left < right
        }?.element
    }
}
