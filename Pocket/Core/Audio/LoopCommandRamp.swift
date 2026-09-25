import Foundation

/// Maps a loop's command-anchored progression onto the shared `CommandRamp` staircase
/// (ADR 0046, Phase B). A loop trains the *same* warm-up → dwell → reach → back-off shape as a
/// metronome `Exercise`, but its tempo is a fraction of original (`×`), not absolute BPM — so the
/// `×` working / command / reach are expressed as **integer percent-of-original** (`0.85×` → `85`)
/// and fed to `CommandRamp` unchanged. `CommandRamp` is reused, not forked: the plateau math,
/// live cursor, and completion all work on percent, and `RoutineStairs` renders it as-is.
///
/// Holds are counted in **loop passes** — one pass through the region is one interval, which is how
/// a loop is actually practised ("play it through, then bump it up"). A loop has no metronome bars,
/// so the ramp reuses `CommandRamp`'s `.bars` interval mechanism with "bars" reinterpreted as *loop
/// passes*: the run driver feeds `PracticeAudioEngine.loopIteration` as the elapsed count. That count
/// is **rate-independent** (it counts musical repetitions, not frames), so a plateau holds a fixed
/// number of passes regardless of the tempo it plays at. Pure and UI-free so the percent rounding
/// (the kind of tempo math that breaks silently) is unit-tested per AGENTS.md.
enum LoopCommandRamp {

    /// Passes per hold interval — one (ADR 0221 D8). A loop's holds are stated in passes, so the
    /// interval is a single pass; it used to be a player-set **reps per step**, which multiplied
    /// every hold and is now folded into them (`Loop.runShape`).
    static let passesPerInterval = 1

    /// `×`-of-original → integer percent (`0.85×` → `85`). Rounded to the nearest whole percent
    /// so the staircase reads in clean steps; `clamped` only against negatives (a loop speed is
    /// always positive in practice).
    static func percent(_ speed: Double) -> Int { max(0, Int((speed * 100).rounded())) }

    /// Build the staircase for a loop run from its `×` tempos and its shape (ADR 0221), in percent
    /// units and one pass per interval — so every hold in `shape` is a number of passes. The warm-up
    /// is placed by count, as every phase is (D4); a pinned `backoffOverride` is converted with the
    /// tempos, and an unpinned one is derived by the ramp in the same percent domain.
    static func make(working: Double, command: Double, target: Double,
                     shape: RunShape = RunShape(), backoffOverride: Double? = nil) -> CommandRamp {
        let floor = percent(working), owned = percent(command), reach = percent(target)
        let backoff = backoffOverride.map(percent)
            ?? TempoStretch.backoffBPM(command: owned, target: reach, floor: floor)
        return make(tempos: RampTempos(working: floor, command: owned, reach: reach, backoff: backoff),
                    shape: shape, backoffOverride: backoffOverride.map(percent))
    }

    /// The same, from tempos already in percent — what the run screen edits in.
    static func make(tempos: RampTempos, shape: RunShape, backoffOverride: Int?) -> CommandRamp {
        CommandRamp(tempos: tempos, shape: shape, backoffOverride: backoffOverride,
                    intervalCount: passesPerInterval, unit: .bars)
    }
}
