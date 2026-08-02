import Foundation

/// **A restriction on the situation the session will be practised in** (ADR 0139 O3) — not a second
/// planner, a parameter to the one there is.
///
/// Everything that makes a session good (goal weighting, dueness, prerequisite softening, block
/// packing) is unchanged by a constraint; it only shrinks the pool the same machinery draws from.
/// That is the whole design: an "away from your instrument" session is the ordinary session, built
/// from the subset of your material you can actually use with nothing in your hands.
///
/// Pure / Foundation-only, like the rest of the planner's front half.
enum SessionConstraint: String, CaseIterable, Identifiable, Equatable {
    /// No restriction — the instrument is in your hands. Every existing caller.
    case none
    /// Instrument-free practice: only units runnable in an off-guitar **mode** survive, and loops are
    /// pinned to `.ear` (ADR 0139 O1 — off-guitar is a property of the mode, never of the material).
    case offGuitar

    var id: String { rawValue }

    /// Whether this constraint restricts anything at all — the fast path every unconstrained caller
    /// takes.
    var isRestricted: Bool { self != .none }

    /// **Never "off-guitar"** (ADR 0139 O5). ADR 0116 made this a multi-instrument app and a bassist
    /// should not be offered a session named for a guitar. The enum case keeps its taxonomy-matching
    /// name in code; nothing user-facing says it.
    var displayName: String {
        switch self {
        case .none: return "With your instrument"
        case .offGuitar: return "Away from your instrument"
        }
    }

    /// The one line under the option — what the player gets, and honestly what it is built from.
    var caption: String {
        switch self {
        case .none:
            return "The usual session — drills, loops and a play-through."
        case .offGuitar:
            return "Listening work built from your own loops, for a commute or a quiet room. "
                 + "Nothing to hold, nothing to plug in."
        }
    }

    /// Which loop run modes this constraint permits. Off-guitar is a property of the **mode**: you
    /// can sing a phrase back on a train, and you cannot improvise over it or run a ramp against it
    /// (ADR 0139 O1).
    func allows(_ mode: LoopRunMode) -> Bool {
        switch self {
        case .none: return true
        case .offGuitar: return mode == .ear
        }
    }

    /// The mode a **loop** is pinned to under this constraint, or `nil` to leave the resolving
    /// skill's own choice alone. Pinning rather than filtering is what lets a repertoire goal's own
    /// loops turn up in an off-guitar session as ear work instead of vanishing with the ramp they
    /// can't run.
    var pinnedLoopMode: LoopRunMode? {
        switch self {
        case .none: return nil
        case .offGuitar: return .ear
        }
    }
}
