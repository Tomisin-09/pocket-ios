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
    // The five remaining modes of the major scale (Ionian = `.major`, Aeolian = `.naturalMinor` are
    // already above). Each is the parent major scale started on a different degree, so it fits the same
    // CAGED box borrowed via `relativeMajorSemitones` — correct by construction, one line each.
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case locrian
    case blues
    // The two bebop scales — a mode plus one chromatic passing tone, threaded onto the box the way the
    // blues ♭5 is (see `passingToneAnchorDegree`). "Bebop Major" adds the ♯5; "Bebop Dominant" the ♮7.
    case bebopMajor
    case bebopDominant

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
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .locrian: return "Locrian"
        case .blues: return "Blues"
        case .bebopMajor: return "Bebop Major"
        case .bebopDominant: return "Bebop Dominant"
        }
    }

    /// Semitone offsets from the root over one octave — the scale's formula.
    var intervals: [Int] {
        switch self {
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor: return [0, 2, 3, 5, 7, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .bebopMajor: return [0, 2, 4, 5, 7, 8, 9, 11]      // major + ♯5 passing tone
        case .bebopDominant: return [0, 2, 4, 5, 7, 9, 10, 11]  // mixolydian + ♮7 passing tone
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
    /// A mode borrows the boxes of its **parent major** (the Ionian it shares notes with): Dorian is the
    /// 2nd degree so its parent sits a whole step below (+10 up), Phrygian the 3rd (+8), and so on. The
    /// bebop scales borrow the box of the mode they decorate (Bebop Major → the major itself; Bebop
    /// Dominant → its Mixolydian parent, +5); their extra passing tone is threaded in separately.
    var relativeMajorSemitones: Int {
        switch self {
        case .major, .majorPentatonic, .bebopMajor: return 0
        case .locrian: return 1
        case .minorPentatonic, .naturalMinor, .blues: return 3
        case .mixolydian, .bebopDominant: return 5
        case .lydian: return 7
        case .phrygian: return 8
        case .dorian: return 10
        }
    }

    /// Scales built as a diatonic CAGED box **plus one chromatic passing tone** name the scale degree
    /// (semitones above the tonic) whose box note the passing tone is threaded one fret above: the ♭5
    /// over the P4 (blues), the ♯5 over the P5 (bebop major), the ♮7 over the ♭7 (bebop dominant). Each
    /// anchor's next diatonic tone is a whole step up, so the passing note lands cleanly between them.
    /// `nil` for the purely diatonic scales, whose box needs no threading.
    var passingToneAnchorDegree: Int? {
        switch self {
        case .blues: return 5           // ♭5 a fret above the perfect fourth
        case .bebopMajor: return 7      // ♯5 a fret above the perfect fifth
        case .bebopDominant: return 10  // ♮7 a fret above the ♭7
        default: return nil
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
