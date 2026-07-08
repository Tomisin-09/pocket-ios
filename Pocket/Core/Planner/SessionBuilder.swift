import Foundation

/// The planner's **back-half** (V2 planner, ADR 0014): lays a ranked candidate list out into a
/// timed, ordered, rest-punctuated session — `buildSession(minutes:candidates:…) → [SessionBlock]`.
/// Composes after the front-half (`deriveCandidates`, Slice 2); Slice 1 feeds it a trivial
/// dueness-only candidate list so "generate a session from my library" works before goals exist.
///
/// Pure and **SwiftData-/SwiftUI-/AVFoundation-free** (Foundation only) so the whole layout is
/// unit-tested per AGENTS.md. It *calls into* `RoutineBudget` for the block-cap / rest constants
/// (ADR 0014 R2/R3) rather than duplicating them, and emits `SessionBlock`s the materialiser turns
/// into a `Routine`.
enum SessionBuilder {

    /// Hard ceiling on total focused minutes in one session (ADR 0014 R7) — no sitting runs past
    /// an hour of deliberate work, whatever preset or budget is asked for.
    static let maxSessionMinutes = 60

    /// Nominal unbudgeted lengths for the structural book-ends (ADR 0014 R1). Warm-up and play are
    /// "as long as you like"; these are just sensible display defaults when a unit carries no
    /// estimate of its own.
    static let warmUpDefaultMinutes = 5
    static let playDefaultMinutes = 10

    /// Lay `candidates` out into a timed session for a `minutes` **focused** budget (ADR 0014).
    /// Warm-up (LRU-picked, unbudgeted) leads; play (a target run, unbudgeted) trails — each
    /// included only when provided. Steps: rank by dueScore → greedily fill the budget under the
    /// 60-min cap → order U-shape (top-due LAST) → split blocks over the cap → rest between adjacent
    /// focused blocks.
    static func buildSession(minutes: Int,
                             candidates: [PlannerCandidate],
                             warmUp: PlannerCandidate? = nil,
                             play: PlannerCandidate? = nil,
                             now: Date) -> [SessionBlock] {
        let budget = min(max(0, minutes), maxSessionMinutes)
        let selected = select(candidates, budget: budget, now: now)
        let ordered = uShape(selected)
        let focused = interleaveRests(timeBox(ordered))

        var blocks: [SessionBlock] = []
        if let warmUp {
            blocks.append(.warmUp(warmUp.unit, minutes: unbudgeted(warmUp, fallback: warmUpDefaultMinutes)))
        }
        blocks.append(contentsOf: focused)
        if let play {
            blocks.append(.play(play.unit, minutes: unbudgeted(play, fallback: playDefaultMinutes)))
        }
        return blocks
    }

    /// LRU pick for the structural warm-up (ADR 0014 R1 / Decision 3): the **least-recently
    /// practised** `template == .warmup` candidate — never-practised (`nil`) counts as most stale
    /// and is picked first; ties break by `uid` for determinism. `nil` when the pool is empty (the
    /// caller then omits the warm-up block). Deliberately *not* dueScore — a warm-up's job is
    /// loosening up, not targeting a weakness.
    static func warmUpPick(_ warmUps: [PlannerCandidate]) -> PlannerCandidate? {
        warmUps.min { lhs, rhs in
            let lhsDate = lhs.lastPracticed ?? .distantPast
            let rhsDate = rhs.lastPracticed ?? .distantPast
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.unit.uid.uuidString < rhs.unit.uid.uuidString
        }
    }

    // MARK: - Stages (internal, but each independently testable)

    /// A chosen candidate with its allotted minutes and its dueScore (kept for U-shape ordering).
    struct Selected: Equatable {
        var candidate: PlannerCandidate
        var minutes: Int
        var score: Double
    }

    /// Rank the goal-affiliated pool by dueScore (desc; ties → older-practised first, then `uid`)
    /// and greedily fill the budget, trimming the final block to fit exactly (ADR 0014 R1/R7).
    /// Candidates with no goal (`priority ≤ 0`, ADR 0015 S4) are excluded.
    static func select(_ candidates: [PlannerCandidate], budget: Int, now: Date) -> [Selected] {
        guard budget > 0 else { return [] }
        let ranked = candidates
            .filter { $0.priority > 0 }
            .sorted { lhs, rhs in
                let lhsScore = DueScore.score(lhs, now: now)
                let rhsScore = DueScore.score(rhs, now: now)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                let lhsDate = lhs.lastPracticed ?? .distantPast
                let rhsDate = rhs.lastPracticed ?? .distantPast
                if lhsDate != rhsDate { return lhsDate < rhsDate }
                return lhs.unit.uid.uuidString < rhs.unit.uid.uuidString
            }

        var selected: [Selected] = []
        var used = 0
        for candidate in ranked {
            guard used < budget else { break }
            let want = max(1, candidate.estimatedMinutes)
            let take = min(want, budget - used)
            selected.append(Selected(candidate: candidate, minutes: take,
                                     score: DueScore.score(candidate, now: now)))
            used += take
        }
        return selected
    }

    /// Arrange selected blocks into the **U-shape** (ADR 0014 R5): the single highest-due item goes
    /// **last** (the peak-effort finale, never buried mid-session), the next-highest leads, and the
    /// lowest sit in the middle — high energy at both ends, maintenance in the valley. A single item
    /// is trivially last.
    static func uShape(_ items: [Selected]) -> [Selected] {
        guard items.count > 1 else { return items }
        let sorted = items.sorted { lhs, rhs in
            lhs.score != rhs.score
                ? lhs.score > rhs.score
                : lhs.candidate.unit.uid.uuidString < rhs.candidate.unit.uid.uuidString
        }
        let peak = sorted[0]
        var front: [Selected] = []
        var back: [Selected] = []
        for (index, item) in sorted.dropFirst().enumerated() {
            if index.isMultiple(of: 2) { front.append(item) } else { back.append(item) }
        }
        return front + back.reversed() + [peak]
    }

    /// Split any selection whose minutes exceed the block cap into several focused blocks, none over
    /// `RoutineBudget.maxFocusedMinutes` (ADR 0014 R2), preserving each block's unit. The split
    /// halves stay adjacent (a rest is threaded between them by `interleaveRests`).
    static func timeBox(_ items: [Selected]) -> [SessionBlock] {
        var result: [SessionBlock] = []
        for item in items {
            for chunk in RoutineBudget.splitFocused(item.minutes) {
                result.append(.focus(item.candidate.unit, minutes: chunk, microRestEvery: nil))
            }
        }
        return result
    }

    /// Thread a rest between every pair of directly-adjacent focused blocks (ADR 0014 R3) — a break
    /// resets attention between deliberate work. Nothing is added before the first block (the
    /// warm-up already separates it) or after the last.
    static func interleaveRests(_ focused: [SessionBlock]) -> [SessionBlock] {
        guard !focused.isEmpty else { return [] }
        var result: [SessionBlock] = []
        for (index, block) in focused.enumerated() {
            if index > 0 { result.append(.rest(minutes: RoutineBudget.defaultRestMinutes)) }
            result.append(block)
        }
        return result
    }

    /// An unbudgeted book-end's minutes: the unit's own estimate when it has one, else a nominal
    /// default. Never counted against the focused budget (ADR 0014 R1).
    private static func unbudgeted(_ candidate: PlannerCandidate, fallback: Int) -> Int {
        candidate.estimatedMinutes > 0 ? candidate.estimatedMinutes : fallback
    }
}
