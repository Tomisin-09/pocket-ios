import Foundation

/// How a pitch class is **spelled** as a note name — the app's single answer to "is that note F♯ or
/// G♭?" (ADR 0123). Pure and SwiftUI-free (M7); every surface that prints a note name resolves one of
/// these first and then asks it for the name.
///
/// The policy is **key-first**: wherever a tonal centre exists, the key decides, because a key is a
/// fact about the music and the user's preference is not — the fourth degree of F major is B♭ for
/// everyone. The stored preference (`AppSettings.accidentalPreference`) is only a **tiebreaker**, used
/// where there is genuinely nothing to spell against: the tuner, a custom chord, a rootless drill, a
/// bare root menu — plus the two places a key *is* known but leaves the question open (see
/// `forKey(root:relativeMajorSemitones:preference:)`). It is deliberately **not** a global override.
enum NoteSpelling: String, CaseIterable, Identifiable {
    case sharps
    case flats

    var id: String { rawValue }

    /// The default when nothing is stored — the sharp fretboard the app shipped with.
    static let `default` = NoteSpelling.sharps

    /// Settings label, glyph included so the choice is legible without reading the note names.
    var label: String {
        switch self {
        case .sharps: return "Sharps (♯)"
        case .flats: return "Flats (♭)"
        }
    }

    private static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    /// The name of a pitch class in this spelling — "D♯" or "E♭" for pitch class 3. Uses the
    /// typographic ♯ / ♭ glyphs (the app already spells its degree labels "♭3"), never ASCII `#`.
    func name(pitchClass: Int) -> String {
        let index = (((pitchClass % 12) + 12) % 12)
        return self == .flats ? Self.flatNames[index] : Self.sharpNames[index]
    }
}

// MARK: - Resolving a spelling from a tonal centre (pure, unit-tested)

extension NoteSpelling {
    /// Pitch classes whose **major key** is written with flats — D♭ · E♭ · F · A♭ · B♭. The rest of the
    /// circle of fifths (C · G · D · A · E · B) is written with sharps or nothing at all; F♯/G♭ is the
    /// six-and-six tie at the bottom of the circle and is listed in neither.
    private static let flatMajorKeys: Set<Int> = [1, 3, 5, 8, 10]
    /// The tie at the bottom of the circle — F♯ major (6 sharps) and G♭ major (6 flats) are equally
    /// standard, so nothing about the key decides it.
    private static let tieMajorKey = 6
    /// The key with no accidentals at all — C major / A minor. Nothing in the signature says how to
    /// spell a chromatic note against it.
    private static let naturalMajorKey = 0

    /// What a **tonal centre** demands, or `nil` where the key declines to answer. Takes a root pitch
    /// class plus the semitones from that root up to the parent major whose key signature governs it
    /// (`GuitarScale.relativeMajorSemitones` / `ArpeggioQuality.relativeMajorSemitones` — 0 for a major
    /// key, 3 for a minor one).
    ///
    /// The parent major's position on the circle of fifths decides: a flat key spells flats, a sharp key
    /// spells sharps. Two positions are genuinely undecided — **C** (no accidentals to follow at all)
    /// and **F♯/G♭** (six of each) — and return `nil`, which is what lets a key context and *no* key
    /// context share one fallback: the preference. `nil` is "nothing here decides", never "sharps".
    static func keySpelling(root: Int, relativeMajorSemitones: Int = 0) -> NoteSpelling? {
        let parentMajor = (((root + relativeMajorSemitones) % 12) + 12) % 12
        guard parentMajor != tieMajorKey, parentMajor != naturalMajorKey else { return nil }
        return flatMajorKeys.contains(parentMajor) ? .flats : .sharps
    }

    /// `keySpelling` with the preference applied to the undecided cases — the everyday resolver.
    static func forKey(root: Int, relativeMajorSemitones: Int = 0,
                       preference: NoteSpelling = .default) -> NoteSpelling {
        keySpelling(root: root, relativeMajorSemitones: relativeMajorSemitones) ?? preference
    }

    /// What a `GuitarScale` rooted at a pitch class demands, or `nil` where it doesn't decide. A scale
    /// run *is* a tonal centre, so its own key answers for it (B♭ minor pentatonic reads "B♭", never
    /// "A♯"). Modes resolve through their parent major, which is what `relativeMajorSemitones` already
    /// encodes for the CAGED boxes.
    static func forScale(_ scale: GuitarScale, root: Int) -> NoteSpelling? {
        keySpelling(root: root, relativeMajorSemitones: scale.relativeMajorSemitones)
    }

    /// What an arpeggio quality rooted at a pitch class demands — same rule, through the major the
    /// chord belongs to (a dominant 7 borrows the key a fourth up, where it is the V7).
    static func forArpeggio(_ quality: ArpeggioQuality, root: Int) -> NoteSpelling? {
        keySpelling(root: root, relativeMajorSemitones: quality.relativeMajorSemitones)
    }

    /// What a song's key demands; `nil` for `.unknown` (no tonal centre) as well as for the two
    /// undecided positions — either way the caller falls back to the preference.
    static func forMusicalKey(_ key: MusicalKey) -> NoteSpelling? {
        guard let root = key.pitchClass, let quality = key.quality else { return nil }
        return keySpelling(root: root, relativeMajorSemitones: quality == .minor ? 3 : 0)
    }
}
