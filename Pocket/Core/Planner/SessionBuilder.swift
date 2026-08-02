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
        let (jams, drills) = partitionJams(candidates)
        let selected = select(drills, items: length.items, now: now)
        let focused = blocked(uShape(selected))

        var blocks: [SessionBlock] = []
        if let warmUp {
            blocks.append(.warmUp(warmUp.unit, minutes: unbudgeted(warmUp, fallback: warmUpDefaultMinutes)))
        }
        blocks.append(contentsOf: focused)
        if length.includesPlay, let trailer = playBlock(explicit: play, jams: jams, now: now) {
            blocks.append(trailer)
        }
        return blocks
    }

    /// Split the pool into backing-track **jams** and everything else (ADR 0135 B6a). A jam is placed
    /// as the session's trailing `play` block, never as a `focus` one: `RoutineItemKind.play` is
    /// precisely a full run-through — surfaced but unbudgeted (ADR 0014 R1) — and a jam charged
    /// against a focused budget would be miscounted work dragging session sizing (ADR 0129) around.
    ///
    /// Partitioning **before** selection rather than after is the point: a jam that consumed one of
    /// the preset's focus items would cost the player a drill to schedule something the preset never
    /// budgeted for.
    static func partitionJams(_ candidates: [PlannerCandidate]) -> (jams: [PlannerCandidate],
                                                                    drills: [PlannerCandidate]) {
        var jams: [PlannerCandidate] = []
        var drills: [PlannerCandidate] = []
        for candidate in candidates where candidate.priority > 0 {
            if candidate.runMode == .improvise { jams.append(candidate) } else { drills.append(candidate) }
        }
        return (jams, drills)
    }

    /// The single trailing play-through. An explicitly-passed `play` (a goal's target song) wins;
    /// otherwise the **top-ranked** jam takes the slot. Exactly one, because R1's structure has one
    /// finale — a session ending in three jams would be a jam session, which is not what was asked
    /// for.
    ///
    /// A jam's minutes come from `RampLessBlockLength`, not from the candidate's `region × repeats`
    /// estimate: the materialised block carries no `plannedMinutes` (play is unbudgeted, so
    /// `PracticePlanner.item` leaves it `nil`), which means ADR 0141's mode default is what it will
    /// actually run for. Displaying anything else would be the review screen promising a length the
    /// player won't get.
    private static func playBlock(explicit: PlannerCandidate?, jams: [PlannerCandidate],
                                  now: Date) -> SessionBlock? {
        if let explicit {
            return .play(explicit.unit, minutes: unbudgeted(explicit, fallback: playDefaultMinutes),
                         mode: explicit.runMode)
        }
        guard let jam = ranked(jams, now: now).first else { return nil }
        let minutes = RampLessBlockLength.defaultMinutes(for: .improvise) ?? playDefaultMinutes
        return .play(jam.unit, minutes: minutes, mode: .improvise)
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

    /// Rank the goal-affiliated pool and take the preset's `items`, **dealing across the active
    /// goals** rather than skimming the top N (ADR 0129 as amended). Candidates with no goal
    /// (`priority ≤ 0`, ADR 0015 S4) are excluded.
    ///
    /// The straight top-N was fine while a session held ~15 items — every goal got in by brute force —
    /// and broke the moment ADR 0129 cut Quick to **three**, where the top-ranked goal simply took
    /// every slot and the player's second goal never appeared. Round-robin is the smallest fix that
    /// restores the guarantee: each goal is represented while it has candidates left, and a goal with
    /// more due material still wins the later slots.
    static func select(_ candidates: [PlannerCandidate], items: Int, now: Date) -> [Selected] {
        guard items > 0 else { return [] }
        return roundRobin(ranked(candidates, now: now), items: items)
            .map { Selected(candidate: $0, score: DueScore.score($0, now: now)) }
    }

    /// The eligible pool in strict dueScore order (desc; ties → older-practised first, then `uid`) —
    /// a total order, so everything downstream of it is deterministic despite `deriveCandidates`
    /// returning an unordered dictionary's values.
    static func ranked(_ candidates: [PlannerCandidate], now: Date) -> [PlannerCandidate] {
        candidates
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
    }

    /// Deal `items` from an already-`ranked` pool, one per goal per pass. Goals are visited in the
    /// order their **best** candidate ranks, so the most-due goal still leads and still gets the extra
    /// slot when the count doesn't divide evenly. A goal that runs out is skipped rather than holding
    /// a place, so a thin second goal never costs the session an item. With one goal — or none, the
    /// goal-less Quick path where every candidate carries `priority = 1` — this is exactly the old
    /// top-N.
    static func roundRobin(_ ranked: [PlannerCandidate], items: Int) -> [PlannerCandidate] {
        var order: [UUID?] = []
        var byGoal: [UUID?: [PlannerCandidate]] = [:]
        for candidate in ranked {
            if byGoal[candidate.goalUID] == nil { order.append(candidate.goalUID) }
            byGoal[candidate.goalUID, default: []].append(candidate)
        }

        var picked: [PlannerCandidate] = []
        var pass = 0
        while picked.count < items {
            let before = picked.count
            for goal in order where picked.count < items {
                guard let pool = byGoal[goal], pass < pool.count else { continue }
                picked.append(pool[pass])
            }
            if picked.count == before { break }   // every goal exhausted
            pass += 1
        }
        return picked
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
                                     microRestEvery: microRestEveryMinutes,
                                     mode: item.candidate.runMode))
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
