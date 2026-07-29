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
    /// Evenly-spaced notes per beat — **quarters by default**, so a new run states the plainest
    /// rhythm and the player raises it deliberately. Clamped to at least 1.
    var notesPerBeat: Int
    /// **How the scale is laid on the neck** (ADR 0083 S4), String-backed for forward-compatible decode
    /// (ADR 0036) — read via `layout`. Additive, decode-time-defaulting to `.box`, so every scale
    /// authored before this axis existed decodes and generates unchanged (no store migration, T4).
    var layoutRaw: String
    /// **How the run is sequenced** (ADR 0108) — straight, or reordered into thirds/fourths/groups.
    /// String-backed (ADR 0036) — read via `sequencePattern`. Additive, decode-time-defaulting to
    /// `.straight`, so every scale authored before this axis existed plays unchanged.
    var sequenceRaw: String
    /// Whether the run begins on the box's **lowest root** rather than on its lowest note (2026-07-28).
    /// Stored on the recipe, never read at render time: it changes the played note order, so a saved run
    /// must keep whatever it was authored with. Hence the split defaults — `true` for a run created now,
    /// but decode-defaulting to `false`, so nothing already in the store silently reorders itself.
    /// Box-only, like `octaves`: the neck-spanning layouts define their own start.
    var startsFromLowestRoot: Bool

    /// The decoded scale — unknown raw falls back to the minor pentatonic.
    var scale: GuitarScale { GuitarScale(storage: scaleRaw) }

    /// The decoded layout, coerced to one the scale actually supports (an unsupported pairing — a
    /// forward-compat blob, say — generates as `.box`), so generation never trusts an out-of-range value.
    var layout: ScaleLayout {
        let decoded = ScaleLayout(storage: layoutRaw)
        return scale.supports(decoded) ? decoded : .box
    }

    /// The decoded sequence pattern — unknown raw falls back to straight (ADR 0108).
    var sequencePattern: SequencePattern { SequencePattern(storage: sequenceRaw) }

    init(scale: GuitarScale,
         rootPitchClass: Int,
         position: Int = 1,
         octaves: Int = 2,
         roundTrip: Bool = true,
         notesPerBeat: Int = 1,
         layout: ScaleLayout = .box,
         sequence: SequencePattern = .straight,
         startsFromLowestRoot: Bool = true,
         version: Int = ScaleRun.currentVersion) {
        self.version = version
        self.scaleRaw = scale.rawValue
        self.rootPitchClass = (((rootPitchClass % 12) + 12) % 12)
        let resolvedLayout = scale.supports(layout) ? layout : .box
        self.layoutRaw = resolvedLayout.rawValue
        self.sequenceRaw = sequence.rawValue
        self.startsFromLowestRoot = startsFromLowestRoot
        self.position = min(max(1, position), Self.positionCount(for: resolvedLayout, scale: scale))
        self.octaves = min(2, max(1, octaves))
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
    }

    private enum CodingKeys: String, CodingKey {
        case version, scaleRaw, rootPitchClass, position, octaves, roundTrip, notesPerBeat, layoutRaw
        case sequenceRaw, startsFromLowestRoot
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
        sequenceRaw = try container.decodeIfPresent(String.self, forKey: .sequenceRaw)
            ?? SequencePattern.straight.rawValue
        // Absent means "authored before the axis existed" — those runs keep starting on the box's
        // lowest note, so an already-saved exercise never reorders itself under the player.
        startsFromLowestRoot = try container.decodeIfPresent(Bool.self, forKey: .startsFromLowestRoot) ?? false
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
    /// The tonic's note name, **spelled by the run's own key** (ADR 0123), e.g. "A", or "B♭" — never
    /// "A♯" — for a run rooted there. A scale run is a tonal centre, so nothing here consults the
    /// user's accidental preference; the key answers.
    var rootName: String { (keySpelling ?? .default).name(pitchClass: rootPitchClass) }

    /// The spelling this run's key implies (ADR 0123), or `nil` at the two positions the circle of
    /// fifths leaves open — C and F♯/G♭ — where the user's accidental preference takes over. Pure
    /// callers (titles, auto-names) resolve `nil` to the sharp default and stay deterministic.
    var keySpelling: NoteSpelling? { NoteSpelling.forScale(scale, root: rootPitchClass) }

    /// The full run title, e.g. "A Minor Pentatonic".
    var title: String { "\(rootName) \(scale.displayName)" }

    /// The lowest fretted fret the current run occupies — shown as "fret N". Derived from the shape the
    /// hand covers (`positionNotes`), not the played order, so "start from the lowest root" moves where
    /// the run *begins* without relabelling where the hand *sits*.
    var anchorFret: Int { positionNotes.map(\.fret).filter { $0 > 0 }.min() ?? 1 }

    /// The notes a **position label** describes: the box as the hand covers it, before `startsFromLowestRoot`
    /// picks a starting note within it. The neck-spanning layouts have no separate shape, so they report
    /// their run directly.
    var positionNotes: [FretNote] {
        layout == .box ? CAGEDShape.trimmed(boxNotes, toOctaves: octaves) : ascendingLayout.notes
    }

    /// The CAGED reference letter for the current position (E/D/C/A/G). Demoted to a secondary caption
    /// (ADR 0091): it's the letter of the box in the *reference/relative-major* key, so for a
    /// minor/modal scale it isn't the letter a player names relative to the tonic — kept for those who
    /// read CAGED, but no longer the primary position label.
    var shapeLetter: String { CAGEDShape(clampedPosition: position).shapeLetter }

    /// A plain-language location for the current **box** (ADR 0091), e.g. "root on low E · fret 5" —
    /// where the box's lowest root note actually sits, shown under the box number in place of the CAGED
    /// letter. Reads the generated notes, so it's honest for every scale and key. Only the box layout
    /// carries a single anchoring root; the neck-spanning layouts report their own start instead.
    var rootAnchor: String { CAGEDShape.rootAnchor(in: positionNotes, root: rootPitchClass) }

    /// The flagship box for this scale/key — the root-position 6th-string box a player learns first
    /// (position 5 for the minor pentatonic, not 1; ADR 0091). Computed per scale, so it tracks the
    /// famous box whatever the CAGED offset.
    var flagshipPosition: Int {
        CAGEDShape.flagshipPosition(root: rootPitchClass,
                                    relativeMajorSemitones: scale.relativeMajorSemitones,
                                    degrees: scale.degrees)
    }

    /// Whether the current position is the flagship **most-common** box — drives the "Most common"
    /// badge; only meaningful for the box layout.
    var isMostCommon: Bool { layout == .box && position == flagshipPosition }

    /// The extended diagonal's fingering — one of the two canonical shapes — derived from `position`
    /// (which the editor caps at 1…2 for this layout). Only meaningful when `layout == .extended`.
    var extendedShape: ExtendedPentatonicShape { ExtendedPentatonicShape(selector: position) }

    /// How many positions/shapes the current layout offers — the five CAGED boxes for `.box` and
    /// `.threePerString`, but only the **two** canonical fingerings for `.extended`.
    var positionCount: Int { Self.positionCount(for: layout, scale: scale) }

    static func positionCount(for layout: ScaleLayout, scale: GuitarScale) -> Int {
        layout == .extended ? ExtendedPentatonicShape.allCases.count : scale.positionCount
    }

    /// The player-facing name for the current position (ADR 0091): the box's **root anchor** — where
    /// the hand goes, "root on low E · fret 5" — as the primary label for `.box` (no CAGED letter or box
    /// number up front); the extended shape's mnemonic for `.extended`; the pattern number for the
    /// diatonic `.threePerString`.
    var positionLabel: String {
        switch layout {
        case .box: return rootAnchor
        case .extended: return "\(extendedShape.shapeLetter) shape"
        case .threePerString: return "Pattern \(position)"
        }
    }
}

