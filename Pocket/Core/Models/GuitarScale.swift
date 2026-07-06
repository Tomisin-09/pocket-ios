import Foundation

/// A **guitar scale** in the first-party library (ADR 0065 build 2, Slice 2). A scale is defined by
/// its **interval formula** (semitones from the root) — the note content is *generated* onto the neck
/// by `ScaleRun`, not hand-drawn, so every scale is correct by construction and new scales cost one
/// line. Common-practice vocabulary authored in-house (T8).
///
/// String-backed on the payload (`ScaleRun.scaleRaw`, the ADR 0036 rule) with an unknown-value
/// fallback, so a blob naming a scale a newer build added still decodes and runs.
enum GuitarScale: String, CaseIterable, Identifiable, Codable {
    case minorPentatonic
    case majorPentatonic
    case major
    case naturalMinor
    case blues

    var id: String { rawValue }

    /// Forgiving decode — an unrecognised stored scale falls back to the minor pentatonic (the
    /// workhorse), mirroring the template/kind fallbacks.
    init(storage raw: String) { self = GuitarScale(rawValue: raw) ?? .minorPentatonic }

    var displayName: String {
        switch self {
        case .minorPentatonic: return "Minor Pentatonic"
        case .majorPentatonic: return "Major Pentatonic"
        case .major: return "Major"
        case .naturalMinor: return "Natural Minor"
        case .blues: return "Blues"
        }
    }

    /// Semitone offsets from the root over one octave — the scale's formula.
    var intervals: [Int] {
        switch self {
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        }
    }

    /// The pitch classes of the scale for a given root pitch class (0 = C … 11 = B).
    func pitchClasses(root: Int) -> Set<Int> {
        Set(intervals.map { (((root + $0) % 12) + 12) % 12 })
    }

    /// The scale's degrees as semitone offsets from its root — the set a CAGED box is filtered to.
    var degrees: Set<Int> { Set(intervals) }

    /// Semitones from this scale's tonic **up to its relative major** — the key whose CAGED boxes the
    /// scale borrows. Major-family scales already are their own major (0); the minor-family scales sit
    /// a minor third (3) below their relative major, so they reuse those boxes shifted up three frets.
    var relativeMajorSemitones: Int {
        switch self {
        case .major, .majorPentatonic: return 0
        case .minorPentatonic, .naturalMinor, .blues: return 3
        }
    }

    /// The number of **CAGED positions** the scale offers up the neck — always the five CAGED boxes.
    var positionCount: Int { CAGEDShape.allCases.count }

    // MARK: - Standard-tuning pitch helpers (pure)

    /// Open-string pitch classes by our string index (5 = low E … 0 = high e): E, A, D, G, B, e.
    private static let openPitchClass = [4, 11, 7, 2, 9, 4]

    /// The pitch class sounding at a string/fret in standard tuning.
    static func pitchClass(string: Int, fret: Int) -> Int {
        let open = openPitchClass.indices.contains(string) ? openPitchClass[string] : 4
        return (((open + fret) % 12) + 12) % 12
    }

    /// The name of a pitch class, sharp-spelled (the app's fretboard is sharp-spelled).
    static func noteName(forPitchClass pitchClass: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return names[(((pitchClass % 12) + 12) % 12)]
    }
}
