import Foundation

/// The three adjacent strings a triad is played on (ADR 0109, ADR 0313). The upper three sets only: the
/// lower ones, D‑A‑E and E‑A‑D, stay out of scope as in 0109.
///
/// The raw values are what a saved Triads run stores, so they never change.
enum TriadStrings: String, CaseIterable, Identifiable, Sendable {
    case gbe, dgb, adg

    var id: String { rawValue }

    /// The strings, **low to high**, as indices into the board's high-e-first order (0 = high e … 5 = low E).
    var strings: [Int] {
        switch self {
        case .gbe: return [2, 1, 0]
        case .dgb: return [3, 2, 1]
        case .adg: return [4, 3, 2]
        }
    }

    /// "G-B-e" — the same name `ChordGrip.triads` gives the set, so the picker and the exercise agree.
    var label: String {
        switch self {
        case .gbe: return "G-B-e"
        case .dgb: return "D-G-B"
        case .adg: return "A-D-G"
        }
    }
}

/// One close-voiced triad on three adjacent strings (ADR 0313 D3): a chord tone on each string, each the
/// next tone up from the one below, so the three sit inside one octave.
struct TriadShape: Equatable, Hashable, Sendable {
    /// The strings, low to high (`TriadStrings.strings`).
    let strings: [Int]
    /// The fret on each string, low to high.
    let frets: [Int]
    /// The MIDI pitch on each string, low to high.
    let pitches: [Int]
    /// Which chord tone sounds on each string, low to high, as an index into the chord's intervals: 0 the
    /// root, 1 the third (or the 2 or 4 of a sus chord), 2 the fifth.
    let tones: [Int]

    /// The tone in the bass: 0 root position, 1 first inversion, 2 second.
    var inversion: Int { tones.first ?? 0 }

    var lowestFret: Int { frets.min() ?? 0 }
    var highestFret: Int { frets.max() ?? 0 }

    /// The three notes, low string to high — the order Broken plays them in (D7).
    var notes: [FretNote] { zip(strings, frets).map { FretNote(string: $0, fret: $1) } }

    /// Whether every fret of the shape sits between the range's two frets, both included.
    func fits(in range: ClosedRange<Int>) -> Bool { frets.allSatisfy(range.contains) }

    /// How far the fingers move from `other`: the sum of the three strings' fret distances (D3).
    func moveCost(from other: TriadShape) -> Int {
        zip(frets, other.frets).reduce(0) { $0 + abs($1.0 - $1.1) }
    }
}

/// **Finds the shapes** of a three-note chord on a string set (ADR 0313 D3). Pure and Foundation-only
/// (AGENTS.md), unit-tested in `TriadShapesTests`.
///
/// It works from intervals rather than placing `ChordGrip.triads`, because sus2 and sus4 play as written
/// (D5) and have no triad grips. A test holds the two together: every triad grip at every root is one of
/// the shapes this finds, so the picker and the exercise can't disagree about what a shape is.
enum TriadShapes {
    /// The highest fret a shape may use. A real neck reaches 21 to 24; 22 is the mockup's, and the
    /// 5-fret table in ADR 0313 was counted with it.
    static let maxFret = 22

    /// Guitar standard tuning, highest-first, as the board's strings are numbered.
    private static let openMidi = FretboardDrill.guitarOpenMidi

    /// Every close voicing of the chord on `strings` with no fret above `maxFret`, **lowest first**: by its
    /// lowest fret, then by its bass note.
    ///
    /// - Parameters:
    ///   - root: the chord's root pitch class, 0 = C … 11 = B.
    ///   - intervals: the three chord tones as semitones above the root, root first: `[0, 4, 7]` for major.
    static func all(root: Int, intervals: [Int], on strings: TriadStrings,
                    maxFret: Int = TriadShapes.maxFret) -> [TriadShape] {
        guard intervals.count == 3 else { return [] }
        let set = strings.strings
        let toneClasses = intervals.map { pitchClass(root + $0) }
        var shapes: [TriadShape] = []
        for inversion in 0..<3 {
            let order = [inversion, (inversion + 1) % 3, (inversion + 2) % 3]
            for fret in 0...max(0, maxFret) {
                let bass = openMidi[set[0]] + fret
                guard pitchClass(bass) == toneClasses[order[0]] else { continue }
                let middle = nextPitch(above: bass, pitchClass: toneClasses[order[1]])
                let top = nextPitch(above: middle, pitchClass: toneClasses[order[2]])
                let pitches = [bass, middle, top]
                let frets = zip(set, pitches).map { $1 - openMidi[$0] }
                guard frets.allSatisfy({ (0...maxFret).contains($0) }) else { continue }
                shapes.append(TriadShape(strings: set, frets: frets, pitches: pitches, tones: order))
            }
        }
        return shapes.sorted { ($0.lowestFret, $0.pitches[0]) < ($1.lowestFret, $1.pitches[0]) }
    }

    /// The shapes that fit between two frets, lowest first.
    static func fitting(root: Int, intervals: [Int], on strings: TriadStrings,
                        in range: ClosedRange<Int>) -> [TriadShape] {
        all(root: root, intervals: intervals, on: strings).filter { $0.fits(in: range) }
    }

    /// The shape that moves the fingers least from `previous` (D3). A tie goes to the lower shape, and with
    /// no chord before, the lowest shape wins. `nil` only when there are no candidates.
    static func nearest(to previous: TriadShape?, among candidates: [TriadShape]) -> TriadShape? {
        guard let previous else { return candidates.first }
        // `min(by:)` keeps the first of equals, and the candidates are lowest first.
        return candidates.min { $0.moveCost(from: previous) < $1.moveCost(from: previous) }
    }

    private static func pitchClass(_ value: Int) -> Int { ((value % 12) + 12) % 12 }

    /// The lowest pitch above `pitch` with the given pitch class.
    private static func nextPitch(above pitch: Int, pitchClass target: Int) -> Int {
        let step = pitchClass(target - pitch)
        return pitch + (step == 0 ? 12 : step)
    }
}

// MARK: - What a progression's chord plays as (ADR 0313 D5)

extension ChordGrip.Quality {
    /// The triad this quality plays as (D5). A 7th, maj7, 6th or 9th plays its major or minor triad; sus2
    /// and sus4 have three notes, so they play as written, as do diminished and augmented. A power chord
    /// has no third, so it has no triad: `nil`.
    var triadQuality: ChordGrip.Quality? {
        switch self {
        case .major, .dom7, .maj7, .sixth, .dom9, .maj9: return .major
        case .minor, .min7, .min9: return .minor
        case .diminished: return .diminished
        case .augmented: return .augmented
        case .sus2: return .sus2
        case .sus4: return .sus4
        case .fifth: return nil
        }
    }

    /// The triad's three tones as semitones above the root, or `nil` for a power chord.
    var triadIntervals: [Int]? {
        switch triadQuality {
        case .major?: return [0, 4, 7]
        case .minor?: return [0, 3, 7]
        case .diminished?: return [0, 3, 6]
        case .augmented?: return [0, 4, 8]
        case .sus2?: return [0, 2, 7]
        case .sus4?: return [0, 5, 7]
        case .dom7?, .min7?, .maj7?, .fifth?, .sixth?, .dom9?, .maj9?, .min9?, nil: return nil
        }
    }
}
