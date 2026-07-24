import Foundation

/// A stringed instrument the tuner supports (ADR 0115). Guitar and bass ship in v1; **ukulele**
/// (re-entrant `GCEA`, whose non-monotonic string order needs a small UI accommodation) and
/// **custom** user-authored tunings are deferred (the latter is the one legitimate future Pro seam,
/// ADR 0112). `String`-raw so it drops straight into `@AppStorage` for the Tune Settings sheet.
enum Instrument: String, CaseIterable, Identifiable {
    case guitar
    case bass

    var id: String { rawValue }

    /// The instrument shipped as the tuner's opening state.
    static let `default`: Instrument = .guitar

    var displayName: String {
        switch self {
        case .guitar: return "Guitar"
        case .bass: return "Bass"
        }
    }

    /// The curated tunings for this instrument, **Standard first** (the reset target when the
    /// instrument changes). Deliberately restrained — the common ones players actually reach for,
    /// not a hardware tuner's exhaustive list.
    var tunings: [Tuning] {
        switch self {
        case .guitar:
            return [
                Tuning(name: "Standard", midiNotes: [40, 45, 50, 55, 59, 64]),   // E2 A2 D3 G3 B3 E4
                Tuning(name: "Drop D", midiNotes: [38, 45, 50, 55, 59, 64]),
                Tuning(name: "Half step down", midiNotes: [39, 44, 49, 54, 58, 63]),
                Tuning(name: "Full step down", midiNotes: [38, 43, 48, 53, 57, 62]),
                Tuning(name: "Open G", midiNotes: [38, 43, 50, 55, 59, 62]),
                Tuning(name: "Open D", midiNotes: [38, 45, 50, 54, 57, 62]),
                Tuning(name: "Open E", midiNotes: [40, 47, 52, 56, 59, 64]),
                Tuning(name: "DADGAD", midiNotes: [38, 45, 50, 55, 57, 62]),
                Tuning(name: "Drop C", midiNotes: [36, 43, 48, 53, 57, 62])
            ]
        case .bass:
            return [
                Tuning(name: "Standard", midiNotes: [28, 33, 38, 43]),   // E1 A1 D2 G2
                Tuning(name: "Drop D", midiNotes: [26, 33, 38, 43]),
                Tuning(name: "Half step down", midiNotes: [27, 32, 37, 42])
            ]
        }
    }

    /// This instrument's Standard tuning — the opening / reset tuning.
    var standardTuning: Tuning { tunings[0] }
}

/// A named tuning: the open-string MIDI notes, **lowest string first** (ADR 0115). The string count
/// is simply the array length (6 for guitar, 4 for bass), which is what lets bass drop in with no
/// model change. Pure and testable; spelling defers to `GuitarScale.noteName`.
struct Tuning: Equatable, Identifiable {
    let name: String
    /// Open-string MIDI notes, lowest (6th/4th string) first.
    let midiNotes: [Int]

    var id: String { name }

    /// Number of strings this tuning covers.
    var stringCount: Int { midiNotes.count }

    /// Sharp-spelled open-string names low→high, e.g. `["E","A","D","G","B","E"]`.
    var noteNames: [String] {
        midiNotes.map { GuitarScale.noteName(forPitchClass: (($0 % 12) + 12) % 12) }
    }

    /// Compact label for a settings row, e.g. `"EADGBE"`.
    var compactLabel: String { noteNames.joined() }

    /// Guided-mode target: the index of the open string in this tuning nearest to `midiNote` (by
    /// absolute MIDI distance, so octaves are respected — DADGAD's three D's don't collapse). Ties
    /// resolve to the **lower** string (smaller index). Lets the tuner say "you're on the 6th string"
    /// from a detected pitch. Returns 0 for an empty tuning (never happens for the curated catalog).
    func nearestStringIndex(toMidi midiNote: Int) -> Int {
        var bestIndex = 0
        var bestDistance = Int.max
        for (index, note) in midiNotes.enumerated() where abs(note - midiNote) < bestDistance {
            bestDistance = abs(note - midiNote)
            bestIndex = index
        }
        return bestIndex
    }
}
