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
    /// Evenly-spaced notes per beat — **quarters by default**, so a new run states the plainest
    /// rhythm and the player raises it deliberately. Clamped to at least 1.
    var notesPerBeat: Int
    /// Whether the run begins on the box's **lowest root** — the tonic the arpeggio is named for —
    /// rather than on whichever chord tone sits lowest in the box (2026-07-28). Stored on the recipe and
    /// never read at render time, with split defaults: `true` for a run created now, decode-defaulting
    /// to `false` so nothing already saved reorders itself. Mirrors `ScaleRun.startsFromLowestRoot`.
    var startsFromLowestRoot: Bool

    /// The decoded quality — unknown raw falls back to the minor seventh.
    var quality: ArpeggioQuality { ArpeggioQuality(storage: qualityRaw) }

    init(quality: ArpeggioQuality,
         rootPitchClass: Int,
         position: Int = 1,
         octaves: Int = 2,
         roundTrip: Bool = true,
         notesPerBeat: Int = 1,
         startsFromLowestRoot: Bool = true,
         version: Int = ArpeggioRun.currentVersion) {
        self.version = version
        self.qualityRaw = quality.rawValue
        self.rootPitchClass = (((rootPitchClass % 12) + 12) % 12)
        self.position = min(max(1, position), CAGEDShape.allCases.count)
        self.octaves = min(2, max(1, octaves))
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
        self.startsFromLowestRoot = startsFromLowestRoot
    }

    private enum CodingKeys: String, CodingKey {
        case version, qualityRaw, rootPitchClass, position, octaves, roundTrip, notesPerBeat
        case startsFromLowestRoot
    }

    /// Custom decode so `startsFromLowestRoot` defaults when absent (T4 — decode-time default, no store
    /// migration); an older blob missing it plays in exactly the order it always did.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        qualityRaw = try container.decode(String.self, forKey: .qualityRaw)
        rootPitchClass = (((try container.decode(Int.self, forKey: .rootPitchClass) % 12) + 12) % 12)
        position = min(max(1, try container.decode(Int.self, forKey: .position)), CAGEDShape.allCases.count)
        octaves = min(2, max(1, try container.decode(Int.self, forKey: .octaves)))
        roundTrip = try container.decode(Bool.self, forKey: .roundTrip)
        notesPerBeat = max(1, try container.decode(Int.self, forKey: .notesPerBeat))
        startsFromLowestRoot = try container.decodeIfPresent(Bool.self, forKey: .startsFromLowestRoot) ?? false
    }
}

// MARK: - Naming (pure)

extension ArpeggioRun {
    /// The tonic's note name, **spelled by the arpeggio's own key** (ADR 0123), e.g. "A", or "B♭" —
    /// never "A♯" — for a run rooted there. Like a scale run, an arpeggio is a tonal centre, so the
    /// key answers and the user's accidental preference is not consulted.
    var rootName: String { (keySpelling ?? .default).name(pitchClass: rootPitchClass) }

    /// The spelling this run's key implies (ADR 0123), or `nil` at the C and F♯/G♭ positions the
    /// circle leaves open, where the accidental preference takes over.
    var keySpelling: NoteSpelling? { NoteSpelling.forArpeggio(quality, root: rootPitchClass) }

    /// The full run title, e.g. "A Minor 7".
    var title: String { "\(rootName) \(quality.displayName)" }

    /// The number of CAGED positions offered — always the five boxes.
    var positionCount: Int { CAGEDShape.allCases.count }

    /// The lowest fret the current position's box occupies — shown as "Anchored at fret N". Reads the
    /// whole box, so "start from the lowest root" moves where the run *begins* without relabelling where
    /// the hand *sits*.
    var anchorFret: Int { boxNotes.map(\.fret).min() ?? 1 }

    /// The player-facing name for the current position — the box's **root anchor** (ADR 0091), "root on
    /// low E · fret 5", where the hand goes, in place of a CAGED letter or box number.
    var positionLabel: String { rootAnchor }

    /// The CAGED reference letter for the current position (E/D/C/A/G). Demoted to a secondary caption
    /// (ADR 0091): it's the letter of the box in the *relative-major* key, not the letter a player names
    /// relative to the tonic — kept for CAGED readers, but no longer the primary position label.
    var shapeLetter: String { CAGEDShape(clampedPosition: position).shapeLetter }

    /// A plain-language location for the current box (ADR 0091), e.g. "root on low E · fret 5" — where
    /// the box's lowest root note actually sits, shown under the box number in place of the CAGED letter.
    var rootAnchor: String { CAGEDShape.rootAnchor(in: boxNotes, root: rootPitchClass) }

    /// The flagship box for this quality/key — the root-position 6th-string box a player learns first
    /// (ADR 0091), computed per quality so it tracks the famous box whatever the CAGED offset.
    var flagshipPosition: Int {
        CAGEDShape.flagshipPosition(root: rootPitchClass,
                                    relativeMajorSemitones: quality.relativeMajorSemitones,
                                    degrees: quality.degrees)
    }

    /// Whether the current position is the flagship **most-common** box — drives the "Most common" badge.
    var isMostCommon: Bool { position == flagshipPosition }
}

// MARK: - Generation (pure — shared CAGED box, filtered to the chord tones)

