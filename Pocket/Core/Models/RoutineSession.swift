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
    /// Number of playable blocks — never negative.
    let total: Int
    /// 0-based index of the current block; equals `total` once every block has run.
    private(set) var index: Int

    init(total: Int) {
        self.total = max(0, total)
        self.index = 0
    }

    /// True when every block has run — or the routine had nothing playable to begin with.
    var isComplete: Bool { index >= total }

    /// 1-based position of the current block — the "2" in "2 of 5". `0` when complete or empty.
    var position: Int { isComplete ? 0 : index + 1 }

    /// "2 of 5" — the session progress label; empty when there is nothing to play.
    var progressLabel: String { total > 0 ? "\(min(index + 1, total)) of \(total)" : "" }

    /// Step to the next block. A no-op once complete, so the cursor never runs past the end.
    mutating func advance() {
        if index < total { index += 1 }
    }

    /// Step back to the previous block. A no-op at the first block, so the cursor never goes negative.
    mutating func retreat() {
        if index > 0 { index -= 1 }
    }
}
