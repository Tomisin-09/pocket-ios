import Foundation

/// A single **chord voicing** (ADR 0065) — the shared geometry for a chord, a barre shape, or a
/// triad: one entry per string, high-e first (index 0) through low-E last (index 5), matching the
/// `openMidi` / `openPitchClass` convention the rest of the fretboard engine uses. Pure and
/// SwiftUI-free so it stays unit-testable and can be drawn by *either* a vertical chord diagram or
/// the horizontal fretboard board.
///
/// `frets[i]`: `nil` = the string is muted (×), `0` = played open (○), `n` = fretted at absolute
/// fret `n`. A **triad is just a voicing** whose sounded strings span three distinct pitch classes
/// — there is no separate type, which is exactly why CAGED-triads folds in here rather than living
/// as its own axis (backlog, 2026-07-06). Authored in-house (T8): generic common-practice shapes,
/// never anyone's protected expression.
struct ChordVoicing: Codable, Equatable, Identifiable {
    /// Player-facing name — "C", "Am", "G7", "F (barre)", "C triad". The create card and the live
    /// change view read it.
    var name: String
    /// One entry per string, index 0 = high e … 5 = low E. `nil` muted, `0` open, `n` fret n.
    var frets: [Int?]
    /// Optional fretting-hand finger per string (1–4; `nil` where open / muted / unspecified), same
    /// indexing as `frets`. Diagrams show it when present.
    var fingers: [Int?]?

    var id: String { name }

    /// Standard six-string tuning; index 0 = high e … 5 = low E.
    static let stringCount = 6
    static let openMidi = [64, 59, 55, 50, 45, 40]

    init(_ name: String, frets: [Int?], fingers: [Int?]? = nil) {
        self.name = name
        self.frets = frets
        self.fingers = fingers
    }
}

// MARK: - Pure geometry (T5 — SwiftUI-free, unit-tested)

extension ChordVoicing {
    /// The string indices that actually sound (not muted), high-e first.
    var soundedStrings: [Int] { frets.indices.filter { frets[$0] != nil } }

    /// MIDI note numbers of the sounded strings, low-to-high unsorted (string order).
    var midiNotes: [Int] {
        soundedStrings.compactMap { index in
            guard let fret = frets[index] else { return nil }
            return ChordVoicing.openMidi[index] + fret
        }
    }

    /// The distinct pitch classes sounded — the voicing's harmonic content.
    var pitchClasses: Set<Int> { Set(midiNotes.map { (($0 % 12) + 12) % 12 }) }

    /// A **triad** = exactly three distinct pitch classes; a seventh chord = four.
    var isTriad: Bool { pitchClasses.count == 3 }

    /// The chord's **root** — the pitch class of its lowest-sounding string. Every library voicing is
    /// in root position, so the bass note is the root; `nil` only for an empty voicing.
    var rootPitchClass: Int? {
        guard let lowest = midiNotes.min() else { return nil }
        return ((lowest % 12) + 12) % 12
    }

    /// Sounds a minor third (and no major third) above the root ⇒ a minor-quality chord (its Roman
    /// numeral is lowercased).
    var isMinorQuality: Bool {
        guard let root = rootPitchClass else { return false }
        return pitchClasses.contains((root + 3) % 12) && !pitchClasses.contains((root + 4) % 12)
    }

    /// A diminished triad (minor third + flat fifth, no perfect fifth) ⇒ lowercase numeral with a °.
    var isDiminishedQuality: Bool {
        guard let root = rootPitchClass else { return false }
        return pitchClasses.contains((root + 3) % 12) && pitchClasses.contains((root + 6) % 12)
            && !pitchClasses.contains((root + 7) % 12)
    }

    /// The fretted (non-open, non-muted) fret numbers.
    private var frettedNumbers: [Int] { frets.compactMap { $0 }.filter { $0 > 0 } }

    /// Lowest / highest fretted fret; `nil` when every sounded string is open.
    var lowestFret: Int? { frettedNumbers.min() }
    var highestFret: Int? { frettedNumbers.max() }

    /// The fret the diagram's first row represents. A shape that reaches the nut region (highest
    /// fretted note ≤ 4) anchors at fret 1 and shows open-string / nut markers; a shape sitting
    /// higher shows a four-fret window starting at its lowest fretted fret, with a "n fr." caption.
    var displayBaseFret: Int {
        guard let low = lowestFret, let high = highestFret, high > 4 else { return 1 }
        return low
    }

    /// Playable as encoded: right string count, no negative frets, and at least one string sounds.
    var isValid: Bool {
        frets.count == ChordVoicing.stringCount
            && frets.allSatisfy { ($0 ?? 0) >= 0 }
            && !soundedStrings.isEmpty
    }
}