// MARK: - Generation (pure — CAGED box, placed then filtered; verified in tests)

extension ScaleRun {
    /// The chosen CAGED box, placed in this run's key and filtered to the scale's degrees (the shared
    /// `CAGEDShape` generator). A chromatic passing tone that no diatonic box contains — the blues ♭5,
    /// the bebop ♯5/♮7 — is threaded in afterwards, one fret above its anchor degree.
    var boxNotes: [FretNote] {
        var notes = CAGEDShape.filteredBox(position: position, root: rootPitchClass,
                                           relativeMajorSemitones: scale.relativeMajorSemitones,
                                           degrees: scale.degrees)
        if let anchor = scale.passingToneAnchorDegree {
            notes = Self.insertingPassingTone(into: notes, root: rootPitchClass, afterDegree: anchor)
        }
        return notes
    }

    /// The ascending run for the current **layout** (S4), paired with an optional per-note **group**
    /// index the renderer focuses (box index for `.extended`, `nil` otherwise). Correct by construction
    /// — every note belongs to the scale and the run climbs strictly, in every layout.
    /// **Box-only**, like `octaves`: the diagonal and 3-notes-per-string layouts are defined by their
    /// string-by-string fingering, so starting one part-way through would break the pattern being taught.
    /// The editor hides the toggle for them on the same condition.
    var appliesLowestRootStart: Bool { startsFromLowestRoot && layout == .box }