extension ArpeggioRun {
    /// The chosen CAGED box, placed in this run's key and filtered to the chord tones.
    var boxNotes: [FretNote] {
        CAGEDShape.filteredBox(position: position, root: rootPitchClass,
                               relativeMajorSemitones: quality.relativeMajorSemitones,
                               degrees: quality.degrees)
    }

    /// The ascending run: the full box for two octaves, or its lower octave for one — begun on the box's
    /// lowest root when the run asks for it. Aligned *before* the octave trim, so a one-octave run spans a
    /// true root-to-root octave instead of a partial one above a dropped low chord tone.
    var ascendingNotes: [FretNote] {
        let placed = startsFromLowestRoot
            ? CAGEDShape.startingAtLowestRoot(boxNotes, root: rootPitchClass)
            : boxNotes
        return CAGEDShape.trimmed(placed, toOctaves: octaves)
    }

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
                       rootPitchClass: rootPitchClass,
                       keySpelling: keySpelling)
    }
}

// MARK: - Bass generation + instrument-aware accessors (ADR 0116 Slice 3)

extension ArpeggioRun {
    /// The rendered drill for a given **instrument** (ADR 0116) — guitar routes to the untouched
    /// `expanded()` above (byte-identical); bass lays a 2-octave `BassNeckLayout` box of the chord tones on
    /// the four strings. The stored recipe is unchanged — instrument comes from the owning `Exercise`.
    func expanded(instrument: Instrument) -> FretboardDrill {
        guard instrument != .guitar else { return expanded() }
        return FretboardDrill(notesPerBeat: notesPerBeat,
                              notes: bassSequence(openMidi: instrument.engineOpenMidi).map { Optional($0) },
                              stringCount: instrument.stringCount,
                              rootPitchClass: rootPitchClass,
                              openMidi: instrument.engineOpenMidi,
                              keySpelling: keySpelling)
    }

    /// The bass 2-octave chord-tone box for this run's quality + key on `openMidi` — the same
    /// `BassNeckLayout.box` the scales use, filtered to the chord tones instead of a scale (an arpeggio is
    /// just a smaller tone set).
    func bassBoxNotes(openMidi: [Int]) -> [FretNote] {
        BassNeckLayout.box(offsets: quality.degrees.sorted(),
                           root: rootPitchClass, openMidi: openMidi)
    }

    /// One played cycle on bass — the box, then (when `roundTrip`) an up-and-back descent omitting the
    /// shared peak/start (mirrors the guitar `sequence`). Bass arpeggios are box-only; `octaves` is folded
    /// into the box's two-octave span.
    func bassSequence(openMidi: [Int]) -> [FretNote] {
        let ascent = bassBoxNotes(openMidi: openMidi)
        guard roundTrip, ascent.count > 2 else { return ascent }
        return ascent + Array(ascent.dropFirst().dropLast().reversed())
    }

    /// MIDI notes the editor's **Hear** sounds, in playing order, for `instrument`.
    func heardMidi(for instrument: Instrument) -> [Int] {
        let notes = instrument == .guitar ? sequence : bassSequence(openMidi: instrument.engineOpenMidi)
        return notes.map { instrument.midi(of: $0) }
    }

    /// How many neck positions the editor offers for `instrument` — the five CAGED boxes, or bass's single
    /// canonical box (ADR 0116).
    func positionCount(for instrument: Instrument) -> Int {
        instrument == .guitar ? positionCount : BassNeckLayout.positionCount
    }

    /// The position label for `instrument` — the guitar box's root anchor, or the bass box's.
    func positionLabel(for instrument: Instrument) -> String {
        guard instrument != .guitar else { return positionLabel }
        let openMidi = instrument.engineOpenMidi
        return BassNeckLayout.rootAnchor(in: bassBoxNotes(openMidi: openMidi),
                                         root: rootPitchClass, openMidi: openMidi)
    }

    /// Whether the current position is the flagship box for `instrument` — the single bass box always is.
    func isMostCommon(for instrument: Instrument) -> Bool {
        instrument == .guitar ? isMostCommon : true
    }

    /// The lowest fretted fret of the run for `instrument` — shown as "from fret N".
    func anchorFret(for instrument: Instrument) -> Int {
        guard instrument != .guitar else { return anchorFret }
        return bassBoxNotes(openMidi: instrument.engineOpenMidi).map(\.fret).filter { $0 > 0 }.min() ?? 1
    }
}

// MARK: - Curated default (T8)

extension ArpeggioRun {
    /// The starter arpeggio a freshly-created Arpeggios drill opens on — **A minor 7**, two octaves, on
    /// its **flagship box**: the root-position box with the root on the low E (ADR 0091), so a new drill
    /// opens on the shape a player anchors to first.
    static let aMinorSeventh = ArpeggioRun(
        quality: .minorSeventh, rootPitchClass: 9,
        position: CAGEDShape.flagshipPosition(
            root: 9,
            relativeMajorSemitones: ArpeggioQuality.minorSeventh.relativeMajorSemitones,
            degrees: ArpeggioQuality.minorSeventh.degrees),
        octaves: 2)

    /// The starter arpeggio a freshly-created **bass** Arpeggios drill opens on (ADR 0116) — **E minor 7**,
    /// opening on the open low-E string. Instrument-agnostic recipe; instrument lives on the `Exercise`.
    static let eMinorSeventhBass = ArpeggioRun(quality: .minorSeventh, rootPitchClass: 4, octaves: 2)
}
