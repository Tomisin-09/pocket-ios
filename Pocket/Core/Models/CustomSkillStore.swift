import Foundation
import SwiftData

/// The writes that touch **every holder** of a skill the player made (ADR 0216 D7) — a goal of
/// either tier, a drill, a loop. In one place so delete can't strip the id from three of them and
/// forget the fourth.
enum CustomSkillStore {

    /// What states a skill — counts, never a judgement (ADR 0171 D7).
    struct Usage: Equatable {
        var goals = 0
        var drills = 0
        var loops = 0

        var isEmpty: Bool { goals + drills + loops == 0 }

        /// *"Used by 1 goal, 2 drills and 1 loop."* — what delete's confirmation says, or `nil` when
        /// nothing uses it and there is nothing to warn about.
        var summary: String? {
            let parts = [(goals, "goal", "goals"), (drills, "drill", "drills"), (loops, "loop", "loops")]
                .filter { $0.0 > 0 }
                .map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.2)" }
            guard !parts.isEmpty else { return nil }
            return "Used by \(SkillExplainer.listed(parts, joiner: "and"))."
        }
    }

    /// What states `skillID` right now.
    @MainActor
    static func usage(of skillID: String, in context: ModelContext) -> Usage {
        Usage(goals: fetch(Goal.self, in: context).filter { $0.skillIDs.contains(skillID) }.count
                  + fetch(LongTermGoal.self, in: context).filter { $0.skillIDs.contains(skillID) }.count,
              drills: fetch(Exercise.self, in: context).filter { $0.skillIDs.contains(skillID) }.count,
              loops: fetch(Loop.self, in: context).filter { $0.skillIDs.contains(skillID) }.count)
    }

    /// Delete `skill`, and strip its id from every goal, drill and loop **in the same save**. A drill
    /// left with nothing follows its type again (D1); a goal left with nothing schedules nothing,
    /// which its row's skill count then says.
    @MainActor
    static func delete(_ skill: CustomSkill, in context: ModelContext) {
        let skillID = skill.skillID
        for goal in fetch(Goal.self, in: context) where goal.skillIDs.contains(skillID) {
            goal.skillIDs.removeAll { $0 == skillID }
        }
        for goal in fetch(LongTermGoal.self, in: context) where goal.skillIDs.contains(skillID) {
            goal.skillIDs.removeAll { $0 == skillID }
        }
        for drill in fetch(Exercise.self, in: context) where drill.skillIDs.contains(skillID) {
            drill.skillIDs.removeAll { $0 == skillID }
        }
        for loop in fetch(Loop.self, in: context) where loop.skillIDs.contains(skillID) {
            loop.skillIDs.removeAll { $0 == skillID }
        }
        context.delete(skill)
        try? context.save()
    }

    /// The whole table, filtered in memory — `skillIDs` is an array, and a `#Predicate` reaching into
    /// one is exactly the kind of query `docs/swiftdata-gotchas.md` warns off.
    @MainActor
    private static func fetch<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) -> [Model] {
        (try? context.fetch(FetchDescriptor<Model>())) ?? []
    }
}
