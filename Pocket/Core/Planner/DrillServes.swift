import Foundation

/// **Which goals a new drill would serve** (ADR 0309 D4): the line under *Works on* on the create form.
///
/// A goal reaches a drill through its skills, which is the route the planner already reads (ADR 0216
/// D3), so this asks only that: does any skill the drill works on appear on a goal that isn't met? It
/// doesn't ask the deriver, as `GoalReach` does, because the drill doesn't exist yet and there is nothing
/// to derive from; and it doesn't weigh one goal against another. Pure and Foundation-only.
enum DrillServes {

    /// A goal, as the line needs it: its name to show, its skills, and whether it's met.
    struct Goal: Equatable {
        let title: String
        let skillIDs: [String]
        let isMet: Bool
    }

    /// The names of the goals the skills serve, in the order given, each once. A met goal brings nothing
    /// into a session, so it's left out.
    static func goals(for skillIDs: [String], among goals: [Goal]) -> [String] {
        let skills = Set(skillIDs)
        guard !skills.isEmpty else { return [] }
        var seen = Set<String>()
        return goals
            .filter { !$0.isMet && !skills.isDisjoint(with: $0.skillIDs) }
            .map(\.title)
            .filter { seen.insert($0).inserted }
    }

    /// *Serves your goal Play at the open mic.* — or `nil` when it serves none, so the form says nothing
    /// rather than *Serves no goals*, which would read as a fault in a drill that's optional to tie to one.
    static func line(_ titles: [String]) -> String? {
        switch titles.count {
        case 0: return nil
        case 1: return "Serves your goal \(titles[0])."
        default:
            let list = titles.dropLast().joined(separator: ", ") + " and " + titles[titles.count - 1]
            return "Serves your goals \(list)."
        }
    }
}
