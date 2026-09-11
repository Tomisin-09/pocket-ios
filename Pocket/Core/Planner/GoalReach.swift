import Foundation

/// What one of a goal's skills **actually pulls from the player's library** (ADR 0216 D4) — the
/// line under each skill in the goal editor.
///
/// Counts, and nothing else. There is no "2 of 3 skills covered" and no bar: a count over a total is
/// a score, and `LongTermGoalReading` already set this register for goals (ADR 0171 D7, ADR 0070).
struct SkillReach: Equatable {
    var skillID: String
    var exercises: Int
    var loops: Int
    /// Whether the target song's own play-through is among what it pulls (Path B).
    var songRun: Bool

    /// Nothing at all — the case the editor offers a fix for.
    var isEmpty: Bool { exercises == 0 && loops == 0 && !songRun }
}

/// Builds the editor's reach lines. Pure and Foundation-only.
///
/// **This asks `CandidateDeriver` rather than walking skill → unit itself**, for the reason
/// `LongTermGoalEcho` gives: a second, hand-rolled walk would be a lookalike that drifts from the
/// planner. Asking the deriver means the editor says exactly what Generate would draw on, by
/// construction — including the routes a hand walk would forget (backing loops, ear-mode loops,
/// tagged loops).
///
/// Each skill is derived **alone**. The deriver keeps only the strongest claim on a unit, so deriving
/// the whole goal at once would credit a shared drill to whichever skill claimed it first, and the
/// other skill would read *nothing* while it plainly has something.
enum GoalReach {

    /// A reach per skill, in the order given. `targetSongUID` is the goal's chosen song, which is
    /// what a repertoire skill resolves through.
    static func reach(skillIDs: [String], targetSongUID: UUID?,
                      library: PlannerLibrary) -> [SkillReach] {
        skillIDs.map { skillID in
            let probe = PlannerGoal(weight: 1.0, skillIDs: [skillID], targetSongUID: targetSongUID,
                                    isMet: false)
            let units = CandidateDeriver.deriveCandidates(goals: [probe], library: library).map(\.unit)
            return SkillReach(skillID: skillID,
                              exercises: units.filter { $0.kind == .exercise }.count,
                              loops: units.filter { $0.kind == .loop }.count,
                              songRun: units.contains { $0.kind == .song })
        }
    }

    /// The line the editor draws: *"2 exercises · 1 loop"*, *"3 loops · the song itself"*, or
    /// *"Nothing in your library yet"*.
    static func summary(_ reach: SkillReach) -> String {
        var parts: [String] = []
        if reach.exercises > 0 { parts.append(counted(reach.exercises, "exercise")) }
        if reach.loops > 0 { parts.append(counted(reach.loops, "loop")) }
        if reach.songRun { parts.append("the song itself") }
        return parts.isEmpty ? "Nothing in your library yet" : parts.joined(separator: " · ")
    }

    private static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
