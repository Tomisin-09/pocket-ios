import Foundation

/// Pure, UI-free sample-grid math for the **standalone** metronome (ADR 0047). The
/// standalone click lives on its own sample clock — tick `i` sounds at
/// `origin + round(i · subInterval)` frames (`StandaloneMetronomeEngine.tick`). When the
/// automator steps the tempo mid-climb, the *spacing* changes but we want the grid to keep
/// its place: the click you're hearing must not jump, and the downbeat must stay a downbeat.
///
/// This computes the **re-anchored origin** for a phase-continuous tempo change. Kept here
/// (Foundation only, frame positions as `Int64`) so the splice math — the kind that breaks
/// silently without coverage — is unit-tested, free of AVFoundation (AGENTS.md).
enum MetronomeGrid {

    /// New grid origin for a tempo change that preserves phase. The last *already-scheduled*
    /// tick (`scheduledThrough`) keeps its exact sample, and the next unscheduled tick lands
    /// one **new** interval after it — so the heard click splices seamlessly and the tick
    /// counter (hence the accent pattern, hence the downbeats) carries on unbroken.
    ///
    /// Solve `origin' + round(scheduledThrough · newInterval) == lastTickSample`, where
    /// `lastTickSample == origin + round(scheduledThrough · oldInterval)`.
    ///
    /// - Parameters:
    ///   - origin: the current grid origin (sample of tick 0) before the change.
    ///   - scheduledThrough: index of the last tick already queued to the audio layer.
    ///   - oldSubInterval: frames between ticks at the *current* tempo.
    ///   - newSubInterval: frames between ticks at the *new* tempo.
    /// - Returns: the origin to adopt so future ticks (`> scheduledThrough`) use the new
    ///   spacing while the queued ticks are left exactly where they sound.
    static func reanchoredOrigin(origin: Int64, scheduledThrough: Int,
                                 oldSubInterval: Double, newSubInterval: Double) -> Int64 {
        let lastTickSample = origin + frames(scheduledThrough, interval: oldSubInterval)
        return lastTickSample - frames(scheduledThrough, interval: newSubInterval)
    }

    /// Sample offset of tick `index` from an origin at the given interval — the rounding the
    /// engine's `subSample` applies, mirrored so the re-anchor lands on the same frame.
    static func frames(_ index: Int, interval: Double) -> Int64 {
        Int64((Double(index) * interval).rounded())
    }
}
