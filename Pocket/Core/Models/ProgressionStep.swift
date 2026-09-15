import Foundation

/// One chord of a progression **written in a key** rather than as a shape (ADR 0218 D2) — "the V chord,
/// held one bar". A step stores where the chord sits above the tonic and what quality it is; the shape is
/// chosen only when the progression is placed in a key (`ProgressionResolver`). That is what makes moving a
/// progression to another key exact: nothing about the shape is stored, so there is nothing to re-fit.
///
/// The quality **is** the movable-grip vocabulary (`ChordGrip.Quality`), on purpose: every quality there
/// has at least one curated grip, so every step can be fretted at every root. A step can't name a chord
/// the neck has no shape for (D5).
///
/// Persisted only inside a blob (`SavedProgression.stepsData`), never as a `@Model` attribute, so the
/// enum here carries none of the SwiftData enum-attribute risk (`docs/swiftdata-gotchas.md`).
struct ProgressionStep: Equatable, Sendable {
    /// Semitones above the tonic, 0–11. Normalised on the way in, so a step can't sit outside the octave.
    var semitones: Int
    /// The chord's quality.
    var quality: ChordGrip.Quality
    /// How many bars the chord is held for, at least 1. An insert's hold setting scales it (`ProgressionHold`).
    var bars: Int

    init(_ semitones: Int, _ quality: ChordGrip.Quality = .major, bars: Int = 1) {
        self.semitones = ((semitones % 12) + 12) % 12
        self.quality = quality
        self.bars = max(1, bars)
    }

    /// The step a chord rooted at `rootPitchClass` is, in a progression whose tonic is `tonic` — how the
    /// builder turns a tapped chord name into a step. Only the distance is kept, so a progression written
    /// against the "wrong" tonic still moves correctly; it just reads with different numerals.
    static func from(rootPitchClass: Int, tonic: Int, quality: ChordGrip.Quality, bars: Int = 1) -> ProgressionStep {
        ProgressionStep(rootPitchClass - tonic, quality, bars: bars)
    }
}

// MARK: - Codable (tolerant — a newer quality must not take the whole progression with it)

extension ProgressionStep: Codable {
    private enum CodingKeys: String, CodingKey { case semitones, quality, bars }

    /// A quality this build doesn't know reads as **major** rather than failing the decode: the step keeps
    /// its place and its length, so the progression still runs in time, and one chord reads plainer than
    /// it was written. Dropping the step, or the progression, would lose more. `bars` defaults to 1.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let semitones = try container.decode(Int.self, forKey: .semitones)
        let raw = try container.decodeIfPresent(String.self, forKey: .quality) ?? ""
        let bars = try container.decodeIfPresent(Int.self, forKey: .bars) ?? 1
        self.init(semitones, ChordGrip.Quality(rawValue: raw) ?? .major, bars: bars)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(semitones, forKey: .semitones)
        try container.encode(quality.rawValue, forKey: .quality)
        try container.encode(bars, forKey: .bars)
    }
}

// MARK: - Reading a step (pure, unit-tested)

extension ProgressionStep {
    /// Which letter above the tonic's letter each semitone is spelled on — I ♭II II ♭III III IV ♭V V ♭VI VI
    /// ♭VII VII, the same reading `RomanNumeral` labels. Shared by the numeral and the note name, so the
    /// two can never disagree about which degree a chord is.
    static let letterSteps = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6]

    /// Letters above the tonic's letter this step's root is spelled on.
    var letterStep: Int { Self.letterSteps[semitones] }

    /// A minor-family chord — its numeral is lowercase.
    var isMinorFamily: Bool { quality == .minor || quality == .min7 || quality == .min9 }

    /// The Roman numeral, relative to the tonic's **major** scale with accidentals for borrowed chords —
    /// "vi", "♭VII", "V7", "ii7". One reading for major- and minor-sounding progressions alike, which is the
    /// convention players use for borrowed chords, and it means a step's numeral never depends on a mode.
    var numeral: String {
        RomanNumeral.label(rootPitchClass: semitones, keyRoot: 0, keyIsMinor: false,
                           isMinorChord: isMinorFamily, isDiminished: false) + numeralSuffix
    }

    /// What follows the numeral. A minor chord's case already says "minor", so "m" is never repeated:
    /// ii7, not iim7.
    private var numeralSuffix: String {
        switch quality {
        case .major, .minor: return ""
        case .dom7, .min7: return "7"
        case .maj7: return "maj7"
        case .fifth: return "5"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .sixth: return "6"
        case .dom9, .min9: return "9"
        case .maj9: return "maj9"
        }
    }
}

extension Array where Element == ProgressionStep {
    /// The numerals, as a progression is spoken — "I – V – vi – IV".
    var numerals: String { map(\.numeral).joined(separator: " – ") }

    /// Whether the progression **reads as minor**: it starts on a minor tonic chord. Decides only how the
    /// key is labelled and spelled ("Am", not "A") — the steps sound identical either way.
    var readsAsMinor: Bool {
        guard let first else { return false }
        return first.semitones == 0 && first.isMinorFamily
    }
}