    var ascendingLayout: (notes: [FretNote], groups: [Int]?) {
        switch layout {
        case .box:
            // Align *before* the octave trim, so a one-octave run measures its octave from the root it
            // starts on rather than keeping a partial octave above a dropped low note.
            let placed = appliesLowestRootStart
                ? CAGEDShape.startingAtLowestRoot(boxNotes, root: rootPitchClass)
                : boxNotes
            return (CAGEDShape.trimmed(placed, toOctaves: octaves), nil)
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

    /// Thread a chromatic passing tone in one fret above each note at `afterDegree`, on the same string,
    /// so a blues box reads as its pentatonic with the ♭5 added, and a bebop box as its mode with the
    /// ♯5/♮7 added, where players actually sound them. The anchor's next diatonic tone is a whole step
    /// up, so the inserted note stays strictly between the two and the run keeps climbing.
    private static func insertingPassingTone(into notes: [FretNote], root: Int,
                                             afterDegree degree: Int) -> [FretNote] {
        notes.flatMap { note -> [FretNote] in
            CAGEDShape.degree(of: note, root: root) == degree
                ? [note, FretNote(string: note.string, fret: note.fret + 1)]
                : [note]
        }
    }

    /// One cycle of notes — the ascending run **reordered by the sequence pattern** (ADR 0108: straight,
    /// thirds, fourths, groups), then (when `roundTrip`) a descent that omits the shared peak and start
    /// so a looping cycle never double-hits a note — paired with the per-note **group** index (box focus
    /// for `.extended`, S2b), mirrored across the descent so the two arrays stay index-aligned. The
    /// sequencing is a pure permutation of the ascending notes, so `ascendingNotes` (and everything that
    /// reads it — the box labels, anchors) is unchanged; only the *played* order here differs.
    var sequenceWithGroups: (notes: [FretNote], groups: [Int]?) {
        let (ascentRaw, ascentGroupsRaw) = ascendingLayout
        let (ascent, ascentGroups) = sequencePattern.apply(to: ascentRaw, groups: ascentGroupsRaw)
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
                              noteGroups: groups,
                              keySpelling: keySpelling)
    }
}

// MARK: - Bass generation + instrument-aware accessors (ADR 0116 Slice 3)

extension ScaleRun {
    /// The rendered drill for a given **instrument** — the single seam the run screen and previews call
    /// once bass exists (ADR 0116). Guitar routes to the untouched `expanded()` above (byte-identical, the
    /// golden path); bass lays a 2-octave `BassNeckLayout` box on the instrument's four strings. The stored
    /// recipe is unchanged — instrument comes from the owning `Exercise`, not the payload.
    func expanded(instrument: Instrument) -> FretboardDrill {
        guard instrument != .guitar else { return expanded() }
        return FretboardDrill(notesPerBeat: notesPerBeat,
                              notes: bassSequence(openMidi: instrument.engineOpenMidi).map { Optional($0) },
                              stringCount: instrument.stringCount,
                              rootPitchClass: rootPitchClass,
                              openMidi: instrument.engineOpenMidi,
                              keySpelling: keySpelling)
    }

    /// The bass 2-octave box for this run's scale + key on `openMidi`, box layout only (bass declares the
    /// diagonal / 3-notes-per-string layouts guitar-only). Blues/bebop passing tones need no special
    /// handling here: they already live in `scale.intervals`, so the tone ladder includes them.
    func bassBoxNotes(openMidi: [Int]) -> [FretNote] {
        BassNeckLayout.box(offsets: ScaleNeckLayout.toneOffsets(scale),
                           root: rootPitchClass, openMidi: openMidi)
    }

    /// One played cycle on bass — the box trimmed to `octaves`, reordered by the sequence pattern, then an
    /// up-and-back descent that omits the shared peak/start (mirrors the guitar `sequenceWithGroups`, minus
    /// the box-focus groups a bass box doesn't carry).
    func bassSequence(openMidi: [Int]) -> [FretNote] {
        let box = bassTrimmed(bassBoxNotes(openMidi: openMidi), toOctaves: octaves, openMidi: openMidi)
        let (ascent, _) = sequencePattern.apply(to: box, groups: nil)
        guard roundTrip, ascent.count > 2 else { return ascent }
        let descent = Array(ascent.indices.dropFirst().dropLast().reversed()).map { ascent[$0] }
        return ascent + descent
    }

