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
    /// Which position up the neck (1 … `scale.positionCount`), CAGED-style — clamped in range. The
    /// neck-spanning layouts (S4) read this as their starting anchor.
    var position: Int
    /// How many octaves the run climbs (1 or 2) — capped so a run stays phone-sized. **Only the box
    /// layout uses it** (S4); the neck-spanning layouts define their own reach and ignore it.
    var octaves: Int
    /// Whether the run descends back after the ascent.
    var roundTrip: Bool
    /// Evenly-spaced notes per beat (default eighths). Clamped to at least 1.
    var notesPerBeat: Int
    /// **How the scale is laid on the neck** (ADR 0083 S4), String-backed for forward-compatible decode
    /// (ADR 0036) — read via `layout`. Additive, decode-time-defaulting to `.box`, so every scale
    /// authored before this axis existed decodes and generates unchanged (no store migration, T4).
    var layoutRaw: String

    /// The decoded scale — unknown raw falls back to the minor pentatonic.
    var scale: GuitarScale { GuitarScale(storage: scaleRaw) }

    /// The decoded layout, coerced to one the scale actually supports (an unsupported pairing — a
    /// forward-compat blob, say — generates as `.box`), so generation never trusts an out-of-range value.
    var layout: ScaleLayout {
        let decoded = ScaleLayout(storage: layoutRaw)
        return scale.supports(decoded) ? decoded : .box
    }

    init(scale: GuitarScale,
         rootPitchClass: Int,
         position: Int = 1,
         octaves: Int = 2,
         roundTrip: Bool = true,
         notesPerBeat: Int = 2,
         layout: ScaleLayout = .box,
         version: Int = ScaleRun.currentVersion) {
        self.version = version
        self.scaleRaw = scale.rawValue
        self.rootPitchClass = (((rootPitchClass % 12) + 12) % 12)
        let resolvedLayout = scale.supports(layout) ? layout : .box
        self.layoutRaw = resolvedLayout.rawValue
        self.position = min(max(1, position), Self.positionCount(for: resolvedLayout, scale: scale))
        self.octaves = min(2, max(1, octaves))
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
    }

    private enum CodingKeys: String, CodingKey {
        case version, scaleRaw, rootPitchClass, position, octaves, roundTrip, notesPerBeat, layoutRaw
    }

    /// Custom decode so the ADR 0083 `layoutRaw` defaults when absent (T4 — decode-time default, no
    /// store migration); an older blob missing it decodes to the box layout and generates unchanged.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        scaleRaw = try container.decode(String.self, forKey: .scaleRaw)
        rootPitchClass = (((try container.decode(Int.self, forKey: .rootPitchClass) % 12) + 12) % 12)
        let decodedScale = GuitarScale(storage: scaleRaw)
        let decodedRaw = try container.decodeIfPresent(String.self, forKey: .layoutRaw) ?? ScaleLayout.box.rawValue
        layoutRaw = decodedRaw
        let decodedLayout = decodedScale.supports(ScaleLayout(storage: decodedRaw))
            ? ScaleLayout(storage: decodedRaw) : .box
        position = min(max(1, try container.decode(Int.self, forKey: .position)),
                       Self.positionCount(for: decodedLayout, scale: decodedScale))
        octaves = min(2, max(1, try container.decode(Int.self, forKey: .octaves)))
        roundTrip = try container.decode(Bool.self, forKey: .roundTrip)
        notesPerBeat = max(1, try container.decode(Int.self, forKey: .notesPerBeat))
    }
}

// MARK: - Naming (pure)

extension ScaleRun {
    /// The tonic's note name (sharp-spelled), e.g. "A".
    var rootName: String { GuitarScale.noteName(forPitchClass: rootPitchClass) }

    /// The full run title, e.g. "A Minor Pentatonic".
    var title: String { "\(rootName) \(scale.displayName)" }

    /// The lowest fretted fret the current run occupies — shown as "fret N". Derived from the actual
    /// generated run so it reads correctly for every layout, not just the box.
    var anchorFret: Int { ascendingNotes.map(\.fret).filter { $0 > 0 }.min() ?? 1 }

    /// The CAGED reference letter for the current position (E/D/C/A/G) — how a player actually
    /// recognises the shape, shown instead of a bare position number.
    var shapeLetter: String { CAGEDShape(clampedPosition: position).shapeLetter }

    /// The extended diagonal's fingering — one of the two canonical shapes — derived from `position`
    /// (which the editor caps at 1…2 for this layout). Only meaningful when `layout == .extended`.
    var extendedShape: ExtendedPentatonicShape { ExtendedPentatonicShape(selector: position) }

    /// How many positions/shapes the current layout offers — the five CAGED boxes for `.box` and
    /// `.threePerString`, but only the **two** canonical fingerings for `.extended`.
    var positionCount: Int { Self.positionCount(for: layout, scale: scale) }

