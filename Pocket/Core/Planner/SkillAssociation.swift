import Foundation

/// **Which skills a unit works on — and, for a skill nothing in the library works on, what could**
/// (ADR 0216). Pure / Foundation-only, per the "pure logic stays pure" rule.
///
/// **One rule (D1).** Every exercise type has a *default* list — its `SkillFamilyMap` row, empty for
/// Basic and Freeform. A drill's stored `skillIDs` being empty means *those defaults*; a non-empty
/// list **replaces** them. So narrowing (drop Alternate picking) and expanding (add Metronome timing,
/// or a skill the player made) are the same edit, and a drill nobody has touched behaves exactly as
/// it did before 0216. A loop works on what it states **plus** what its bucket tags carry (ADR 0074).
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

    // MARK: - What a unit works on (D1)

    /// **The skills an exercise works on.** Stored empty ⇒ its type's defaults; stored non-empty ⇒
    /// exactly that list. Warm-up works on nothing whatever is stored: it is structural (ADR 0072),
    /// placed by recency and never scheduled by a goal.
    static func effectiveSkills(template: ExerciseTemplate, stated: [String]) -> [String] {
        guard template != .warmup else { return [] }
        let kept = deduplicated(stated)
        return kept.isEmpty ? defaultSkills(for: template) : kept
    }

    /// **The skills a loop works on:** what the player stated, then what its recognised bucket tags
    /// carry. A union rather than a replacement — the tags are the player's older statement of the
    /// same thing, and nothing migrates them (ADR 0210's backfill was deleted for writing things
    /// nobody chose).
    static func loopSkills(stated: [String], templates: [ExerciseTemplate]) -> [String] {
        deduplicated(stated + templates.flatMap(defaultSkills(for:)))
    }

    /// The list to **store** for an exercise whose player kept `kept`: empty when that is exactly
    /// its type's defaults, so the drill goes on following its type; otherwise `kept`, in catalogue
    /// order, so the same choice always stores the same list.
    static func storedSkills(kept: Set<String>, template: ExerciseTemplate) -> [String] {
        guard kept != Set(defaultSkills(for: template)) else { return [] }
        return catalogueOrdered(kept)
    }

    /// Whether an exercise's skills are the player's own rather than its type's — the *Set by you*
    /// caption, and the condition for offering *Use its type's skills*.
    static func isSetByPlayer(template: ExerciseTemplate, stated: [String]) -> Bool {
        let kept = deduplicated(stated)
        return !kept.isEmpty && Set(kept) != Set(defaultSkills(for: template))
    }

    /// Drop ids that name nothing — neither a taxonomy row nor a custom skill that still exists. The
    /// backstop behind delete's own clean-up (D7): a dangling id is dropped on read, never shown raw,
    /// never a crash. A drill left with nothing falls back to its type, by the rule above.
    ///
    /// `customIDs` `nil` accepts any custom-shaped id — for the planner's projection, which can't see
    /// the `CustomSkill` rows. That is safe because deleting a custom skill strips its id from every
    /// unit and goal in the same save; the screens, which can see the rows, pass them.
    static func resolvable(_ ids: [String], customIDs: Set<String>? = nil) -> [String] {
        ids.filter { id in
            TechniqueTaxonomy.info(id) != nil || (isCustom(id) && (customIDs?.contains(id) ?? true))
        }
    }

    /// Taxonomy skills in taxonomy order, then the player's own by id. Anything else is dropped.
    static func catalogueOrdered(_ ids: Set<String>) -> [String] {
        TechniqueTaxonomy.all.map(\.id).filter(ids.contains) + ids.filter(isCustom).sorted()
    }

    private static func deduplicated(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { seen.insert($0).inserted }
    }

    // MARK: - Skills the player made (D7)

    /// The prefix on a skill the player made — `custom:<uid>`. The id carries the row's `uid`, never
    /// its name, so a rename touches nothing that states it.
    static let customPrefix = "custom:"

    static func customID(_ uid: UUID) -> String { customPrefix + uid.uuidString }

    static func isCustom(_ skillID: String) -> Bool { skillID.hasPrefix(customPrefix) }

    /// The name a skill id shows as — the taxonomy's, or the player's for one they made. Never the
    /// raw id: `customNames` maps each `custom:<uid>` to its row's current name.
    static func displayName(_ skillID: String, customNames: [String: String]) -> String {
        if let info = TechniqueTaxonomy.info(skillID) { return info.name }
        if let name = customNames[skillID], !name.isEmpty { return name }
        return "Unknown skill"
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
        /// No type the player can create works on it by default: a retired type's skill (`know.*`
        /// through Theory), one no type covers (bends, vibrato), or one the player made. A freeform
        /// block that **states** it is the route that always exists — the player writes the
        /// practice and says what it is for (ADR 0139 O6's *declared, never inferred*).
        case makeFreeform
    }

    /// The single fix to offer for `skillID`, in order of how directly it answers the skill: a drill
    /// of a type that already works on it, then a way to run a loop, then a target song, and
    /// otherwise a freeform block that states it. Every skill has one.
    static func fix(for skillID: String) -> Fix {
        if let template = preferredTemplate(forSkill: skillID) { return .makeExercise(template) }
        if let mode = SkillFamilyMap.directLoopMode(forSkill: skillID) { return .runLoopIn(mode) }
        if TechniqueTaxonomy.mode(skillID)?.isRepertoire == true { return .pickTargetSong }
        return .makeFreeform
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