    /// Keep a bass run to `octaves` octaves — the whole box for two, its lower octave for one — measured
    /// with the bass string layout (the guitar `CAGEDShape.trimmed` measures with guitar open MIDI).
    private func bassTrimmed(_ notes: [FretNote], toOctaves octaves: Int, openMidi: [Int]) -> [FretNote] {
        guard octaves < 2, let low = notes.first.map({ BassNeckLayout.midi($0, openMidi: openMidi) }) else {
            return notes
        }
        return notes.filter { BassNeckLayout.midi($0, openMidi: openMidi) <= low + 12 }
    }

    /// MIDI notes the editor's **Hear** sounds, in playing order, for `instrument` — guitar and bass both
    /// resolve through `Instrument.midi(of:)` (guitar's is byte-identical to `CAGEDShape.midi`).
    func heardMidi(for instrument: Instrument) -> [Int] {
        let notes = instrument == .guitar ? sequence : bassSequence(openMidi: instrument.engineOpenMidi)
        return notes.map { instrument.midi(of: $0) }
    }

    /// How many neck positions the editor offers for `instrument` — the guitar layout's count, or bass's
    /// single canonical box (ADR 0116). Drives the position stepper's range.
    func positionCount(for instrument: Instrument) -> Int {
        instrument == .guitar ? positionCount : BassNeckLayout.positionCount
    }

    /// The player-facing position label for `instrument` — the guitar `positionLabel`, or the bass box's
    /// root anchor ("root: open E").
    func positionLabel(for instrument: Instrument) -> String {
        guard instrument != .guitar else { return positionLabel }
        let openMidi = instrument.engineOpenMidi
        return BassNeckLayout.rootAnchor(in: bassBoxNotes(openMidi: openMidi),
                                         root: rootPitchClass, openMidi: openMidi)
    }

    /// Whether the current position is the flagship "most-common" box for `instrument` — the single bass
    /// box always is.
    func isMostCommon(for instrument: Instrument) -> Bool {
        instrument == .guitar ? isMostCommon : true
    }

    /// The lowest fretted fret of the run for `instrument` — shown as "from fret N" in the subtitle.
    func anchorFret(for instrument: Instrument) -> Int {
        guard instrument != .guitar else { return anchorFret }
        return bassBoxNotes(openMidi: instrument.engineOpenMidi).map(\.fret).filter { $0 > 0 }.min() ?? 1
    }
}

// MARK: - Curated default (T8)

extension ScaleRun {
    /// The starter scale a freshly-created Scales drill opens on — **A minor pentatonic**, two octaves,
    /// on its **flagship box**: the famous 5th-fret box with the root on the low E (the G-shape /
    /// position 5, not position 1 — ADR 0091), so a new drill opens on the shape everyone knows.
    static let aMinorPentatonic = ScaleRun(
        scale: .minorPentatonic, rootPitchClass: 9,
        position: CAGEDShape.flagshipPosition(
            root: 9,
            relativeMajorSemitones: GuitarScale.minorPentatonic.relativeMajorSemitones,
            degrees: GuitarScale.minorPentatonic.degrees),
        octaves: 2)

    /// The **extended** A minor pentatonic (ADR 0083 S4) — the A-G-slide diagonal (shape 1 of the two
    /// canonical fingerings), three boxes stitched into one climb by whole-step slides on the A and G
    /// strings. The flagship for the diagonal layout.
    static let aMinorPentatonicExtended = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                                                   position: 1, layout: .extended)

    /// The **3-notes-per-string** G major scale (ADR 0083 S4) — the diatonic neck-spanning drill, three
    /// tones on every string from the low E up. The flagship for the 3-NPS layout.
    static let gMajorThreePerString = ScaleRun(scale: .major, rootPitchClass: 7,
                                               position: 1, layout: .threePerString)

    /// The **G major scale in 3rds** (ADR 0108) — the box run reordered into melodic thirds
    /// (1 3 2 4 3 5 …), the classic pattern drill. The flagship for the sequence axis.
    static let gMajorInThirds = ScaleRun(scale: .major, rootPitchClass: 7,
                                         position: 1, octaves: 2, sequence: .thirds)

    /// The starter scale a freshly-created **bass** Scales drill opens on (ADR 0116) — **E minor
    /// pentatonic**, two octaves, opening on the open low-E string: the first scale most bassists learn.
    /// The recipe is instrument-agnostic (instrument lives on the `Exercise`); this is just the key/scale
    /// that renders cleanly on the four-string box.
    static let eMinorPentatonicBass = ScaleRun(scale: .minorPentatonic, rootPitchClass: 4, octaves: 2)
}
