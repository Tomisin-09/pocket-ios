import Foundation

/// Where the cursor goes after a note is tapped into a hand-drawn drill, and whether the run has to
/// **grow** to make room (device feedback 2026-07-29).
///
/// Placing auto-advances so a run can be tapped in without reaching for the strip between notes. The
/// question is what happens at the end. Wrapping back to slot 1 — the original behaviour — silently
/// overwrote the notes just placed: nothing on the fretboard says you've reached the end of the bar,
/// so the run stopped growing while the taps kept landing. Appending a bar instead fails in the
/// recoverable direction: a spare empty bar is visible in the strip and one stepper tap away, where
/// an overwritten note is simply gone.
///
/// Pure and UI-free so the rule is unit-tested rather than inferred from the editor (AGENTS.md).
enum DrillPlacement {

    /// The outcome of one placement: the bar count the drill must be resized to first (`nil` = leave
    /// the grid alone), and the slot the cursor ends on.
    struct Advance: Equatable {
        /// The new whole-bar count to grow to before advancing, or `nil` when the run already has room.
        var growToBars: Int?
        /// The slot the cursor lands on — always inside the (possibly grown) run.
        var cursor: Int
    }

    /// Resolve a placement into `slot` of a `slotCount`-slot, `barCount`-bar run.
    ///
    /// - Mid-run: step to the next slot, nothing grows.
    /// - On the final slot with bars to spare: grow one bar and step into it.
    /// - On the final slot at `maxBars`: **hold the cursor where it is**. There is no room to grow and
    ///   no safe slot to move to, and a stuck cursor at the end reads as "this run is full" — still
    ///   never a silent overwrite of the start.
    static func advance(fromSlot slot: Int, slotCount: Int, barCount: Int,
                        maxBars: Int) -> Advance {
        let slots = max(1, slotCount)
        let current = min(max(0, slot), slots - 1)
        guard current >= slots - 1 else { return Advance(growToBars: nil, cursor: current + 1) }
        guard barCount < maxBars else { return Advance(growToBars: nil, cursor: current) }
        return Advance(growToBars: barCount + 1, cursor: current + 1)
    }
}
