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
/// middle, and a full sitting.
///
/// **A preset denominates focused *blocks*, not minutes (ADR 0129).** It used to be a minute budget
/// the builder spent, which produced two failures: nothing enforced R2's *floor*, so a pool of
/// short-estimating exercises filled a "Quick 15" with fifteen one-minute items and fourteen rests;
/// and the number meant two different things in the two builders (a focused budget here, a total cap
/// in `CollectionSessionBuilder`). Counting blocks fixes both — the count is what the builder fills,
/// and minutes become a derived total-time *estimate* with one meaning everywhere.
enum SessionLength: Int, CaseIterable, Identifiable {
    case quick = 15
    case focused = 30
    case full = 60

    var id: Int { rawValue }

    /// One R2-sized focused block, in minutes. The **top** of R2's 10–15 default range, picked so the
    /// presets land exactly on R8's 15 / 30 / 60 focused minutes and R7's hour is the largest preset
    /// rather than a separate clamp.
    static let blockMinutes = 15

    /// Items rotated **inside** one block (ADR 0129) — one pass each, in sequence. Three items per
    /// R2-sized block is what reconciles interleaving (which wants several short exposures) with R2
    /// (which wants a 10–15 minute container): the rotation happens inside the block, so neither rule
    /// is traded off against the other.
    static let itemsPerBlock = 3

    /// The **focused** minutes this preset targets (ADR 0014 R8). No longer a budget the builder
    /// spends — it is the nominal span the soft `SessionEstimate.fit` hint compares an *edited*
    /// session against. A freshly generated session is on-target by construction.
    var minutes: Int { rawValue }

    /// Focused blocks this preset builds — 1 · 2 · 4.
    var blocks: Int { max(1, rawValue / Self.blockMinutes) }

    /// Focus items this preset schedules — 3 · 6 · 12. **This is the budget the builder fills.**
    var items: Int { blocks * Self.itemsPerBlock }

    /// Whether this preset schedules a trailing play-through (ADR 0129 sub-decision 2). A Quick
    /// sitting does not: a nominal 10-minute play block would be two-thirds of it again, so the one
    /// preset chosen *because* time is short would read as the longest. ADR 0014 R1 is untouched —
    /// play is never *capped*, it is simply not *scheduled* here.
    var includesPlay: Bool { self != .quick }

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
