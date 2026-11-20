import Foundation

/// How a take gets its number (ADR 0307 D7): counted where it was recorded, one more than the highest
/// number that count has already given, starting at 1.
///
/// Pure and Foundation-only (AGENTS.md), beside `TakeExportName`, so the rule is tested without a
/// store. Where the numbers come from (a loop's relationship, a fetch of the metronome's takes) is
/// `RecordingOwner`'s business; this only does the counting.
enum TakeNumbering {

    /// What a take with this number is called when the player hasn't named it: *Take 3* (D3).
    static func name(_ number: Int) -> String { "Take \(number)" }

    /// The number the next take in a count gets, given the numbers that count has already given.
    ///
    /// One more than the **highest**, not one more than the count: a gap left by deleting an older
    /// take stays a gap, and nothing renumbers (D1). Deleting the newest take lets its number come
    /// back, which D1 accepts over a stored counter on every loop and exercise.
    static func next(after given: some Sequence<Int>) -> Int {
        (given.max() ?? 0) + 1
    }

    /// One take as the backfill sees it (D8): which count it belongs to, when it was recorded, the
    /// number it already has if any, and a tiebreak so two takes stamped in the same instant always
    /// come out in the same order.
    struct Entry<Group: Hashable> {
        let group: Group
        let recordedAt: Date
        let number: Int?
        let tiebreak: String
    }

    /// Numbers for every entry that has none, keyed by its index in `entries` (D8).
    ///
    /// Group by group, in the order the takes were recorded, starting above the highest number the
    /// group already has. An entry that has a number keeps it and is never in the result, so a second
    /// pass over the same takes returns nothing.
    static func backfill<Group: Hashable>(_ entries: [Entry<Group>]) -> [Int: Int] {
        var assigned: [Int: Int] = [:]
        let byGroup = Dictionary(grouping: entries.indices, by: { entries[$0].group })
        for indices in byGroup.values {
            var highest = indices.compactMap { entries[$0].number }.max() ?? 0
            let unnumbered = indices
                .filter { entries[$0].number == nil }
                .sorted { lhs, rhs in
                    (entries[lhs].recordedAt, entries[lhs].tiebreak) < (entries[rhs].recordedAt, entries[rhs].tiebreak)
                }
            for index in unnumbered {
                highest += 1
                assigned[index] = highest
            }
        }
        return assigned
    }
}
