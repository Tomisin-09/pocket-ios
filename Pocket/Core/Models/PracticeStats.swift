import Foundation

/// Pure, UI-free **practice stats** for the home hub — a first slice of glanceable *measures*
/// derived entirely from what's already stored (no new persistence): how many loops and exercises
/// you have, how many loops you've fully mastered, and how many journal notes you've written.
///
/// Kept SwiftData/SwiftUI-free (it works over plain values, not `@Model`s) so the counting and the
/// "mastered" threshold — the kind of off-by-one that breaks silently — are unit-tested per
/// AGENTS.md. The view gathers the raw inputs from its `@Query`s and hands them here.
enum PracticeStats {

    /// Top of the 0–5 mastery scale (`MasteryDots`) — a loop counts as **mastered** at this value,
    /// **at full speed** (ADR 0250 D10).
    static let masteryCeiling = 5

    /// One loop, as the counts need it: its rating and the command it was given at. Under ADR 0250 a
    /// rating is always at the loop's *current* command — the effective one (`Loop.command`), which
    /// for an unmeasured loop is its practice speed.
    struct LoopFacts: Equatable {
        var mastery: Int?
        var command: Double
    }

    /// The four headline numbers the home card shows. `Equatable` so the view diffs cheaply.
    struct Summary: Equatable {
        var loops: Int
        var exercises: Int
        /// Loops rated at the top of the scale **at full speed** — the "Mastered" tile. A 5 below
        /// full speed is the cue to raise the tempo, not a loop finished (ADR 0250 D10).
        var fullMasteryCount: Int
        var notes: Int

        /// Nothing to show yet — a fresh library with no loops *or* exercises. The card hides on
        /// this so first launch isn't a wall of zeros.
        var isEmpty: Bool { loops == 0 && exercises == 0 }
    }

    /// Roll the raw inputs into the summary. `loops` is one entry per loop; `totalNotes` is the
    /// journal-entry count across every loop and exercise.
    static func summarize(loops: [LoopFacts],
                          exerciseCount: Int,
                          totalNotes: Int) -> Summary {
        Summary(loops: loops.count,
                exercises: exerciseCount,
                fullMasteryCount: loops.lazy.filter(hasFullMastery).count,
                notes: totalNotes)
    }

    /// Rated 5, at full speed — the one place the threshold is decided.
    static func hasFullMastery(_ loop: LoopFacts) -> Bool {
        loop.mastery == masteryCeiling && SongSpeed.isFullSpeed(loop.command)
    }
}
