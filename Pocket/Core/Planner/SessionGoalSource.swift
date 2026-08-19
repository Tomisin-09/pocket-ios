import Foundation

/// **Which tier of goal a generated session draws on** (ADR 0171 D10). The planner reads two goal
/// lists — the short-term one on Today's session and the ranked long-term one in Practice — and
/// until this existed it silently used both, which made the screen dishonest: it listed only the
/// short-term goals while Generate quietly consulted a list the player could not see from there.
///
/// Fixing the honesty problem needed the long-term tier *shown* on the planner. Giving the player a
/// say needed this. They are the same change: the control names the distinction, and selecting one
/// tier visibly dims the other, so the screen teaches which goals produced what it handed you.
///
/// **Not persisted**, by the same reasoning as `SessionConstraint` — which tier today's sitting
/// follows is a fact about this afternoon, not a preference. A player who deliberately practised
/// only their standing goals on Sunday should not find the planner still assuming it on Monday.
enum SessionGoalSource: String, CaseIterable, Identifiable {
    /// Today's goals lead the deal; the long-term ranking fills the rest. The default, and the
    /// behaviour ADR 0171 D3 shipped before this control existed.
    case both
    /// Only the goals authored on Today's session.
    case thisSession
    /// Only the ranked standing list.
    case longTerm

    var id: String { rawValue }

    /// Short segmented-control label. Deliberately terse — the sections below the control carry the
    /// full names, so repeating them here would only make the segments wrap.
    var label: String {
        switch self {
        case .both: return "Both"
        case .thisSession: return "This session"
        case .longTerm: return "Long-term"
        }
    }

    var drawsOnShortTerm: Bool { self != .longTerm }
    var drawsOnLongTerm: Bool { self != .thisSession }
}

/// What the planner should actually do, given a source and what the player has authored. Pure, so
/// the "which list feeds Generate" rule is unit-tested rather than living in a view's `if`.
struct SessionGoalPlan: Equatable {
    var usesShortTerm: Bool
    var usesLongTerm: Bool
    /// Whether nothing selected has anything to contribute, so the goal-less due-ranked Quick path
    /// runs instead. **The button always produces something to practise** — picking `Long-term` with
    /// an empty standing list generates a quick session rather than refusing (ADR 0073).
    var isQuickFallback: Bool { !usesShortTerm && !usesLongTerm }
}

extension SessionGoalSource {
    /// Resolve the source against the counts of **unmet** goals in each tier. A tier the source
    /// excludes contributes nothing; so does a tier the source includes but the player has left
    /// empty — which is why an empty selection falls back rather than failing.
    func plan(activeShortTermCount: Int, activeLongTermCount: Int) -> SessionGoalPlan {
        SessionGoalPlan(usesShortTerm: drawsOnShortTerm && activeShortTermCount > 0,
                        usesLongTerm: drawsOnLongTerm && activeLongTermCount > 0)
    }
}
