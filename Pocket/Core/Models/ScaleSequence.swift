import Foundation

/// **How a scale run is sequenced** — the orthogonal "pattern" axis over any generated `ScaleRun`
/// (ADR 0108). Straight is one-note-per-step up the scale (today's behaviour); the others reorder the
/// *same* ascending notes into the classic practice patterns — melodic intervals (thirds, fourths) and
/// rolling groups (threes, fours). It's a **pure permutation of the generated note list**: it never
/// changes *which* notes the box/layout produced, only the order they're played, so it composes with
/// every scale, root, position and layout and can't fight the box generator or its span tests.
///
/// String-backed on the payload (`ScaleRun.sequenceRaw`, the ADR 0036 rule) and decode-defaulting to
/// `.straight`, so every scale authored before this axis existed plays exactly as it did.
enum SequencePattern: String, CaseIterable, Identifiable, Codable {
    /// One note per step, straight up (and back) the scale — the default.
    case straight
    /// Melodic **thirds**: each note paired with the scale tone two steps above — 1 3 2 4 3 5 …
    case thirds
    /// Melodic **fourths**: each note paired with the scale tone three steps above — 1 4 2 5 3 6 …
    case fourths
    /// Rolling **groups of three**: 1 2 3, 2 3 4, 3 4 5 …
    case groupsOfThree
    /// Rolling **groups of four**: 1 2 3 4, 2 3 4 5 …
    case groupsOfFour

    var id: String { rawValue }

    /// Forgiving decode — an unrecognised stored pattern falls back to straight (mirrors the
    /// scale/layout fallbacks, ADR 0036).
    init(storage raw: String) { self = SequencePattern(rawValue: raw) ?? .straight }

    var displayName: String {
        switch self {
        case .straight: return "Straight"
        case .thirds: return "In 3rds"
        case .fourths: return "In 4ths"
        case .groupsOfThree: return "Groups of 3"
        case .groupsOfFour: return "Groups of 4"
        }
    }

    /// The reordered index list for a run of `count` ascending notes — the permutation this pattern
    /// applies. Every original index appears at least once (the pattern always emits `i` itself), so no
    /// note is dropped; a pattern's partner index is emitted only when it stays in range, so the run
    /// never runs off the top of the scale. Pure and total.
    func indices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        switch self {
        case .straight: return Array(0..<count)
        case .thirds: return byInterval(step: 2, count: count)
        case .fourths: return byInterval(step: 3, count: count)
        case .groupsOfThree: return byGroup(size: 3, count: count)
        case .groupsOfFour: return byGroup(size: 4, count: count)
        }
    }

    /// Each note paired with the one `step` scale-tones above it, when that partner is in range.
    private func byInterval(step: Int, count: Int) -> [Int] {
        (0..<count).flatMap { index in
            index + step < count ? [index, index + step] : [index]
        }
    }

    /// A rolling window of `size` consecutive notes starting on each note, clamped to the top.
    private func byGroup(size: Int, count: Int) -> [Int] {
        (0..<count).flatMap { index in
            (0..<size).map { index + $0 }.filter { $0 < count }
        }
    }

    /// Reorder an ascending run — its `notes` and an optional index-aligned `groups` array (ADR 0083
    /// S2b box focus) — into this pattern, keeping the two aligned. Generic so it serves any element
    /// type; `ScaleRun` passes `FretNote`.
    func apply<Element>(to notes: [Element], groups: [Int]?) -> (notes: [Element], groups: [Int]?) {
        guard self != .straight else { return (notes, groups) }
        let order = indices(count: notes.count)
        return (order.map { notes[$0] }, groups.map { source in order.map { source[$0] } })
    }
}
