import Foundation

/// A **scale as a pitch-class formula** — a pure reference used to *ghost* a scale's notes on the
/// custom-scale canvas (`FretboardDrillEditor`'s guide overlay), so a player can trace and tap a scale
/// they want to drill rather than hand-recall every note. Deliberately **not** a `GuitarScale`: it
/// carries only a name + interval formula (→ pitch classes), never a CAGED box, so it can express the
/// *symmetric* scales the box generator can't (whole-tone, diminished — they aren't subsets of a major
/// scale) without touching the generative scale engine at all.
///
/// SwiftUI/SwiftData-free so the catalog and its pitch-class math are unit-tested (the repo's
/// pure-logic rule). Informational only — a drawing aid, never a grade (ADR 0070).
struct ScaleReference: Identifiable, Equatable {
    /// Player-facing name, e.g. "Whole Tone", "Minor Pentatonic".
    let name: String
    /// Semitone offsets from the root over one octave — the scale's formula.
    let intervals: [Int]

    /// Stable identity for menus — names are unique across the catalog.
    var id: String { name }

    /// The pitch classes (0 = C … 11 = B) the scale sounds for a given root pitch class — the set the
    /// canvas ghosts.
    func pitchClasses(root: Int) -> Set<Int> {
        Set(intervals.map { (((root + $0) % 12) + 12) % 12 })
    }
}

extension ScaleReference {
    /// The **symmetric** scales that motivated the custom canvas — they repeat on a fixed interval and
    /// are not subsets of any single major scale, so the CAGED box generator can't place them, but as a
    /// pitch-class formula they ghost onto the board like any other scale. Whole-tone repeats every whole
    /// step; the two diminished modes every minor third (whole–half vs half–whole).
    static let symmetric: [ScaleReference] = [
        .init(name: "Whole Tone", intervals: [0, 2, 4, 6, 8, 10]),
        .init(name: "Diminished (whole–half)", intervals: [0, 2, 3, 5, 6, 8, 9, 11]),
        .init(name: "Diminished (half–whole)", intervals: [0, 1, 3, 4, 6, 7, 9, 10])
    ]

    /// The full **scale** guide catalog: every `GuitarScale` (reusing its own formula, so the two never
    /// drift) **plus** the symmetric scales the generator can't produce. The symmetric ones lead —
    /// they're the reason a player reaches for the canvas — then the familiar diatonic/pentatonic
    /// references. Ghosted on the Scales (and run-family) "draw your own" canvas.
    static let all: [ScaleReference] =
        symmetric + GuitarScale.allCases.map { ScaleReference(name: $0.displayName, intervals: $0.intervals) }

    /// The **arpeggio** guide catalog — the chord-tone shapes ghosted on the Arpeggios "draw your own"
    /// canvas (ADR 0107). An arpeggio is just a chord-tone formula (R 3 5, optionally a 7th), so it
    /// ghosts onto the board like any scale — letting a player trace the *chord tones* themselves rather
    /// than a parent scale. Reuses `ArpeggioQuality`'s own interval formula, so the two never drift.
    static let arpeggios: [ScaleReference] =
        ArpeggioQuality.allCases.map { ScaleReference(name: $0.displayName, intervals: $0.intervals) }
}
