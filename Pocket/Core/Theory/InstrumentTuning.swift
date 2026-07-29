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

    /// The tuning with this name for this instrument, or **Standard** if the name isn't one of the
    /// instrument's curated tunings. Lets a stored tuning name resolve safely across an instrument
    /// change — a guitar-only "Open G" left in `@AppStorage` lands on the bass's Standard rather than
    /// nothing (ADR 0115: a bass tuning never leaks onto guitar, and vice-versa).
    func tuning(named name: String) -> Tuning {
        tunings.first { $0.name == name } ?? standardTuning
    }
}

// MARK: - Fretboard-engine bridge (ADR 0116)

extension Instrument {
    /// The engine-canonical open-string MIDI — **highest-first** (index 0 = thinnest string) — for this
    /// instrument's **standard** tuning. The single point the fretboard generators resolve an instrument
    /// to (ADR 0116): guitar returns `[64,59,55,50,45,40]` (the golden-pinned CAGED constant), bass its
    /// four strings. Per-exercise alternate tunings (Drop D) and custom tunings are deferred, so
    /// generation always uses standard.
    var engineOpenMidi: [Int] { standardTuning.engineOpenMidi }

    /// How many strings this instrument's board draws — the length of its standard tuning (6 / 4).
    var stringCount: Int { standardTuning.stringCount }

    /// The MIDI pitch a `FretNote` sounds on this instrument's standard tuning — the instrument-aware
    /// counterpart of `CAGEDShape.midi` / `BassNeckLayout.midi`, used where the neck's actual pitches are
    /// needed (Hear playback of a generated run).
    func midi(of note: FretNote) -> Int {
        let open = engineOpenMidi
        guard !open.isEmpty else { return note.fret }
        return open[min(max(0, note.string), open.count - 1)] + note.fret
    }
}

/// How the tuner interprets a detected pitch (ADR 0115). **Guided** (default) knows the selected
/// tuning and names the target string + direction; **Chromatic** names any of the twelve pitches with
/// no target, for odd/experimental tunings. `String`-raw so it drops straight into `@AppStorage`.
enum TunerMode: String, CaseIterable, Identifiable {
    case guided
    case chromatic

    var id: String { rawValue }

    /// The mode the tuner opens in.
    static let `default`: TunerMode = .guided

    var displayName: String {
        switch self {
        case .guided: return "Guided"
        case .chromatic: return "Chromatic"
        }
    }

    /// One-line explanation for the settings sheet.
    var blurb: String {
        switch self {
        case .guided: return "Tunes to your selected tuning and names the string you're nearest."
        case .chromatic: return "Names any note with no target — for odd or experimental tunings."
        }
    }
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

    /// The open-string MIDI notes in the **fretboard engine's** canonical order — **highest string
    /// first** (index 0 = high e / thinnest), the reverse of this struct's lowest-first `midiNotes`
    /// (ADR 0116). This is the *single* crossing point between the tuner's lowest-first `Tuning`
    /// value and the engine (`CAGEDShape.openMidi`, `ChordVoicing.openMidi`, `ScaleLayout`,
    /// `FretNote.string`), all of which index highest-first and are persisted that way — so raw
    /// `midiNotes` must never reach engine code, only `engineOpenMidi`. Valid only for **monotonic**
    /// tunings (every curated guitar/bass tuning); a reentrant tuning like ukulele's gCEA is not a
    /// simple reversal, which is why uke is deferred. Guitar Standard here is
    /// `[64,59,55,50,45,40]` — byte-for-byte the engine's long-standing hardcoded constant, the
    /// golden test that proves the refactor changes nothing for guitar.
    var engineOpenMidi: [Int] { Array(midiNotes.reversed()) }

    /// Open-string names low→high, e.g. `["E","A","D","G","B","E"]`. **Always sharp-spelled**, and
    /// deliberately outside the accidental preference (ADR 0123): an open tuning is named for the chord
    /// it sounds, so Open D's third string is F♯ — the raised third of D major — for everyone. Spelling
    /// it G♭ on a preference would be plain wrong, and the preference exists only where nothing decides.
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
