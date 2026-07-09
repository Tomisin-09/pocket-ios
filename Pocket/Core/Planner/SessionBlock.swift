import Foundation

/// One block in a **planned session** (V2 planner, ADR 0014) — the pure output of
/// `SessionBuilder.buildSession`, before it is materialised into a `Routine`. Mirrors the
/// two-axis shape of `RoutineItemKind` (structural role) + a unit reference, but stays
/// **SwiftData-free** so the whole back-half is unit-testable. The materialiser translates
/// each case one-to-one into a `RoutineItem` of the matching `RoutineItemKind`.
///
/// Warm-up and play carry a unit ref only when one exists (a warm-up exercise / a target
/// song); absent that, the builder simply omits the block — never emits an empty structural
/// slot. Rests carry no unit (ADR 0014 R3). Every `focus` block is capped at
/// `RoutineBudget.maxFocusedMinutes` (R2) — a longer selection is split into several.
enum SessionBlock: Equatable {
    /// The unbudgeted warm-up that leads the session (ADR 0014 R1), sourced by LRU rotation
    /// from `template == .warmup` exercises. Placed by rule, never due-scored.
    case warmUp(PlannerUnitRef, minutes: Int)

    /// A budgeted focused block drilling one unit (ADR 0014 R1). `microRestEvery` is an
    /// optional in-block micro-rest cue cadence in minutes (R4); `nil` = no cue.
    case focus(PlannerUnitRef, minutes: Int, microRestEvery: Int?)

    /// A between-blocks rest (ADR 0014 R3). Carries no unit.
    case rest(minutes: Int)

    /// The unbudgeted play-through that trails the session (ADR 0014 R1) — a full run / jam,
    /// typically the goal's target song (Path B, Slice 2). Omitted when there is none.
    case play(PlannerUnitRef, minutes: Int)

    /// The structural role this block maps to on materialisation — the bridge to
    /// `RoutineItemKind`. Keeps the pure enum and the persisted enum in lockstep.
    var kind: RoutineItemKind {
        switch self {
        case .warmUp: return .warmup
        case .focus: return .focused
        case .rest: return .rest
        case .play: return .play
        }
    }

    /// The unit this block references, or `nil` for a rest — what the materialiser resolves.
    var unit: PlannerUnitRef? {
        switch self {
        case let .warmUp(ref, _), let .focus(ref, _, _), let .play(ref, _): return ref
        case .rest: return nil
        }
    }

    /// This block's minutes (a rest's break length, else the unit's allotted time).
    var minutes: Int {
        switch self {
        case let .warmUp(_, min), let .focus(_, min, _), let .rest(min), let .play(_, min):
            return min
        }
    }
}

/// The session-length presets the planner offers (ADR 0014 R8): a short default, a focused
/// middle, and a full sitting. The number is the **focused** budget in minutes (warm-up and
/// play sit outside it, R1). Pure — the UI (Slice 3) renders these; the builder consumes the
/// raw minutes.
enum SessionLength: Int, CaseIterable, Identifiable {
    case quick = 15
    case focused = 30
    case full = 60

    var id: Int { rawValue }

    /// The focused-minutes budget this preset allots.
    var minutes: Int { rawValue }

    /// The default preset — the short one (ADR 0014 R8: "default short").
    static let `default`: SessionLength = .quick

    /// Short label for the picker.
    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .focused: return "Focused"
        case .full: return "Full"
        }
    }
}
