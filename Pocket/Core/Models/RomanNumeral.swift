import Foundation

/// Pure **Roman-numeral analysis** for a chord relative to a key (ADR 0065): a chord's root, the key
/// root, and the key's mode give the scale-degree numeral; the chord's own quality sets the case
/// (major/dominant uppercase, minor/diminished lowercase, diminished gets a °). SwiftUI-free and
/// unit-tested — the badge on a chord diagram is just its output.
///
/// The tables are the natural spelling of each semitone above the tonic in a major vs a natural-minor
/// key; non-diatonic steps get an accidental. Deliberately simple — it labels the common diatonic and
/// borrowed chords players actually drill, not every enharmonic edge case.
enum RomanNumeral {
    private static let majorKey =
        ["I", "♭II", "II", "♭III", "III", "IV", "♭V", "V", "♭VI", "VI", "♭VII", "VII"]
    private static let minorKey =
        ["I", "♭II", "II", "III", "♯III", "IV", "♭V", "V", "VI", "♯VI", "VII", "♯VII"]

    /// The numeral for a chord rooted at `rootPitchClass` in the given key. Case follows the chord's
    /// quality: minor/diminished lowercase, everything else uppercase; a diminished chord adds a °.
    static func label(rootPitchClass: Int, keyRoot: Int, keyIsMinor: Bool,
                      isMinorChord: Bool, isDiminished: Bool) -> String {
        let degree = (((rootPitchClass - keyRoot) % 12) + 12) % 12
        let base = (keyIsMinor ? minorKey : majorKey)[degree]
        var text = (isMinorChord || isDiminished) ? base.lowercased() : base
        if isDiminished { text += "°" }
        return text
    }
}
