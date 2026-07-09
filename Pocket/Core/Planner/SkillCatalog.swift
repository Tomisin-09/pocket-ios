import Foundation

/// A **display family** for the skill catalog — the section headings the goal editor's skill search
/// groups rows under (V2 planner R2). These mirror the comment groupings in `TechniqueTaxonomy` /
/// `docs/practice-techniques.md`; they are a *presentation* concept only and carry no planner
/// meaning (resolution stays `SkillMode` + `SkillFamilyMap`). Derived from the stable `SkillID`
/// prefix so a new taxonomy row lands in the right section for free. Pure / Foundation-only.
enum SkillFamily: String, CaseIterable, Identifiable {
    case picking
    case fretting
    case fretboard
    case scales
    case rhythm
    case ear
    case repertoire

    var id: String { rawValue }

    /// The section heading shown in the skill picker.
    var label: String {
        switch self {
        case .picking: return "Picking hand"
        case .fretting: return "Fretting & legato"
        case .fretboard: return "Fretboard knowledge"
        case .scales: return "Scales & improvisation"
        case .rhythm: return "Rhythm & timing"
        case .ear: return "Ear & musicianship"
        case .repertoire: return "Repertoire & creativity"
        }
    }
}

/// The searchable **skill catalog** over `TechniqueTaxonomy` (V2 planner R2): pure grouping + text
/// filtering the goal editor uses to let a user *add* any taxonomy skill, not just the ones a
/// template seeded. No free-text — search only narrows the fixed catalog (an orphan skill would
/// schedule nothing, ADR 0015). Foundation-only so it stays unit-testable.
enum SkillCatalog {

    /// The display family for a skill id, derived from its `SkillID` prefix (`pick.` → picking,
    /// `scale.`/`improv.` → scales, `rep.`/`create.` → repertoire, …). `nil` for an unknown prefix.
    static func family(of id: String) -> SkillFamily? {
        let prefix = id.split(separator: ".").first.map(String.init) ?? id
        switch prefix {
        case "pick": return .picking
        case "fret": return .fretting
        case "know": return .fretboard
        case "scale", "improv": return .scales
        case "rhythm": return .rhythm
        case "ear": return .ear
        case "rep", "create": return .repertoire
        default: return nil
        }
    }

    /// Group taxonomy rows under their display family, in `SkillFamily.allCases` order, preserving
    /// each family's in-catalog row order. Families with no matching row are omitted. Rows whose
    /// prefix maps to no family are dropped (there are none in the shipped table).
    static func grouped(_ rows: [SkillInfo] = TechniqueTaxonomy.all) -> [(family: SkillFamily, skills: [SkillInfo])] {
        SkillFamily.allCases.compactMap { family in
            let members = rows.filter { self.family(of: $0.id) == family }
            return members.isEmpty ? nil : (family, members)
        }
    }

    /// Case- and diacritic-insensitive search over skill **names**, grouped by family. An empty or
    /// whitespace-only query returns the whole catalog grouped; otherwise only names containing the
    /// query survive. Never matches on the raw id — users search the words they see.
    static func search(_ query: String, in rows: [SkillInfo] = TechniqueTaxonomy.all)
        -> [(family: SkillFamily, skills: [SkillInfo])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return grouped(rows) }
        let matches = rows.filter {
            $0.name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return grouped(matches)
    }
}
