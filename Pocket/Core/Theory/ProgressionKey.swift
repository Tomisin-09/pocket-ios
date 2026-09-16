import Foundation

/// The key a progression is **placed in** (ADR 0218 D3) — a tonic, and whether the progression reads as
/// minor. Only two things depend on it: which pitches the steps land on, and how their roots are spelled.
///
/// Spelling goes one step past ADR 0123. That ADR decides *sharps or flats* from the key signature, which
/// is enough wherever a note has no degree. A progression's roots do have degrees, so here the **letter**
/// comes from the degree and only the accidental from the pitch: ♭VII in C is B♭ whatever the preference,
/// because the seventh letter above C is B. Reading it off a sharps list would print A♯ — a spelling no
/// chart uses. The key's own tonic still follows 0123 (`NoteSpelling.forKey`), preference included for
/// the two positions a signature leaves open.
struct ProgressionKey: Equatable, Sendable {
    /// The tonic's pitch class, 0 = C … 11 = B.
    var tonic: Int
    /// Labels and spells the key as minor ("Am") — see `[ProgressionStep].readsAsMinor`.
    var isMinor: Bool

    init(tonic: Int, isMinor: Bool = false) {
        self.tonic = ((tonic % 12) + 12) % 12
        self.isMinor = isMinor
    }

    /// Natural pitch class of each letter, C D E F G A B.
    private static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    private static let naturals = [0, 2, 4, 5, 7, 9, 11]

    /// How the key signature spells the tonic — ADR 0123's resolver, with the relative major for a minor key.
    func tonicSpelling(preference: NoteSpelling = .default) -> NoteSpelling {
        NoteSpelling.forKey(root: tonic, relativeMajorSemitones: isMinor ? 3 : 0, preference: preference)
    }

    /// The tonic's name — "B♭", "F♯".
    func tonicName(preference: NoteSpelling = .default) -> String {
        tonicSpelling(preference: preference).name(pitchClass: tonic)
    }

    /// The key as a chip reads it — "B♭", or "B♭m" for a minor-reading progression.
    func label(preference: NoteSpelling = .default) -> String {
        tonicName(preference: preference) + (isMinor ? "m" : "")
    }

    /// The pitch class a step lands on in this key.
    func rootPitchClass(of step: ProgressionStep) -> Int { (tonic + step.semitones) % 12 }

    /// The name of a step's root in this key — letter from the degree, accidental from the pitch.
    ///
    /// Falls back to the key's sharps-or-flats reading when the degree's letter would need a **double**
    /// accidental (E𝄫 for ♭VI in G♭): technically the degree's spelling, but not a name a player reading a
    /// chord chart should meet.
    func rootName(of step: ProgressionStep, preference: NoteSpelling = .default) -> String {
        let spelling = tonicSpelling(preference: preference)
        let pitch = rootPitchClass(of: step)
        guard let tonicLetter = Self.letterIndex(of: spelling.name(pitchClass: tonic)) else {
            return spelling.name(pitchClass: pitch)
        }
        let letter = (tonicLetter + step.letterStep) % 7
        var accidental = ((pitch - Self.naturals[letter]) % 12 + 12) % 12
        if accidental > 6 { accidental -= 12 }
        switch accidental {
        case 0: return Self.letters[letter]
        case 1: return Self.letters[letter] + "♯"
        case -1: return Self.letters[letter] + "♭"
        default: return spelling.name(pitchClass: pitch)
        }
    }

    /// The chord a step names in this key — "B♭", "F♯m7", "G7".
    func chordName(of step: ProgressionStep, preference: NoteSpelling = .default) -> String {
        rootName(of: step, preference: preference) + step.quality.nameSuffix
    }

    /// The letter index (0 = C … 6 = B) a note name is written on, or `nil` for text that isn't one.
    private static func letterIndex(of name: String) -> Int? {
        guard let first = name.first else { return nil }
        return letters.firstIndex(of: String(first))
    }
}
