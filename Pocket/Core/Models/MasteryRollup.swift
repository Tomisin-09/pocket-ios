import Foundation

/// Rolls per-loop mastery up to a song-level value (ADR 0036). A loop-centric
/// practice app stores mastery where practice happens — on loops — and derives the
/// song summary from it; there is no stored song proficiency any more.
///
/// Kept SwiftData-free and pure so the rounding/empty boundaries (the logic that
/// breaks silently) are unit-testable per AGENTS.md.
enum MasteryRollup {
    /// The rounded average of a song's loop mastery values, or `nil` when there are
    /// no loops (the "unrated" state). Half-values round to nearest (`.toNearestOrAwayFromZero`).
    static func rollup(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(values.count)).rounded())
    }
}
