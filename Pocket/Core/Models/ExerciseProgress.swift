import Foundation

/// The cross-session **light progress** of an exercise (ADR 0043, slice 7): how its working
/// `current` tempo sits against the `target` goal it climbs toward. The gap between the two
/// *is* the whole progress signal — no audio analysis and no logged history, the
/// deliberately "light" model the ADR locked in (the number moving over time, nothing
/// auto-rewritten).
///
/// Pure and unit-tested: the bar fraction and the readout are exactly the clamping /
/// divide-by-zero logic that breaks silently (AGENTS.md — pure tempo logic must be covered).
struct ExerciseProgress: Equatable {
    /// The day-to-day working tempo (absolute BPM).
    let current: Int
    /// The goal tempo (absolute BPM) being climbed toward.
    let target: Int

    /// Fill for the progress track, `0...1`: the working tempo as a fraction of the goal,
    /// clamped. `0` when the goal isn't positive (guards bad data / divide-by-zero).
    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(target)))
    }

    /// BPM still to climb; `0` once the working tempo reaches or passes the goal.
    var remaining: Int { max(0, target - current) }

    /// Whether the working tempo has met or beaten the goal.
    var isAtTarget: Bool { current >= target }

    /// The compact current→target readout: "92 → 120 BPM".
    var readout: String { "\(current) → \(target) BPM" }

    /// Short status — "28 BPM to go" while climbing, "At target" once the goal is met.
    var status: String { isAtTarget ? "At target" : "\(remaining) BPM to go" }
}

extension Exercise {
    /// This exercise's command-vs-target reach (ADR 0043 slice 7; re-anchored by ADR 0045).
    /// `current` is the effective `command` — the measured owned tempo, or the working tempo
    /// until one is promoted — so an un-promoted exercise reads exactly as the old
    /// working-vs-goal light model and a promoted one reads command-vs-reach.
    var progress: ExerciseProgress {
        ExerciseProgress(current: command, target: targetTempo)
    }
}
