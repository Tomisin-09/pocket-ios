import Foundation

/// A **chord quality** — a display suffix plus the normalised set of semitone intervals it spells above
/// its root (root = 0). The reverse-lookup engine matches a voicing's interval set against this table.
/// The `rarity` orders how common a quality is (0 = most common) so equally-valid readings of the same
/// notes rank sensibly (a bare `{0,4,7}` is "C", not an exotic re-spelling). Pure and SwiftUI-free (ADR
/// 0093 N1) so it lives in `Core/Theory/` and is exhaustively unit-testable.
struct ChordQuality: Equatable {
    /// The suffix appended to the root name — `""` for a major triad, `"m"`, `"maj7"`, `"dim7"`, …
    let suffix: String
    /// Semitone intervals above the root, root included (0). E.g. a dominant 7th is `[0, 4, 7, 10]`.
    let intervals: Set<Int>
    /// Commonness rank, 0 = most common. Tiebreaks equally-valid readings toward the familiar name.
    let rarity: Int

    /// The common-practice vocabulary (ADR 0093 N3) — everything the curated grips (ADR 0084 tiers 1–2)
    /// and the custom placer can idiomatically produce. Ordered by `rarity`. The 9ths (ADR 0101) are
    /// listed in both their full 5-note form and the drop-5 4-note form guitar actually voices, so a
    /// slid 9th grip names correctly in the preview. Higher extensions (11/13, altered dominants) remain
    /// out of scope for v1; this table extends additively.
    static let catalog: [ChordQuality] = [
        ChordQuality(suffix: "", intervals: [0, 4, 7], rarity: 0), // major triad
        ChordQuality(suffix: "m", intervals: [0, 3, 7], rarity: 1), // minor triad
        ChordQuality(suffix: "7", intervals: [0, 4, 7, 10], rarity: 2), // dominant 7th
        ChordQuality(suffix: "m7", intervals: [0, 3, 7, 10], rarity: 3), // minor 7th
        ChordQuality(suffix: "maj7", intervals: [0, 4, 7, 11], rarity: 4), // major 7th
        ChordQuality(suffix: "sus4", intervals: [0, 5, 7], rarity: 5), // suspended 4th
        ChordQuality(suffix: "sus2", intervals: [0, 2, 7], rarity: 6), // suspended 2nd
        ChordQuality(suffix: "6", intervals: [0, 4, 7, 9], rarity: 7), // major 6th
        ChordQuality(suffix: "m6", intervals: [0, 3, 7, 9], rarity: 8), // minor 6th
        ChordQuality(suffix: "add9", intervals: [0, 2, 4, 7], rarity: 9), // add9
        ChordQuality(suffix: "madd9", intervals: [0, 2, 3, 7], rarity: 10), // minor add9
        ChordQuality(suffix: "dim", intervals: [0, 3, 6], rarity: 11), // diminished triad
        ChordQuality(suffix: "aug", intervals: [0, 4, 8], rarity: 12), // augmented triad
        ChordQuality(suffix: "m7♭5", intervals: [0, 3, 6, 10], rarity: 13), // half-diminished
        ChordQuality(suffix: "dim7", intervals: [0, 3, 6, 9], rarity: 14), // diminished 7th
        ChordQuality(suffix: "mMaj7", intervals: [0, 3, 7, 11], rarity: 15), // minor-major 7th
        ChordQuality(suffix: "6/9", intervals: [0, 2, 4, 7, 9], rarity: 16), // 6/9
        // The 9ths (ADR 0101) — full 5-note forms first, then the drop-5 4-note forms guitar voices.
        ChordQuality(suffix: "9", intervals: [0, 4, 7, 10, 2], rarity: 17), // dominant 9th
        ChordQuality(suffix: "m9", intervals: [0, 3, 7, 10, 2], rarity: 18), // minor 9th
        ChordQuality(suffix: "maj9", intervals: [0, 4, 7, 11, 2], rarity: 19), // major 9th
        ChordQuality(suffix: "9", intervals: [0, 4, 10, 2], rarity: 20), // dominant 9th, no 5th
        ChordQuality(suffix: "m9", intervals: [0, 3, 10, 2], rarity: 21), // minor 9th, no 5th
        ChordQuality(suffix: "maj9", intervals: [0, 4, 11, 2], rarity: 22), // major 9th, no 5th
        // The power chord (ADR 0106) — just root + 5th, no 3rd. A two-note quality, so it can only ever
        // match a bare dyad (a three-note set has three intervals and never equals `[0, 7]`). Ranked last
        // so it never shadows a fuller reading. (ADR 0093 amend: a root-and-5th is a named chord, "X5".)
        ChordQuality(suffix: "5", intervals: [0, 7], rarity: 23) // power chord
    ]
}

/// One reverse-lookup reading of a set of notes — a root, the quality it spells, and the actual bass
/// pitch class (which may differ from the root, i.e. an inversion). Names are rendered from these fields
/// so the caller can show the root-position name, the slash-bass name, or both (ADR 0093 N5). Sharp-
/// spelled with no key assumed (N6), sharing `GuitarScale.noteName` so it agrees with the board.
struct ChordCandidate: Equatable, Identifiable {
    let rootPitchClass: Int
    let quality: ChordQuality
    /// The lowest sounding pitch class, when known. `nil` when the engine was given a bare pitch-class
    /// set with no bass information — then no inversion can be detected.
    let bassPitchClass: Int?

