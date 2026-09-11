import Foundation

/// **What to call a skill, and what its ⓘ says** — for any id a drill, loop or goal can hold, the
/// taxonomy's or the player's own (ADR 0216 D5/D7). Pure: the screens build one from their
/// `CustomSkill` query (`SkillVocabulary(_:)`, beside the model), so every place a skill is named
/// goes through here and a raw `custom:` id can't reach the screen.
struct SkillVocabulary: Equatable {

    /// A skill the player made, as far as a screen needs it.
    struct Custom: Equatable {
        let name: String
        let info: String
    }

    /// The player's skills, keyed by `custom:<uid>`.
    let custom: [String: Custom]

    init(custom: [String: Custom] = [:]) {
        self.custom = custom
    }

    /// The name `skillID` shows as.
    func name(_ skillID: String) -> String {
        SkillAssociation.displayName(skillID, customNames: custom.mapValues(\.name))
    }

    /// The text behind `skillID`'s ⓘ — ours for a taxonomy skill, the player's own for theirs.
    func explanation(_ skillID: String) -> String {
        if let own = custom[skillID] { return SkillExplainer.customText(info: own.info) }
        return SkillExplainer.text(for: skillID)
    }

    /// `ids` without the ones that name nothing here — what a screen lists.
    func resolvable(_ ids: [String]) -> [String] {
        SkillAssociation.resolvable(ids, customIDs: Set(custom.keys))
    }

    /// The player's skills in name order — the picker's *Your own* section.
    var customIDsByName: [String] {
        custom.sorted { $0.value.name.localizedCaseInsensitiveCompare($1.value.name) == .orderedAscending }
            .map(\.key)
    }
}
