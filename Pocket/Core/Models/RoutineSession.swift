import Foundation

/// What kind of block the routine **player** is running (ADR 0066, slice 3) — the player's view of
/// a `RoutineItem`, reduced to what drives its *surface and completion trigger* rather than the
/// persisted `RoutineItemKind` (Focus/Warm-up/Play/Rest). An exercise runs a click ramp, a loop
/// runs an audio ramp, a rest counts down; the `song` case is reserved for the audio-only
/// play-along (a following slice) and is not authored yet.
///
/// SwiftData-free (Foundation only) so the pure stepping layer stays importable everywhere (the
/// "pure logic stays pure" rule, AGENTS.md).
enum RoutineStageKind: Equatable {
    case exercise, loop, song, rest
    /// A loop run **ears-only** for ear training (ADR 0104 Slice 2) — same loop unit as `.loop`, but
    /// the player embeds `EarLoopRunView` (continuous playback + hum/sing + note) instead of the
    /// command-anchored trainer. Manual-advance, no ramp; treated as a unit block (never a rest).
    case earLoop
}

/// A pure cursor over a routine's playable blocks (ADR 0066, slice 3): position and advancement
/// only. The conductor (`RoutineSessionPlayer`) owns the engines and the model references; this
/// owns the **stepping**, so the index math stays SwiftData-/SwiftUI-free and unit-tested — the
/// kind of off-by-one boundary logic that breaks silently (AGENTS.md).
///
/// `count` is the number of *playable* blocks the conductor resolved (orphaned and
/// not-yet-supported blocks already filtered out). The cursor climbs `0…count`; reaching `count`
/// means the session is complete.
struct RoutineSessionCursor: Equatable {
    /// Per-block **repeat counts** (R3), clamped to at least one, one entry per playable block. The
    /// cursor's length (`total`) is this array's count; a block with `reps[index] > 1` is run
    /// back-to-back that many times before the cursor rolls to the next block.
    let reps: [Int]
    /// 0-based index of the current block; equals `total` once every block has run.
    private(set) var index: Int
    /// 1-based run within the current block — the "2" in "Rep 2 of 3". Resets to `1` on every block
    /// change (advance past the last rep, skip, or retreat).
    private(set) var rep: Int

    /// Number of playable blocks — never negative.
    var total: Int { reps.count }

    /// Full initializer — one repeat count per playable block (R3).
    init(reps: [Int]) {
        self.reps = reps.map { max(1, $0) }
        self.index = 0
        self.rep = 1
    }

    /// Convenience for callers/tests that don't vary reps: `total` single-run blocks.
    init(total: Int) {
        self.init(reps: Array(repeating: 1, count: max(0, total)))
    }

    /// True when every block has run — or the routine had nothing playable to begin with.
    var isComplete: Bool { index >= total }

    /// 1-based position of the current block — the "2" in "2 of 5". `0` when complete or empty.
    var position: Int { isComplete ? 0 : index + 1 }

    /// "2 of 5" — the session progress label; empty when there is nothing to play.
    var progressLabel: String { total > 0 ? "\(min(index + 1, total)) of \(total)" : "" }

    /// How many times the current block repeats — `0` when complete.
    var repsForCurrent: Int { isComplete ? 0 : reps[index] }

    /// Whether the current block has another rep to run before it's done (a multi-rep block, ADR 0076).
    var hasMoreReps: Bool { !isComplete && rep < reps[index] }

    /// "Rep 2 of 3" for a multi-rep block, else empty (a single-run block reads no rep counter).
    var repLabel: String {
        (!isComplete && reps[index] > 1) ? "Rep \(rep) of \(reps[index])" : ""
    }

    /// **Natural completion of one run.** On a multi-rep block, step to the next rep of the *same*
    /// block; on its last rep, roll to the next block and reset the rep counter. A no-op once
    /// complete, so the cursor never runs past the end.
    mutating func advance() {
        guard !isComplete else { return }
        if rep < reps[index] { rep += 1 } else { rep = 1; index += 1 }
    }

    /// **User skip** — jump to the next block, abandoning any remaining reps of the current one.
    mutating func skip() {
        guard !isComplete else { return }
        rep = 1
        index += 1
    }

    /// Step back to the previous block (resetting its rep). A no-op at the first block, so the cursor
    /// never goes negative.
    mutating func retreat() {
        if index > 0 { index -= 1 }
        rep = 1
    }
}
