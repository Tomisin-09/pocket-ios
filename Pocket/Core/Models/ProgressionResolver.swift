import Foundation

/// Places **steps in a key** onto the neck (ADR 0218 D4) — for each step, the shape a player would reach
/// for. Pure and SwiftUI-free; the progression sheet only draws what this returns.
///
/// The order is fixed, and it is the whole policy:
///
/// 1. **One of the player's saved chords**, when they asked for that and one fits (D6).
/// 2. **An open shape** from `ChordVoicing.library` — in G, the G chord is the open G, not a barre.
/// 3. **The lowest-sitting movable grip** of that quality (`ChordGrip.curated`).
///
/// On a bass drill the guitar shapes stand down (ADR 0164) and a `BassChordShape` states the chord.
///
/// Every quality has a curated grip, so step 3 always answers on guitar — the tests hold that for every
/// quality at every root, which is what lets the builder offer any chord in any key (D5).
enum ProgressionResolver {

    /// A step placed in a key: the voicing to insert, and whether it is one of the player's own.
    struct Resolved: Equatable {
        var voicing: ChordVoicing
        var isYours: Bool
    }

    /// The voicing for one step.
    ///
    /// - Parameters:
    ///   - myChords: saved voicings to prefer when one fits — pass `[]` when the switch is off. Only
    ///     shapes for this neck are considered.
    ///   - preference: the accidental preference, for the positions a key leaves undecided (ADR 0123).
    static func resolve(_ step: ProgressionStep, in key: ProgressionKey, instrument: Instrument,
                        myChords: [ChordVoicing] = [], preference: NoteSpelling = .default) -> Resolved {
        let root = key.rootPitchClass(of: step)
        let name = key.chordName(of: step, preference: preference)
        let isBass = instrument == .bass

        // A saved chord keeps its own name: the player called it that, and "Cadd9" says more than "C".
        if let mine = myChords.first(where: { $0.isBass == isBass && fits($0, root: root, quality: step.quality) }) {
            return Resolved(voicing: mine, isYours: true)
        }
        if isBass {
            return Resolved(voicing: renamed(bassVoicing(root: root, quality: step.quality), to: name), isYours: false)
        }
        if let open = ChordVoicing.library.first(where: { fits($0, root: root, quality: step.quality) }) {
            return Resolved(voicing: renamed(open, to: name), isYours: false)
        }
        return Resolved(voicing: renamed(gripVoicing(root: root, quality: step.quality), to: name), isYours: false)
    }

    // MARK: - Fitting a voicing to a step

    // What a quality is made of, as the three slots a fit checks. Three exhaustive switches rather than
    // one table, so a quality added to `ChordGrip.Quality` can't compile without saying what it is.

    /// The third — major (4), minor (3), or none for a chord that has no third to state.
    private static func third(of quality: ChordGrip.Quality) -> Int? {
        switch quality {
        case .major, .dom7, .maj7, .sixth, .dom9, .maj9: return 4
        case .minor, .min7, .min9: return 3
        case .fifth, .sus2, .sus4: return nil
        }
    }

    /// The seventh — flat (10), major (11), or none.
    private static func seventh(of quality: ChordGrip.Quality) -> Int? {
        switch quality {
        case .dom7, .min7, .dom9, .min9: return 10
        case .maj7, .maj9: return 11
        case .major, .minor, .fifth, .sus2, .sus4, .sixth: return nil
        }
    }

    /// The tones that make the quality what it is beyond its third and seventh.
    private static func defining(of quality: ChordGrip.Quality) -> Set<Int> {
        switch quality {
        case .fifth: return [7]
        case .sus2, .dom9, .maj9, .min9: return [2]
        case .sus4: return [5]
        case .sixth: return [9]
        case .major, .minor, .dom7, .min7, .maj7: return []
        }
    }

    /// Whether `voicing` **is** `quality` on `root`, for the purpose of standing in for it.
    ///
    /// Deliberately more forgiving than `ChordNamer`, which wants an exact note set: the root must be the
    /// lowest note, the third and the seventh must be exactly the quality's (a C7 is not a C, a Cmaj7 is
    /// not a C7), and its defining tones must sound — but the **fifth may be left out**, as guitar voicings
    /// routinely do (the open C7 has none), and a **9th or 6th may colour** anything except a power chord.
    /// So a saved Cadd9 can play the I chord (D6), and the open C7 counts as a C7.
    static func fits(_ voicing: ChordVoicing, root: Int, quality: ChordGrip.Quality) -> Bool {
        guard voicing.rootPitchClass == ((root % 12) + 12) % 12 else { return false }
        let intervals = Set(voicing.pitchClasses.map { (($0 - root) % 12 + 12) % 12 })
        let thirds: Set<Int> = Self.third(of: quality).map { [$0] } ?? []
        let sevenths: Set<Int> = Self.seventh(of: quality).map { [$0] } ?? []
        let definingTones = Self.defining(of: quality)

        guard intervals.intersection([3, 4]) == thirds,
              intervals.intersection([10, 11]) == sevenths,
              definingTones.isSubset(of: intervals) else { return false }

        var allowed: Set<Int> = [0, 7]
        allowed.formUnion(thirds)
        allowed.formUnion(sevenths)
        allowed.formUnion(definingTones)
        if quality != .fifth { allowed.formUnion([2, 9]) }
        return intervals.isSubset(of: allowed)
    }

    // MARK: - Shapes

    /// The curated grip of `quality` that sits **lowest** on the neck at `root` — the one a hand meets
    /// first. Ties go to the list's own order (E-shape before A-shape).
    private static func gripVoicing(root: Int, quality: ChordGrip.Quality) -> ChordVoicing {
        let placed = ChordGrip.curated
            .filter { $0.quality == quality }
            .map { $0.voicing(rootPitchClass: root) }
        let lowest = placed.enumerated().min { lhs, rhs in
            let left = (lhs.element.highestFret ?? 0, lhs.offset)
            let right = (rhs.element.highestFret ?? 0, rhs.offset)
            return left < right
        }
        // Unreachable while every quality has a curated grip — which the tests hold. A named, silent
        // shape is still a better failure than a missing chord: the row can be swapped.
        return lowest?.element ?? ChordVoicing("", frets: Array(repeating: nil, count: ChordVoicing.stringCount))
    }

    /// The bass shape that states a chord (ADR 0164): a tenth for a chord with a third (major or minor), the
    /// ♭7-and-tenth shell for a dominant, and the power dyad for a chord with no third to state. The first
    /// playable one wins, with the power dyad behind it — it fits at every root.
    private static func bassVoicing(root: Int, quality: ChordGrip.Quality) -> ChordVoicing {
        let preferred: BassChordShape
        switch quality {
        case .minor, .min7, .min9: preferred = .minorTenth
        case .dom7, .dom9: preferred = .seventhTenthShell
        case .major, .maj7, .maj9, .sixth: preferred = .majorTenth
        case .fifth, .sus2, .sus4: preferred = .fifth
        }
        return preferred.voicing(rootPitchClass: root)
            ?? BassChordShape.fifth.voicing(rootPitchClass: root)
            ?? ChordVoicing("", frets: Array(repeating: nil, count: ChordVoicing.bassStringCount))
    }

    /// The same shape under the chord's name in this key. A grip names itself from a keyless spelling
    /// and a library shape carries a fixed name, so both are renamed; fingering is kept.
    private static func renamed(_ voicing: ChordVoicing, to name: String) -> ChordVoicing {
        ChordVoicing(name, frets: voicing.frets, fingers: voicing.fingers)
    }
}
