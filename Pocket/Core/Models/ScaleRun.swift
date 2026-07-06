import Foundation

/// A **generated scale run** (ADR 0065 build 2, Slice 2) — a preprogrammed scale drill declared by
/// *picking*: a **scale**, a **root note**, a **position** up the neck (one of the five CAGED boxes),
/// and how many **octaves**. Generation places the position's `CAGEDShape` in the chosen key and
/// filters it to the scale's degrees, so every shape is a real CAGED box — not a formula
/// approximation that only held at the E position — and "A Minor Pentatonic, position 1" is a few
/// menu taps, correct by construction. Optionally runs **up and back**.
///
/// Stored as the recipe (not the expanded notes) inside the versioned `FretboardContent` payload
/// (T4). The generation is pure and unit-tested — every note is verified to belong to the scale, to
/// ascend, and to sit inside a single hand box (T5).
struct ScaleRun: Codable, Equatable {
    /// The schema version this build writes (T4).
    static let currentVersion = 1

    var version: Int
    /// The scale, String-backed for forward-compatible decode (ADR 0036) — read via `scale`.
    var scaleRaw: String
    /// The tonic's pitch class (0 = C … 11 = B) — the key. The fretboard position is derived.
    var rootPitchClass: Int
    /// Which position up the neck (1 … `scale.positionCount`), CAGED-style — clamped in range.
    var position: Int
    /// How many octaves the run climbs (1 or 2) — capped so a run stays phone-sized.
    var octaves: Int
    /// Whether the run descends back after the ascent.
    var roundTrip: Bool
    /// Evenly-spaced notes per beat (default eighths). Clamped to at least 1.
    var notesPerBeat: Int

    /// The decoded scale — unknown raw falls back to the minor pentatonic.
    var scale: GuitarScale { GuitarScale(storage: scaleRaw) }

    init(scale: GuitarScale,
         rootPitchClass: Int,
         position: Int = 1,
         octaves: Int = 2,
         roundTrip: Bool = true,
         notesPerBeat: Int = 2,
         version: Int = ScaleRun.currentVersion) {
        self.version = version
        self.scaleRaw = scale.rawValue
        self.rootPitchClass = (((rootPitchClass % 12) + 12) % 12)
        self.position = min(max(1, position), scale.positionCount)
        self.octaves = min(2, max(1, octaves))
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
    }
}

// MARK: - Naming (pure)

extension ScaleRun {
    /// The tonic's note name (sharp-spelled), e.g. "A".
    var rootName: String { GuitarScale.noteName(forPitchClass: rootPitchClass) }

    /// The full run title, e.g. "A Minor Pentatonic".
    var title: String { "\(rootName) \(scale.displayName)" }

    /// The lowest fret the current position's box occupies — shown as "Anchored at fret N".
    var anchorFret: Int { boxNotes.map(\.fret).min() ?? 1 }

    /// The CAGED reference letter for the current position (E/D/C/A/G) — how a player actually
    /// recognises the shape, shown instead of a bare position number.
    var shapeLetter: String { CAGEDShape(clampedPosition: position).shapeLetter }
}

// MARK: - Generation (pure — CAGED box, placed then filtered; verified in tests)

extension ScaleRun {
    /// The chosen CAGED box, placed in this run's key and filtered to the scale's degrees (the shared
    /// `CAGEDShape` generator). The blues note (♭5), which no diatonic box contains, is threaded in as
    /// a chromatic passing tone.
    var boxNotes: [FretNote] {
        var notes = CAGEDShape.filteredBox(position: position, root: rootPitchClass,
                                           relativeMajorSemitones: scale.relativeMajorSemitones,
                                           degrees: scale.degrees)
        if scale == .blues { notes = Self.insertingBlueNote(into: notes, root: rootPitchClass) }
        return notes
    }

    /// The ascending run: the full box for two octaves, or its lower octave for one. Correct by
    /// construction — every note belongs to the scale, and the run climbs strictly.
    var ascendingNotes: [FretNote] { CAGEDShape.trimmed(boxNotes, toOctaves: octaves) }

    /// Thread the blue note (♭5) in as a chromatic passing tone one fret above each p4, so a blues
    /// box reads as its minor pentatonic with the tritone added where players actually sound it.
    private static func insertingBlueNote(into notes: [FretNote], root: Int) -> [FretNote] {
        notes.flatMap { note -> [FretNote] in
            CAGEDShape.degree(of: note, root: root) == 5   // a perfect fourth
                ? [note, FretNote(string: note.string, fret: note.fret + 1)]
                : [note]
        }
    }

    /// One cycle of notes: the ascending run, then (when `roundTrip`) a descent that omits the shared
    /// peak and start so a looping cycle never double-hits a note — the same smooth triangle as the
    /// other generators.
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

extension ScaleRun {
    /// The starter scale a freshly-created Scales drill opens on — **A minor pentatonic**, position 1,
    /// two octaves: the workhorse box from the 5th fret. A real, playable run from the first moment.
    static let aMinorPentatonic = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                                           position: 1, octaves: 2)
}
