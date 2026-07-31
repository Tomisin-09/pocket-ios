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
    /// an hour of deliberate work. Under the block model (ADR 0129) `.full` lands on it exactly
    /// (4 blocks × 15 min), so it is now a structural property rather than a clamp applied after
    /// the fact; kept as the invariant a test pins.
    static let maxSessionMinutes = 60

    /// Nominal unbudgeted lengths for the structural book-ends (ADR 0014 R1). Warm-up and play are
    /// "as long as you like"; these are just sensible display defaults when a unit carries no
    /// estimate of its own.
    static let warmUpDefaultMinutes = 5
    static let playDefaultMinutes = 10

    /// In-block micro-rest cue cadence, minutes (ADR 0014 R4 — "~10 s every 1–2 min"). Emitted on
    /// every focused block; **no consumer reads it yet** — the field has been plumbed on
    /// `SessionBlock.focus` since R4 and passed `nil` at every construction site since, so this at
    /// least makes the planner state the cadence it was always specified to state.
    static let microRestEveryMinutes = 2

    /// Lay `candidates` out into a session of `length`'s **focused blocks** (ADR 0129).
    ///
    /// Warm-up (LRU-picked, unbudgeted) leads; play (a target run, unbudgeted) trails — each included
    /// only when provided, and play only when the preset schedules one. Steps: rank by dueScore →
    /// take the preset's item count → order U-shape (top-due LAST) → chunk into R2-sized blocks with
    /// a rest between blocks.
    ///
    /// Note what is *no longer* consulted: a candidate's own `estimatedMinutes`. A block's share sets
    /// each item's minutes, and the ramp is fitted to that share
    /// (`SessionEstimate.fitted(_:toMinutes:beatsPerBar:)`) rather than the item's natural length
    /// setting the block. That inversion is the point — it is why an exercise estimating one minute
    /// can no longer drag a whole session into fifteen stubs.
    static func buildSession(length: SessionLength,
                             candidates: [PlannerCandidate],
                             warmUp: PlannerCandidate? = nil,
                             play: PlannerCandidate? = nil,
                             now: Date) -> [SessionBlock] {
        let selected = select(candidates, items: length.items, now: now)
        let focused = blocked(uShape(selected))

        var blocks: [SessionBlock] = []
        if let warmUp {
            blocks.append(.warmUp(warmUp.unit, minutes: unbudgeted(warmUp, fallback: warmUpDefaultMinutes)))
        }
        blocks.append(contentsOf: focused)
        if let play, length.includesPlay {
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

    /// A chosen candidate with its dueScore (kept for U-shape ordering). Minutes are **not** held
    /// here: a block's share decides them, so they are assigned in `blocked` once the chunking is
    /// known and the number of items actually sharing a block is settled.
    struct Selected: Equatable {
        var candidate: PlannerCandidate
        var score: Double
    }

    /// Rank the goal-affiliated pool by dueScore (desc; ties → older-practised first, then `uid`)
    /// and take the preset's `items` (ADR 0129). Candidates with no goal (`priority ≤ 0`, ADR 0015
    /// S4) are excluded.
    static func select(_ candidates: [PlannerCandidate], items: Int, now: Date) -> [Selected] {
        guard items > 0 else { return [] }
        return candidates
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
            .prefix(items)
            .map { Selected(candidate: $0, score: DueScore.score($0, now: now)) }
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

    /// Chunk the ordered items into R2-sized focused blocks, threading a rest **between blocks**
    /// (ADR 0129, amending R3's "between every pair of focused blocks").
    ///
    /// Each block holds up to `SessionLength.itemsPerBlock` items — one pass each, adjacent, which
    /// *is* the rotation — and its `blockMinutes` are shared among the items it **actually** holds,
    /// so a library too thin to fill the last block yields fewer, longer items rather than a stub.
    /// The share is clamped to R2's ceiling: unreachable with the current constants, but a future
    /// `blockMinutes` could exceed it and the clamp is one comparison.
    ///
    /// Moving rests from between *items* to between *blocks* is what takes a "Quick 15" from fourteen
    /// rests to none.
    static func blocked(_ items: [Selected]) -> [SessionBlock] {
        guard !items.isEmpty else { return [] }
        var result: [SessionBlock] = []
        for start in stride(from: 0, to: items.count, by: SessionLength.itemsPerBlock) {
            let chunk = items[start..<min(start + SessionLength.itemsPerBlock, items.count)]
            if start > 0 { result.append(.rest(minutes: RoutineBudget.defaultRestMinutes)) }
            let share = min(RoutineBudget.maxFocusedMinutes,
                            max(1, SessionLength.blockMinutes / chunk.count))
            for item in chunk {
                result.append(.focus(item.candidate.unit, minutes: share,
                                     microRestEvery: microRestEveryMinutes))
            }
        }
        return result
    }

    /// An unbudgeted book-end's minutes: the unit's own estimate when it has one, else a nominal
    /// default. Never counted against the focused budget (ADR 0014 R1).
    private static func unbudgeted(_ candidate: PlannerCandidate, fallback: Int) -> Int {
        candidate.estimatedMinutes > 0 ? candidate.estimatedMinutes : fallback
    }
}
