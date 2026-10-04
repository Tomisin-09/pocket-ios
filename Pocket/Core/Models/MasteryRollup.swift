import Foundation

/// Rolls per-loop mastery up to a song-level value (ADR 0036). A loop-centric
/// practice app stores mastery where practice happens — on loops — and derives the
/// song summary from it; there is no stored song proficiency any more.
///
/// Kept SwiftData-free and pure so the rounding/empty boundaries (the logic that
/// breaks silently) are unit-testable per AGENTS.md.
enum MasteryRollup {
    /// The rounded average of a song's **rated** loop mastery values, or `nil` when no loop
    /// is rated (the "unrated" state). `nil` values — loops never rated (ADR 0039) — are
    /// skipped, so one untouched loop no longer drags the song summary down with a phantom
    /// `0`. Half-values round to nearest (`.toNearestOrAwayFromZero`).
    static func rollup(_ values: [Int?]) -> Int? {
        let rated = values.compactMap { $0 }
        guard !rated.isEmpty else { return nil }
        let total = rated.reduce(0, +)
        return Int((Double(total) / Double(rated.count)).rounded())
    }

    /// What the average is made of, said beside it on Song details (ADR 0250 D9) — "2 of 3 loops
    /// rated". A raised loop drops out until it is rated again, so the dots alone can't say how many
    /// loops they stand for. The noun agrees with the total: "1 of 1 loop rated".
    static func ratedLabel(rated: Int, of total: Int) -> String {
        "\(rated) of \(total) \(total == 1 ? "loop" : "loops") rated"
    }
}
