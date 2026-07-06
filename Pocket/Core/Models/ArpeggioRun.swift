import Foundation

/// An **arpeggio quality** in the first-party library (ADR 0065 build 2, Slice 3). Like `GuitarScale`
/// it is just an **interval formula** — the chord tones as semitones from the root — plus the
/// *relative major* whose CAGED boxes it borrows (chosen so every chord tone is diatonic to that
/// major, and the shape falls out of the shared generator for free). Common-practice vocabulary
/// authored in-house (T8); String-backed on the payload (ADR 0036) with an unknown-value fallback.
enum ArpeggioQuality: String, CaseIterable, Identifiable, Codable {
    case major
    case minor
    case majorSeventh
    case minorSeventh
    case dominantSeventh

    var id: String { rawValue }

    /// Forgiving decode — an unrecognised stored quality falls back to the minor seventh (the
    /// workhorse), mirroring the scale/template fallbacks.
    init(storage raw: String) { self = ArpeggioQuality(rawValue: raw) ?? .minorSeventh }

    var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .majorSeventh: return "Major 7"
        case .minorSeventh: return "Minor 7"
        case .dominantSeventh: return "Dominant 7"
        }
    }

    /// The chord tones as semitones from the root — the arpeggio's formula.
    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]              // R 3 5
        case .minor: return [0, 3, 7]              // R ♭3 5
        case .majorSeventh: return [0, 4, 7, 11]   // R 3 5 7
        case .minorSeventh: return [0, 3, 7, 10]   // R ♭3 5 ♭7
        case .dominantSeventh: return [0, 4, 7, 10] // R 3 5 ♭7
        }
    }

    /// The chord tones as a degree set — what a CAGED box is filtered to.
    var degrees: Set<Int> { Set(intervals) }

    /// Semitones from the root **up to the relative major** whose CAGED boxes this quality borrows,
    /// chosen so every chord tone is diatonic to that major: a major-third chord is its own major (0);
    /// a minor-third chord sits a minor third below its relative major (3); a dominant seventh belongs
    /// to the major a fourth up — it is that key's V7 (5).
    var relativeMajorSemitones: Int {
        switch self {
        case .major, .majorSeventh: return 0
        case .minor, .minorSeventh: return 3
        case .dominantSeventh: return 5
        }
    }
}

/// A **generated arpeggio run** (ADR 0065 build 2, Slice 3) — the arpeggio sibling of `ScaleRun`,
/// declared by *picking* a **quality**, a **root**, a **position** (one of the five CAGED boxes), and
/// **octaves**. Generation places the position's `CAGEDShape` in the key and filters it to the chord
/// tones, so every shape is a real CAGED arpeggio box, correct by construction. Optionally runs **up
/// and back**. Stored as the recipe inside the versioned `FretboardContent` payload (T4); the
/// generation is pure and unit-tested (T5).
struct ArpeggioRun: Codable, Equatable {
    /// The schema version this build writes (T4).
    static let currentVersion = 1

    var version: Int
    /// The quality, String-backed for forward-compatible decode (ADR 0036) — read via `quality`.
    var qualityRaw: String
    /// The tonic's pitch class (0 = C … 11 = B).
    var rootPitchClass: Int
    /// Which position up the neck (1 … 5 CAGED boxes) — clamped in range.
    var position: Int
    /// How many octaves the run climbs (1 or 2) — capped so a run stays phone-sized.
    var octaves: Int
    /// Whether the run descends back after the ascent.
    var roundTrip: Bool
    /// Evenly-spaced notes per beat (default eighths). Clamped to at least 1.
    var notesPerBeat: Int

    /// The decoded quality — unknown raw falls back to the minor seventh.
    var quality: ArpeggioQuality { ArpeggioQuality(storage: qualityRaw) }

    init(quality: ArpeggioQuality,
         rootPitchClass: Int,
         position: Int = 1,
         octaves: Int = 2,
         roundTrip: Bool = true,
         notesPerBeat: Int = 2,
         version: Int = ArpeggioRun.currentVersion) {
        self.version = version
        self.qualityRaw = quality.rawValue
        self.rootPitchClass = (((rootPitchClass % 12) + 12) % 12)
        self.position = min(max(1, position), CAGEDShape.allCases.count)
        self.octaves = min(2, max(1, octaves))
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
    }
}

// MARK: - Naming (pure)

extension ArpeggioRun {
    /// The tonic's note name (sharp-spelled), e.g. "A".
    var rootName: String { GuitarScale.noteName(forPitchClass: rootPitchClass) }

    /// The full run title, e.g. "A Minor 7".
    var title: String { "\(rootName) \(quality.displayName)" }

    /// The number of CAGED positions offered — always the five boxes.
    var positionCount: Int { CAGEDShape.allCases.count }

    /// The lowest fret the current position's box occupies — shown as "Anchored at fret N".
    var anchorFret: Int { boxNotes.map(\.fret).min() ?? 1 }

    /// The CAGED reference letter for the current position (E/D/C/A/G) — how a player actually
    /// recognises the shape, shown instead of a bare position number.
    var shapeLetter: String { CAGEDShape(clampedPosition: position).shapeLetter }
}

// MARK: - Generation (pure — shared CAGED box, filtered to the chord tones)

extension ArpeggioRun {
    /// The chosen CAGED box, placed in this run's key and filtered to the chord tones.
    var boxNotes: [FretNote] {
        CAGEDShape.filteredBox(position: position, root: rootPitchClass,
                               relativeMajorSemitones: quality.relativeMajorSemitones,
                               degrees: quality.degrees)
    }

    /// The ascending run: the full box for two octaves, or its lower octave for one.
    var ascendingNotes: [FretNote] { CAGEDShape.trimmed(boxNotes, toOctaves: octaves) }

    /// One cycle of notes: the ascending run, then (when `roundTrip`) a descent that omits the shared
    /// peak and start so a looping cycle never double-hits a note.
    var sequence: [FretNote] {
        let ascent = ascendingNotes
        guard roundTrip, ascent.count > 2 else { return ascent }
        return ascent + Array(ascent.dropFirst().dropLast().reversed())
    }

    /// Expand into the evenly-gridded `FretboardDrill` the board plays. Carries the `rootPitchClass`
    /// so the renderer can light the tonic notes wherever they fall in the run.
    func expanded() -> FretboardDrill {
        FretboardDrill(notesPerBeat: notesPerBeat,
                       notes: sequence.map { Optional($0) },
                       stringCount: 6,
                       rootPitchClass: rootPitchClass)
    }
}

// MARK: - Curated default (T8)

extension ArpeggioRun {
    /// The starter arpeggio a freshly-created Arpeggios drill opens on — **A minor 7**, position 1,
    /// two octaves: a real, playable arpeggio from the first moment.
    static let aMinorSeventh = ArpeggioRun(quality: .minorSeventh, rootPitchClass: 9,
                                           position: 1, octaves: 2)
}
