import Foundation

/// What counts toward each long-term goal in the Practice log's grouping by goal (ADR 0298 D2).
///
/// A run records the unit it was on and **no goal** (ADR 0171 D7), so the answer is worked back from
/// the goal to the units that serve it, and that walk is the planner's: `CandidateDeriver.resolve`,
/// skill by skill. The log counts what *Generate* would have handed you for the goal, by construction.
///
/// **Two rules keep the count from flattering the goal** (D2). The over-count the 2026-11-13 check
/// found was ear training on a loop counted toward an improvising skill, because the loop *could*
/// be soloed over. So:
///
/// - **A loop counts in the mode the goal would run it in.** The planner says, for each loop it
///   claims, whether it is there to train, to hear or to solo over (ADR 0139 O2a); only runs of that
///   kind count. A loop a skill states, with no mode of its own, counts as the trainer.
/// - **A target song counts whole.** Every run *By song* counts under the song counts toward a goal
///   that names it, whatever kind of work it was: learning a song by ear is learning the song.
///
/// Pure and Foundation-only.
enum GoalAttribution {

    /// One goal as the view hands it over.
    struct Source {
        var goal: PlannerGoal
        /// The name to show (`GoalTitle`).
        var title: String
        /// The target song by `Song.sourceID`. `PlannerGoal` holds only the planner's id for it.
        var songSourceID: String?
        /// When the goal was set (`LongTermGoal.dateAdded`).
        var since: Date?
    }

    /// The claims, unmet goals in the order given (rank) and then met ones: the order a run shared
    /// by two goals is settled in.
    ///
    /// A **met** goal still claims. It derives nothing for the planner, but the time spent on it
    /// before it was met was time toward it, so it is derived here as if it were open.
    static func claims(_ sources: [Source], library: PlannerLibrary) -> [PracticeBreakdown.GoalClaim] {
        let ordered = sources.filter { !$0.goal.isMet } + sources.filter(\.goal.isMet)
        return ordered.map { source in
            var probe = source.goal
            probe.isMet = false
            var units = Set<PracticeBreakdown.UnitClaim>()
            for skillID in probe.skillIDs {
                for candidate in CandidateDeriver.resolve(skillID, of: probe, library: library) {
                    guard let kind = runKind(for: candidate) else { continue }
                    units.insert(PracticeBreakdown.UnitClaim(uid: candidate.unit.uid, kind: kind))
                }
            }
            return PracticeBreakdown.GoalClaim(id: source.goal.uid, title: source.title,
                                               isMet: source.goal.isMet,
                                               songSourceID: source.songSourceID, units: units,
                                               since: source.since)
        }
    }

    /// The kind of run that serves `candidate`. `nil` for the song run itself, which the target
    /// song's own rule already counts.
    private static func runKind(for candidate: PlannerCandidate) -> PracticeRunKind? {
        switch candidate.unit.kind {
        case .exercise:
            return .exercise
        case .loop:
            switch candidate.runMode {
            case .trainer: return .loop
            case .ear: return .earLoop
            case .improvise: return .improvise
            }
        case .song:
            return nil
        }
    }
}
