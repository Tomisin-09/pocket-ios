import Foundation

/// Pure, UI-free **practice stats** for the home hub — a first slice of glanceable *measures*
/// derived entirely from what's already stored (no new persistence): how many loops and exercises
/// you have, how many loops you've fully mastered, and how many journal notes you've written.
///
/// Kept SwiftData/SwiftUI-free (it works over plain values, not `@Model`s) so the counting and the
/// "mastered" threshold — the kind of off-by-one that breaks silently — are unit-tested per
/// AGENTS.md. The view gathers the raw inputs from its `@Query`s and hands them here.
enum PracticeStats {

    /// Top of the 0–5 mastery scale (`MasteryDots`) — a loop counts as **mastered** at this value.
    static let masteryCeiling = 5

    /// The four headline numbers the home card shows. `Equatable` so the view diffs cheaply.
    struct Summary: Equatable {
        var loops: Int
        var exercises: Int
        /// Loops sitting at the top of the mastery scale — the "Mastered" tile.
        var fullMasteryCount: Int
        var notes: Int

        /// Nothing to show yet — a fresh library with no loops *or* exercises. The card hides on
        /// this so first launch isn't a wall of zeros.
        var isEmpty: Bool { loops == 0 && exercises == 0 }
    }

    /// Roll the raw inputs into the summary. `loopMasteryValues` is one entry per loop (its
    /// `mastery`, `nil` when unrated); `totalNotes` is the journal-entry count across every loop
    /// and exercise.
    static func summarize(loopMasteryValues: [Int?],
                          exerciseCount: Int,
                          totalNotes: Int) -> Summary {
        Summary(loops: loopMasteryValues.count,
                exercises: exerciseCount,
                fullMasteryCount: loopMasteryValues.lazy.filter { $0 == masteryCeiling }.count,
                notes: totalNotes)
    }
}
