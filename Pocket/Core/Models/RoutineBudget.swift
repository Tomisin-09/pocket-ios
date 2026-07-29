import Foundation

/// Pure pacing / budget / rest rules for a practice **routine** (ADR 0066 R7),
/// distilled from the practice-science planner rules (ADR 0014). **SwiftData-,
/// SwiftUI- and AVFoundation-free** so it stays unit-testable and reusable by both the
/// manual authoring UI and the future planner / AI suggester (ADR 0002) — the "pure
/// logic stays pure" rule (AGENTS.md).
///
/// The model (`Routine`/`RoutineItem`) stores what a routine *contains*; this layer
/// *computes* over it and can *propose* structure (rests), never mutating the store.
/// It reasons over the SwiftData-free `RoutineItemKind` and small value projections, so
/// nothing here imports the persistence stack.
enum RoutineBudget {

    // MARK: Block-length caps (ADR 0014 R2 — short focused blocks, never one long grind)

    /// Default length of a focused block, minutes (ADR 0014 R2: 10–15 min).
    static let defaultFocusedMinutes = 12
    /// Hard ceiling on a single unbroken focused block, minutes (ADR 0014 R2).
    static let maxFocusedMinutes = 20

    // MARK: Rest length (ADR 0014 R3 — a short break between focused blocks)

    /// Minimum / default / maximum rest length between blocks, minutes (ADR 0014 R3).
    static let minRestMinutes = 2
    static let defaultRestMinutes = 3
    static let maxRestMinutes = 5

    // MARK: Budget accounting (ADR 0014 R1 — only deliberate work is budgeted)

    /// A minimal value projection of a block for budget math — just its kind and an
    /// estimated duration. Keeps the pure layer free of the `@Model` type.
    struct PlanItem: Equatable {
        var kind: RoutineItemKind
        var minutes: Int
        init(_ kind: RoutineItemKind, minutes: Int) {
            self.kind = kind
            self.minutes = minutes
        }
    }

    /// Total **budgeted** minutes across a plan: only `focused` blocks count (ADR 0014
    /// R1). Warm-up and play are surfaced but unbudgeted; rests are breaks, not work.
    static func budgetedMinutes(_ plan: [PlanItem]) -> Int {
        plan.filter { $0.kind.isBudgeted }.reduce(0) { $0 + $1.minutes }
    }

    /// Whether a single focused block exceeds the hard ceiling and should be split
    /// (ADR 0014 R2).
    static func exceedsBlockCap(_ minutes: Int) -> Bool { minutes > maxFocusedMinutes }

    /// Split a focused span that exceeds the cap into several blocks, none over the
    /// ceiling (ADR 0014 R2 — "if the selected focused time exceeds one block, split it").
    /// Fills whole `maxFocusedMinutes` blocks and leaves the remainder as the last.
    /// A non-positive input yields no blocks; an at-or-under-cap input stays one block.
    static func splitFocused(_ minutes: Int) -> [Int] {
        guard minutes > 0 else { return [] }
        var blocks: [Int] = []
        var remaining = minutes
        while remaining > maxFocusedMinutes {
            blocks.append(maxFocusedMinutes)
            remaining -= maxFocusedMinutes
        }
        blocks.append(remaining)
        return blocks
    }

    // MARK: Rest proposal (ADR 0014 R3)

    /// Propose rests **between directly-adjacent focused blocks** (ADR 0014 R3): a break
    /// resets attention between deliberate work. Only injected where two `focused` blocks
    /// sit next to each other — an existing warm-up / play / rest already separates them,
    /// so none is added there. Pure: returns a new sequence, mutates nothing.
    static func withProposedRests(_ kinds: [RoutineItemKind]) -> [RoutineItemKind] {
        guard !kinds.isEmpty else { return [] }
        var result: [RoutineItemKind] = []
        for (index, kind) in kinds.enumerated() {
            result.append(kind)
            let next = index + 1
            if next < kinds.count, kind == .focused, kinds[next] == .focused {
                result.append(.rest)
            }
        }
        return result
    }

    // MARK: Authoring guard — no two rests in a row (ADR 0127)

    /// The number of **insertion slots** in a block list: one before every block plus one at the
    /// end, so a list of `n` blocks has `n + 1` places a rest could go.
    static func restSlotCount(_ kinds: [RoutineItemKind]) -> Int { kinds.count + 1 }

    /// Whether a rest may be inserted at `index` — the slot *before* `kinds[index]`, with
    /// `kinds.count` meaning the end of the list (ADR 0127).
    ///
    /// One rule, and only one: **a rest may not sit next to a rest.** Two rests in a row are just
    /// one longer break wearing two rows — they add nothing the existing rest's own length doesn't
    /// already say, and they read as a bug in the player, which would announce two breaks back to
    /// back. Every other position is fair game, including the head and tail of the list (a routine
    /// that opens or closes on a breather is a legitimate shape, and the append path has always
    /// allowed the trailing one).
    ///
    /// Out-of-range indices clamp rather than trap: this backs a tappable UI, and a stale index
    /// from a list that changed underneath should decline politely, not crash.
    static func allowsRest(at index: Int, in kinds: [RoutineItemKind]) -> Bool {
        let slot = min(max(index, 0), kinds.count)
        let before = slot > 0 ? kinds[slot - 1] : nil
        let after = slot < kinds.count ? kinds[slot] : nil
        return before != .rest && after != .rest
    }

    /// Every slot's verdict in one pass — `restSlotCount` entries, index-aligned with the slots the
    /// rest-insert UI draws. Convenience over `allowsRest(at:in:)` for rendering a whole list.
    static func restSlots(_ kinds: [RoutineItemKind]) -> [Bool] {
        (0...kinds.count).map { allowsRest(at: $0, in: kinds) }
    }

    // MARK: Orphan rule (ADR 0066 R5)

    /// A unit-bearing block whose referenced unit has gone missing is **orphaned** — the
    /// player skips it. A `rest` carries no unit, so it is never orphaned. Pure decision
    /// backing `RoutineItem.isOrphaned`.
    static func isOrphaned(kind: RoutineItemKind, hasResolvableUnit: Bool) -> Bool {
        kind.carriesUnit && !hasResolvableUnit
    }
}