    static func positionCount(for layout: ScaleLayout, scale: GuitarScale) -> Int {
        layout == .extended ? ExtendedPentatonicShape.allCases.count : scale.positionCount
    }

    /// The player-facing name for the current position — a CAGED shape letter rather than a bare number
    /// (ADR 0083 refinement): the box's CAGED letter for `.box`, the extended shape's mnemonic for
    /// `.extended`, and the pattern number for the diatonic `.threePerString` (which isn't a CAGED box).
    var positionLabel: String {
        switch layout {
        case .box: return "\(shapeLetter) shape"
        case .extended: return "\(extendedShape.shapeLetter) shape"
        case .threePerString: return "Pattern \(position)"
        }
    }
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

    /// The ascending run for the current **layout** (S4), paired with an optional per-note **group**
    /// index the renderer focuses (box index for `.extended`, `nil` otherwise). Correct by construction
    /// — every note belongs to the scale and the run climbs strictly, in every layout.
    var ascendingLayout: (notes: [FretNote], groups: [Int]?) {
        switch layout {
        case .box:
            return (CAGEDShape.trimmed(boxNotes, toOctaves: octaves), nil)
        case .threePerString:
            return (ScaleNeckLayout.threePerString(scale: scale, root: rootPitchClass, position: position), nil)
        case .extended:
            let extended = ScaleNeckLayout.extended(scale: scale, root: rootPitchClass, shape: extendedShape)
            return (extended.notes, extended.groups)
        }
    }

    /// The ascending run: the full box for two octaves, or its lower octave for one (box layout); the
    /// diagonal or 3-notes-per-string climb otherwise. Correct by construction — every note belongs to
    /// the scale, and the run climbs strictly.
    var ascendingNotes: [FretNote] { ascendingLayout.notes }

    /// Thread the blue note (♭5) in as a chromatic passing tone one fret above each p4, so a blues
    /// box reads as its minor pentatonic with the tritone added where players actually sound it.
    private static func insertingBlueNote(into notes: [FretNote], root: Int) -> [FretNote] {
        notes.flatMap { note -> [FretNote] in
            CAGEDShape.degree(of: note, root: root) == 5   // a perfect fourth
                ? [note, FretNote(string: note.string, fret: note.fret + 1)]
                : [note]
        }
    }

    /// One cycle of notes — the ascending run, then (when `roundTrip`) a descent that omits the shared
    /// peak and start so a looping cycle never double-hits a note — paired with the per-note **group**
    /// index (box focus for `.extended`, S2b), mirrored across the descent so the two arrays stay
    /// index-aligned. The same smooth triangle as the other generators.
    var sequenceWithGroups: (notes: [FretNote], groups: [Int]?) {
        let (ascent, ascentGroups) = ascendingLayout
        guard roundTrip, ascent.count > 2 else { return (ascent, ascentGroups) }
        let descentRange = Array(ascent.indices.dropFirst().dropLast().reversed())
        let notes = ascent + descentRange.map { ascent[$0] }
        let groups = ascentGroups.map { groups in groups + descentRange.map { groups[$0] } }
        return (notes, groups)
    }

    /// One cycle of notes (the group tags dropped) — the shape most callers and tests read.
    var sequence: [FretNote] { sequenceWithGroups.notes }

    /// Expand into the evenly-gridded `FretboardDrill` the board plays. Carries the `rootPitchClass` so
    /// the renderer lights the tonic notes wherever they fall, and the per-note **box groups** so the
    /// board can focus the box being played on an extended diagonal (ADR 0083 S2b); a box or
    /// 3-notes-per-string run carries no groups, so nothing dims.
    func expanded() -> FretboardDrill {
        let (notes, groups) = sequenceWithGroups
        return FretboardDrill(notesPerBeat: notesPerBeat,
                              notes: notes.map { Optional($0) },
                              stringCount: 6,
                              rootPitchClass: rootPitchClass,
                              noteGroups: groups)
    }
}

// MARK: - Curated default (T8)

extension ScaleRun {
    /// The starter scale a freshly-created Scales drill opens on — **A minor pentatonic**, position 1,
    /// two octaves: the workhorse box from the 5th fret. A real, playable run from the first moment.
    static let aMinorPentatonic = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                                           position: 1, octaves: 2)

    /// The **extended** A minor pentatonic (ADR 0083 S4) — the A-G-slide diagonal (shape 1 of the two
    /// canonical fingerings), three boxes stitched into one climb by whole-step slides on the A and G
    /// strings. The flagship for the diagonal layout.
    static let aMinorPentatonicExtended = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                                                   position: 1, layout: .extended)

    /// The **3-notes-per-string** G major scale (ADR 0083 S4) — the diatonic neck-spanning drill, three
    /// tones on every string from the low E up. The flagship for the 3-NPS layout.
    static let gMajorThreePerString = ScaleRun(scale: .major, rootPitchClass: 7,
                                               position: 1, layout: .threePerString)
}
