import Foundation

/// What happens to an exercise's tempos when its **rhythm** changes (ADR 0121).
///
/// Moving Rhythm from eighths to sixteenths doubles the notes each beat carries, so every BPM on the
/// drill now means something different — including the *measured* command tempo, which ADR 0045
/// defines as an achievement, not an aspiration. Silently leaving 80 in place revalues that
/// achievement with no event marking it; silently rescaling it rewrites it without asking. So the
/// change is a question with exactly two honest answers, and this type is the pure arithmetic behind
/// them.
///
/// UI-free and total, so the rescale — the part that quietly corrupts a whole ramp when it's wrong —
/// is unit-tested (AGENTS.md).
enum RhythmChange {

    /// The exercise tempos a rhythm change has to carry across: the warm-up floor, the measured
    /// command, and the two manual pins (`nil` = auto-derived, and an auto value stays auto — it
    /// re-derives from the new command by itself).
    struct Tempos: Equatable {
        var working: Int
        var command: Int
        var reachOverride: Int?
        var backoffOverride: Int?
    }

    /// The tempos rescaled so the **note speed is unchanged**: eighths at 80 and sixteenths at 40
    /// are both 160 notes a minute, so what the player owns is preserved even though every number
    /// moves. Applied to working and the pins as well as command — a floor left at the old rhythm
    /// would sit *above* the rescaled command and invert the ramp.
    ///
    /// Results are clamped into `range` and the ramp invariants restored afterwards: a pinned reach
    /// must stay strictly above command and a pinned backoff at or below it (the same rules
    /// `promoteCommand` enforces), so clamping or rounding at the ends of the range can't produce a
    /// ramp that climbs backwards. A pin that collides after clamping is **dropped to auto** rather
    /// than nudged, since the derived value is always valid.
    static func keepingNoteSpeed(_ tempos: Tempos, from oldPerBeat: Int, to newPerBeat: Int,
                                 clampedTo range: ClosedRange<Int>) -> Tempos {
        let old = max(1, oldPerBeat), new = max(1, newPerBeat)
        func scaled(_ bpm: Int) -> Int {
            let value = (Double(bpm) * Double(old) / Double(new)).rounded()
            return min(range.upperBound, max(range.lowerBound, Int(value)))
        }
        let command = scaled(tempos.command)
        var result = Tempos(working: min(command, scaled(tempos.working)),
                            command: command,
                            reachOverride: tempos.reachOverride.map(scaled),
                            backoffOverride: tempos.backoffOverride.map(scaled))
        // A reach must stay above command, a backoff at or below it — drop a pin that can't.
        if let reach = result.reachOverride, reach <= command { result.reachOverride = nil }
        if let backoff = result.backoffOverride, backoff > command { result.backoffOverride = nil }
        return result
    }

    /// The note speed a tempo represents at a rhythm — the number "keep the same note speed" holds
    /// fixed, and what the choice sheet quotes so the player can see the trade rather than trust it.
    static func notesPerMinute(bpm: Int, perBeat: Int) -> Int {
        NoteRate(perBeat: perBeat).notesPerMinute(atBPM: bpm)
    }
}
