import Foundation

/// Pure, UI-free Italian tempo marking lookup (ADR 0043, slice 1).
///
/// The classical tempo words ("Andante", "Allegro", …) name BPM bands. The bounds
/// vary across sources, so this picks one contiguous, gap-free convention and commits
/// to it: every positive BPM maps to exactly one marking, with no overlaps. Kept
/// Foundation-only and unit-tested — cheap, charming, and exactly the kind of table
/// that rots silently if a boundary is fenced wrong (AGENTS.md).
///
/// Cases are ordered slow→fast; `allCases` is in that order, which the band table
/// below relies on.
enum TempoMarking: String, CaseIterable, Equatable {
    case larghissimo
    case grave
    case largo
    case larghetto
    case adagio
    case andante
    case moderato
    case allegro
    case vivace
    case presto
    case prestissimo

    /// The display name ("Andante"), capitalised.
    var name: String { rawValue.capitalized }

    /// Upper bound (exclusive) of each band, in BPM, ascending. `prestissimo` is the
    /// open-ended top and so carries no entry here — anything at or above the last
    /// bound falls through to it.
    private static let upperBounds: [(marking: TempoMarking, below: Double)] = [
        (.larghissimo, 20),
        (.grave, 40),
        (.largo, 60),
        (.larghetto, 66),
        (.adagio, 76),
        (.andante, 108),
        (.moderato, 120),
        (.allegro, 168),
        (.vivace, 176),
        (.presto, 200)
    ]

    /// The marking for a given BPM. A non-positive BPM clamps to the slowest band
    /// (`larghissimo`) rather than returning `nil` — the lookup always names a tempo so
    /// the UI never has a blank. The first band whose exclusive upper bound the BPM
    /// sits below wins; everything from the last bound up is `prestissimo`.
    static func marking(forBPM bpm: Double) -> TempoMarking {
        for band in upperBounds where bpm < band.below {
            return band.marking
        }
        return .prestissimo
    }
}
