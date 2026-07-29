import Foundation

/// A single tuner readout (ADR 0115): the nearest equal-tempered note to a detected frequency and how
/// far off it is, in cents. Pure — built from a frequency and a reference pitch, no audio.
///
/// Note names come from a `NoteSpelling`, so the tuner spells notes identically to the fretboard,
/// chord namer, and scale surfaces — the tuner never disagrees with the rest of the app. A tuner
/// reading has **no tonal centre** (a detected pitch is just a pitch), so it is one of the surfaces
/// the user's accidental preference decides outright (ADR 0123); the engine passes it in. MIDI note
/// numbers are the currency here as they are for `ToneEngine` / `ChordVoicing`.
struct TunerReading: Equatable {
    /// MIDI note number of the nearest note (e.g. 40 = E2, 69 = A4).
    let midiNote: Int
    /// Octave in scientific pitch notation (E2 → 2, A4 → 4).
    let octave: Int
    /// Deviation from the nearest note, −50…+50 cents. Negative = flat, positive = sharp.
    let cents: Double
    /// How this reading spells its note — the user's preference, since a detected pitch carries no
    /// key. Part of the value (and so of `Equatable`) so a changed preference re-renders the readout.
    let spelling: NoteSpelling

    /// Name of the nearest note in this reading's spelling ("E", "F♯" / "G♭", …).
    var noteName: String { spelling.name(pitchClass: ((midiNote % 12) + 12) % 12) }

    /// Within this many cents of the target reads as "in tune" (ADR 0115 §2).
    static let inTuneTolerance: Double = 5

    /// True when the pitch is close enough to the nearest note to read as in tune.
    var isInTune: Bool { abs(cents) <= Self.inTuneTolerance }

    /// Scientific-pitch label, e.g. "E2" or "F♯3".
    var pitchLabel: String { "\(noteName)\(octave)" }

    /// The nearest note + cents for `frequency`, using `referenceA` as the tunable A4 reference
    /// (432…446, default A440). Returns `nil` for a non-positive frequency or reference.
    ///
    /// The real-valued MIDI number is `69 + 12·log₂(f / A4)`; rounding it gives the nearest note and
    /// the fractional remainder (×100) gives the cents, which therefore always lands in −50…+50.
    static func nearest(toFrequency frequency: Double, referenceA: Double = 440,
                        spelling: NoteSpelling = .default) -> TunerReading? {
        guard frequency > 0, referenceA > 0 else { return nil }
        let exactMIDI = 69 + 12 * log2(frequency / referenceA)
        let midi = Int(exactMIDI.rounded())
        let cents = (exactMIDI - Double(midi)) * 100
        return TunerReading(midiNote: midi, octave: midi / 12 - 1, cents: cents, spelling: spelling)
    }
}