    /// A candidate is uniquely identified by its root + quality (one reading of the notes).
    var id: String { "\(rootPitchClass)-\(quality.suffix)" }

    /// The root-position name — root note + quality suffix, e.g. `"C"`, `"Am7"`, `"Fdim7"`.
    var name: String {
        GuitarScale.noteName(forPitchClass: rootPitchClass) + quality.suffix
    }

    /// True when the bass note is known and is **not** the root — the notes are an inversion.
    var isInversion: Bool {
        guard let bass = bassPitchClass else { return false }
        return bass != rootPitchClass
    }

    /// Which chord tone sits in the bass: `0` root position, `1` first inversion (3rd in bass), `2`
    /// second (5th), `3` third (7th) — the bass note's index among the quality's stacked intervals.
    var inversion: Int {
        guard let bass = bassPitchClass else { return 0 }
        let bassInterval = (((bass - rootPitchClass) % 12) + 12) % 12
        return quality.intervals.sorted().firstIndex(of: bassInterval) ?? 0
    }

    /// A short tag for the identifier ("1st inv" … "3rd inv"), or `nil` in root position.
    var inversionLabel: String? {
        switch inversion {
        case 1: return "1st inv"
        case 2: return "2nd inv"
        case 3: return "3rd inv"
        default: return nil
        }
    }

    /// The name a player would see for *this voicing*: the slash-bass form for an inversion
    /// (`"C/E"`), otherwise the plain root-position name. This is what the identifier surfaces, because
    /// the bass note is what the player actually fingered.
    var displayName: String {
        guard isInversion, let bass = bassPitchClass else { return name }
        return name + "/" + GuitarScale.noteName(forPitchClass: bass)
    }
}

/// The **chord-naming engine** (ADR 0093) — reverse lookup from sounded notes to ranked chord names. Pure
/// and deterministic: it takes a pitch-class set (+ optional bass), never a key (ADR 0086 — chord
/// surfaces are keyless), and never a `ChordVoicing` directly at its core, so an interval reader, an
/// ear-training tool, or audio analysis can all reuse it. It is factual, not a judgement of playing:
/// naming a shape the player chose to build assesses no performance (ADR 0070 N7).
enum ChordNamer {

    /// Candidate readings of a pitch-class set, **best first** (ADR 0093 N4 ranking). An empty result
    /// means the notes don't spell any common-practice chord — the honest "No common name" case.
    ///
    /// - Parameters:
    ///   - pitchClasses: the distinct sounded pitch classes (0…11). Octave doublings collapse here.
    ///   - bassPitchClass: the lowest sounding pitch class, if known — enables root-position preference
    ///     and inversion (slash) naming. `nil` ranks purely by commonness.
    static func candidates(pitchClasses: Set<Int>, bassPitchClass: Int? = nil) -> [ChordCandidate] {
        let notes = Set(pitchClasses.map { normalise($0) })
        // Three notes name any chord in the catalog; two notes name only the **power chord** (root + 5th,
        // ADR 0106) — every other dyad is a bare interval, not a chord. The `[0, 7]` quality below matches
        // exactly the two-note case, so allowing two notes through can't over-name anything else.
        guard notes.count >= 2 else { return [] }

        let bass = bassPitchClass.map(normalise)
        var found: [ChordCandidate] = []

        // Try every sounded pitch class as a candidate root; exact interval-set match only (N4 —
        // extra non-chord tones disqualify the pair; honest over clever for v1).
        for root in notes {
            let intervals = Set(notes.map { normalise($0 - root) })
            for quality in ChordQuality.catalog where quality.intervals == intervals {
                found.append(ChordCandidate(rootPitchClass: root, quality: quality, bassPitchClass: bass))
            }
        }

        return found.sorted { isBetter($0, than: $1) }
    }

    /// Convenience adapter for a `ChordVoicing` (ADR 0093 N2) — feeds the core the voicing's pitch classes
    /// and the pitch class of its lowest-sounding string as the bass, so inversions are detected.
    static func candidates(for voicing: ChordVoicing) -> [ChordCandidate] {
        let bass = voicing.midiNotes.min().map { normalise($0) }
        return candidates(pitchClasses: voicing.pitchClasses, bassPitchClass: bass)
    }

    /// The single best chord name for a voicing, or `nil` if it spells no common chord ("No common name").
    static func bestName(for voicing: ChordVoicing) -> String? {
        candidates(for: voicing).first?.displayName
    }

    // MARK: - Ranking

    /// Best-first ordering (ADR 0093 N4): root-position (root == bass) beats an inversion; then a more
    /// common quality; then the plain root-position note order — fully deterministic.
    private static func isBetter(_ lhs: ChordCandidate, than rhs: ChordCandidate) -> Bool {
        if lhs.isInversion != rhs.isInversion { return !lhs.isInversion }   // root position first
        if lhs.quality.rarity != rhs.quality.rarity { return lhs.quality.rarity < rhs.quality.rarity }
        return lhs.rootPitchClass < rhs.rootPitchClass
    }

    /// Fold any integer into 0…11.
    private static func normalise(_ value: Int) -> Int { ((value % 12) + 12) % 12 }
}
