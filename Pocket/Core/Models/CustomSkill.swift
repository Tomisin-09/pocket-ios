import Foundation
import SwiftData

/// **A skill the player made** (ADR 0216 D7) — for practice the taxonomy doesn't name: live looping,
/// a teacher's exercise, a style of their own. A Freeform block can already *be* that practice; this
/// is what lets a goal *ask for it*.
///
/// **A row, because a description needs somewhere to live.** The player can write what the skill is,
/// and that text is what its ⓘ shows. Units and goals never hold a relationship to it: they store
/// the string `custom:<uid>` (`skillID`) inside the `skillIDs` they already have, so renaming is free
/// — the id doesn't move — and editing the description touches this row alone.
///
/// Lifting ADR 0015 Decision 7's ban on free text is safe for one reason: the ban existed because an
/// orphan skill schedules nothing, and the goal editor now **shows** an orphan and offers the fix
/// (D4). Names and descriptions are the player's own words, so they never enter analytics.
///
/// Model discipline per ADR 0011/0036: a business `uid`, and a **declaration default** on every
/// non-optional attribute. A brand-new entity is additive on its own account, so registering it
/// costs no migration (the `PracticeFolder` precedent).
@Model
final class CustomSkill {

    /// Stable business id — the half of `skillID` that never changes, and the key its editor is
    /// presented by (never `persistentModelID`, which self-dismisses a sheet — ADR 0090).
    var uid: UUID

    /// What the player calls it. Unique case-insensitively, checked at write (`nameProblem`), so
    /// *Live looping* and *live looping* can't both exist.
    var name: String = ""

    /// What it is, in the player's words — the text behind its ⓘ. Optional to write.
    var info: String = ""

    /// When it was made. The natural secondary sort.
    var dateAdded: Date = Date.now

    init(uid: UUID = UUID(), name: String, info: String = "", dateAdded: Date = .now) {
        self.uid = uid
        self.name = name
        self.info = info
        self.dateAdded = dateAdded
    }

    /// The id units and goals store for this skill — `custom:<uid>`.
    var skillID: String { SkillAssociation.customID(uid) }

    /// The key two names are compared by — whitespace canonicalised (`Labels`), case folded. So
    /// *Live looping*, *live looping* and *Live  looping* are one name.
    static func foldedName(_ raw: String) -> String {
        (Labels.canonical(raw) ?? "").lowercased()
    }

    /// Why `raw` can't be a skill's name, in the words the form shows — or `nil` when it can.
    /// `takenNames` is every other name it must not repeat: the player's other skills (not the one
    /// being renamed) and every skill in the catalogue, so a custom *Alternate picking* can't shadow
    /// the real one.
    static func nameProblem(_ raw: String, takenNames: [String]) -> String? {
        let folded = foldedName(raw)
        guard !folded.isEmpty else { return "Give it a name." }
        if let clash = takenNames.first(where: { foldedName($0) == folded }) {
            return "\u{201C}\(Labels.canonical(clash) ?? clash)\u{201D} is already a skill."
        }
        return nil
    }
}
