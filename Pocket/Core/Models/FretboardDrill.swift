import Foundation

/// How a fretboard note is sounded (ADR 0065) — carried on each note so a legato run can show a
/// hammer-on/pull-off differently from a picked note, and so the accessibility read is honest.
/// Generic common-practice vocabulary (T8), never anyone's protected expression. Optional on a
/// note: `nil` means an ordinary picked/struck note, the common case, so most drills stay terse.
enum FretTechnique: String, CaseIterable, Identifiable, Codable, Hashable {
    /// Struck normally with the pick / finger — the default when a note carries no technique.
    case pick
    /// Sounded by hammering the fretting finger down without picking (legato).
    case hammerOn
    /// Sounded by pulling the fretting finger off to a lower note (legato).
    case pullOff
    /// Sounded by sliding into the note from an adjacent fret.
    case slide

    var id: String { rawValue }

    /// Short spoken/label form for accessibility and any future badge.
    var label: String {
        switch self {
        case .pick: return "Pick"
        case .hammerOn: return "Hammer-on"
        case .pullOff: return "Pull-off"
        case .slide: return "Slide"
        }
    }
}

/// One note in a fretboard drill: which `string` (0 = high e … 5 = low E, top-to-bottom as a tab
/// staff reads) and which `fret` (0 = open), with an optional articulation. A plain value so the
/// timing math over a sequence of these stays pure (T5).
struct FretNote: Codable, Equatable, Hashable {
    /// 0 = high e (top row) … 5 = low E (bottom row). Matches how a tab staff and the renderer stack
    /// the strings.
    var string: Int
    /// Absolute fret number; 0 = open string.
    var fret: Int
    /// How the note is sounded; `nil` reads as an ordinary picked note.
    var technique: FretTechnique?

    init(string: Int, fret: Int, technique: FretTechnique? = nil) {
        self.string = string
        self.fret = fret
        self.technique = technique
    }
}

/// A **fretboard template's** content (ADR 0065 T4): a small, self-contained *recipe* of notes laid
/// on an evenly-spaced beat grid — the shared surface for warm-ups (spider walks), scales, picking
/// and legato runs (ADR 0065 build 2, "build once, reuse many"). Persisted as the opaque
/// `Exercise.templatePayload: Data?` blob, never a child `@Model`, because the payload is never
/// relationally queried; it carries its own `version` so the schema evolves with a decode-time
/// upgrade and no store migration (T4).
///
/// **Grid, not free beats.** The drills the fretboard serves are even runs — one note per
/// subdivision — so this narrows ADR 0065 T4's `{string, fret, beat}` events to an evenly-gridded
/// list (`beat = index / notesPerBeat`), reusing the exact wrap/active-index timing proven for
/// `StrumPattern`. Arbitrary-beat events are deferred until a drill actually needs an uneven rhythm.
/// Which note is sounding at a moment is **pure timing math** (`activeNoteIndex(atBeat:)`),
/// SwiftUI-free and unit-tested (T5); the fretboard view is only a skin over it.
struct FretboardDrill: Codable, Equatable {
    /// The schema version this build writes. Bump when the encoded shape changes, and add a
    /// decode-time upgrade rather than a store migration (T4).
    static let currentVersion = 1

    /// The version the blob was encoded at — for a future decode-time upgrade. A blob from a newer
    /// build best-effort decodes; if it can't, `Exercise`'s accessor returns nil and the run falls
    /// back to the metronome renderer (T5).
    var version: Int
    /// Evenly-spaced notes per beat — 1 = one per beat, 2 = eighths, 3 = triplets, 4 = sixteenths.
    /// Clamped to at least 1 so the grid never divides by zero.
    var notesPerBeat: Int
    /// One cycle of notes, in order. `nil` is a rest — the hand keeps time but nothing sounds — so
    /// the grid can carry gaps like `StrumPattern`'s rests.
    var notes: [FretNote?]
    /// How many strings the board draws (6 for standard guitar). Stored so a future 7-string or bass
    /// drill round-trips; clamped to at least 1.
    var stringCount: Int
    /// The **root pitch class** (0 = C … 11 = B) when the drill has a tonal centre — a scale or
    /// arpeggio run sets it so the renderer can light the root notes; a spider walk or picking
    /// pattern leaves it `nil` (no root to mark). Optional so legacy blobs decode unchanged.
    var rootPitchClass: Int?
    /// The **pass index** each note belongs to (ADR 0083 S2b — "pass focus"), parallel to `notes` and
    /// the same length: a multi-pass climbing run tags every note with the pass that emitted it, so the
    /// renderer can keep the pass being played at full strength and fade the others to a ghost. `nil`
    /// for every non-run drill (scales, arpeggios, custom hand-authored) and for a single-pass run's
    /// callers that don't populate it; a single-pass run fills one uniform group, which reads as "no
    /// dimming." **Transient — never encoded** (omitted from `CodingKeys`): it is a pure generation
    /// artifact re-derived on each `expanded()`, so there is no persisted-shape change and no store
    /// migration, and a decoded drill always comes back `nil` (an implicitly-`nil` optional, which the
    /// synthesized `Decodable` uses as the default for the omitted key).
    var noteGroups: [Int]?
    /// The open-string MIDI the board is tuned to, **highest-first** — the instrument's tuning when this
    /// drill was generated for one (ADR 0116 S5), else `nil` ⇒ guitar. The renderer resolves each note's
    /// pitch class / root against it, so a bass board labels in bass tuning. **Transient — never encoded**
    /// (omitted from `CodingKeys`, like `noteGroups`): a pure render concern the generator and
    /// `FretboardContent.drill(instrument:)` stamp on, so no persisted-shape change; a decoded `.custom`
    /// bass drill is re-stamped from its exercise's instrument at render time.
    var openMidi: [Int]?

    init(notesPerBeat: Int,
         notes: [FretNote?],
         stringCount: Int = 6,
         rootPitchClass: Int? = nil,
         noteGroups: [Int]? = nil,
         openMidi: [Int]? = nil,
         version: Int = FretboardDrill.currentVersion) {
        self.version = version
        self.notesPerBeat = max(1, notesPerBeat)
        self.notes = notes
        self.stringCount = max(1, stringCount)
        self.rootPitchClass = rootPitchClass.map { (($0 % 12) + 12) % 12 }
        self.noteGroups = noteGroups
        self.openMidi = openMidi
    }

    /// Explicit keys so `noteGroups` and `openMidi` (transient render artifacts) are **excluded** from
    /// the encoded shape — no persisted-blob change, no migration. Every other field codes and decodes
    /// exactly as the synthesized conformance did before; the two transients decode to their `nil`
    /// default.
    private enum CodingKeys: String, CodingKey {
        case version, notesPerBeat, notes, stringCount, rootPitchClass
    }

    /// Guitar standard open MIDI, highest-first — the default tuning labels resolve against when
    /// `openMidi` is unset. Byte-identical (mod 12) to `GuitarScale.openPitchClass`, so a guitar board is
    /// unchanged; equals `Instrument.guitar.engineOpenMidi` / `CAGEDShape.openMidi`.
    static let guitarOpenMidi = [64, 59, 55, 50, 45, 40]

    /// The tuning this drill's labels resolve against — its stamped `openMidi`, or guitar standard.
    var resolvedOpenMidi: [Int] { openMidi ?? Self.guitarOpenMidi }

    /// The pitch class (0…11) a note sounds on this drill's tuning — the tuning-aware replacement for the
    /// guitar-hardcoded `GuitarScale.pitchClass(string:fret:)` the renderer used, so bass note names,
    /// intervals and root rings land on the right notes (ADR 0116 S5). Guitar resolves identically.
    func pitchClass(of note: FretNote) -> Int {
        let open = resolvedOpenMidi
        guard !open.isEmpty else { return ((note.fret % 12) + 12) % 12 }
        let index = min(max(0, note.string), open.count - 1)
        return (((open[index] + note.fret) % 12) + 12) % 12
    }
}

// MARK: - Pure note-timing math (T5 — SwiftUI-free, unit-tested; mirrors StrumPattern)

extension FretboardDrill {
    /// Number of notes (including rests) in one cycle.
    var noteCount: Int { notes.count }

    /// Length of one cycle in beats — `noteCount / notesPerBeat`. An eight-note eighths run is four
    /// beats (one 4/4 bar).
    var lengthInBeats: Double {
        noteCount > 0 ? Double(noteCount) / Double(max(1, notesPerBeat)) : 0
    }

    /// The beat offset (from the start of the cycle) at which a note begins.
    func beatOffset(ofNote index: Int) -> Double {
        Double(index) / Double(max(1, notesPerBeat))
    }

    /// Which note index is sounding at a continuous beat position — beats elapsed since the run's
    /// beat anchor. The cycle **wraps**: position `lengthInBeats` returns to note 0. A negative
    /// position (the count-in, before beat 0) and an empty drill both return `nil` — nothing lit.
    /// Pure and total, so it is exhaustively unit-tested and the view only draws its result.
    func activeNoteIndex(atBeat beatPosition: Double) -> Int? {
        guard noteCount > 0, beatPosition >= 0, beatPosition.isFinite else { return nil }
        let absolute = Int((beatPosition * Double(max(1, notesPerBeat))).rounded(.down))
        return absolute % noteCount
    }

    /// The note at an index, wrapping. `nil` for a rest slot, an out-of-range index on an empty
    /// drill, or a wrapped hit on a rest. Safe for any index.
    func note(at index: Int) -> FretNote? {
        guard noteCount > 0 else { return nil }
        let wrapped = ((index % noteCount) + noteCount) % noteCount
        return notes[wrapped]
    }

    /// Each **distinct board position** the run touches, in first-played order, paired with every slot
    /// index that plays it.
    ///
    /// The renderer plots *positions*, not *events*: a run can sound the same fret many times over, and
    /// drawing one translucent dot per played slot stacked their alpha until a note the sequence hit
    /// four times read as solid white while one it hit twice read as greyed out — the "dots grey out
    /// when a sequence is picked" report (device repro 2026-07-28: A minor pentatonic, box layout,
    /// Straight vs Groups of 4). `SequencePattern.byGroup` emits each note up to four times, so the
    /// brightness was tracking *how often the rolling window happened to include a note*, which is not
    /// information anyone asked to see. Rests are skipped; the paired indices let the renderer keep the
    /// per-index concerns it still needs — which position is lit now, and ADR 0083 pass focus.
    var plottedPositions: [(note: FretNote, indices: [Int])] {
        var order: [FretNote] = []
        var indicesByNote: [FretNote: [Int]] = [:]
        for (index, note) in notes.enumerated() {
            guard let note else { continue }
            if indicesByNote[note] == nil { order.append(note) }
            indicesByNote[note, default: []].append(index)
        }
        return order.map { ($0, indicesByNote[$0] ?? []) }
    }
}

// MARK: - Editing (pure — the authoring editor is a thin skin over these, T5; mirrors StrumPattern)

extension FretboardDrill {
    /// The drill with the slot at `index` set to `note` (a `FretNote` to place one, `nil` to clear it
    /// to a rest). Out-of-range indices return the drill unchanged. Pure, so the editor just maps a
    /// tap to this and redraws.
    func replacingNote(at index: Int, with note: FretNote?) -> FretboardDrill {
        guard notes.indices.contains(index) else { return self }
        var updated = notes
        updated[index] = note
        return FretboardDrill(notesPerBeat: notesPerBeat, notes: updated,
                              stringCount: stringCount, rootPitchClass: rootPitchClass,
                              openMidi: openMidi, version: version)
    }

    /// Every slot reset to a rest, **preserving the grid** — subdivision, length, string count, and root
    /// are untouched, only the placed notes clear. Backs the editor's "Clear taps": it wipes what the
    /// player tapped without disturbing the drill's shape or any overlaid scale guide (device feedback,
    /// 2026-07-23).
    func cleared() -> FretboardDrill {
        FretboardDrill(notesPerBeat: notesPerBeat,
                       notes: Array(repeating: nil, count: notes.count),
                       stringCount: stringCount, rootPitchClass: rootPitchClass,
                       openMidi: openMidi, version: version)
    }

    /// True when no slot holds a note (every slot is a rest) — the editor disables Clear/Undo when there's
    /// nothing to remove.
    var hasNoNotes: Bool { notes.allSatisfy { $0 == nil } }

    /// How many whole bars the placed notes span, given the exercise meter — `notes.count ÷ (beats ×
    /// subdivision)`, at least one. Backs the editor's Bars stepper and keeps a subdivision change from
    /// silently collapsing a multi-bar drill to one bar.
    func barCount(beatsPerBar: Int) -> Int {
        let perBar = max(1, notesPerBeat) * max(1, beatsPerBar)
        return max(1, notes.count / perBar)
    }

    /// The drill re-gridded to a new resolution over `beatsPerBar`, **preserving its bar count** —
    /// remapping existing notes **by beat position**, not by raw array index (the same fix
    /// `StrumPattern.resized` carries). Each new slot inherits the old note that fell on the *same*
    /// beat offset; positions between old notes become rests. Refining keeps notes on their beats;
    /// coarsening keeps the on-beat notes and drops the sub-beat ones (an inherent, deliberate
    /// downsample), so visiting a coarser resolution and returning never wipes the tail. A one-bar drill
    /// stays one bar; an N-bar drill stays N bars.
    func resized(notesPerBeat newNotesPerBeat: Int, beatsPerBar: Int) -> FretboardDrill {
        let perBeat = max(1, newNotesPerBeat)
        let oldPerBeat = max(1, notesPerBeat)
        let bars = barCount(beatsPerBar: beatsPerBar)
        let count = max(1, beatsPerBar) * perBeat * bars
        var resizedNotes: [FretNote?] = Array(repeating: nil, count: count)
        for newIndex in 0..<count {
            let oldPosition = Double(newIndex) * Double(oldPerBeat) / Double(perBeat)
            let rounded = oldPosition.rounded()
            guard abs(oldPosition - rounded) < 0.0001 else { continue }
            let oldIndex = Int(rounded)
            if notes.indices.contains(oldIndex) { resizedNotes[newIndex] = notes[oldIndex] }
        }
        return FretboardDrill(notesPerBeat: perBeat, notes: resizedNotes,
                              stringCount: stringCount, rootPitchClass: rootPitchClass,
                              openMidi: openMidi, version: version)
    }

    /// The drill grown or shrunk to `bars` whole bars at the current subdivision, **preserving placed
    /// notes by index** — growing appends rests, shrinking drops the trailing slots. Backs the editor's
    /// Bars stepper (device feedback 2026-07-23: the custom-scale canvas was capped at one bar). Bars is
    /// clamped to at least one.
    func withBarCount(_ bars: Int, beatsPerBar: Int) -> FretboardDrill {
        let perBar = max(1, notesPerBeat) * max(1, beatsPerBar)
        let count = max(1, bars) * perBar
        var updated = Array(notes.prefix(count))
        if updated.count < count { updated.append(contentsOf: Array(repeating: nil, count: count - updated.count)) }
        return FretboardDrill(notesPerBeat: notesPerBeat, notes: updated,
                              stringCount: stringCount, rootPitchClass: rootPitchClass,
                              openMidi: openMidi, version: version)
    }
}

// MARK: - Curated presets (T8 — common-practice drills, authored in-house)

extension FretboardDrill {
    /// The classic **spider walk / chromatic warm-up**: one finger per fret, 1-2-3-4 up the low E
    /// then the A string, in eighths over a 4/4 bar. Synchronises the fret and pick hands — the
    /// canonical warm-up, and the flagship that exercises the fretboard renderer (ADR 0065 build 2).
    /// Common-practice vocabulary (T8).
    static let spiderWalk: FretboardDrill = {
        let lowE = 5, aString = 4
        let notes: [FretNote?] = [
            FretNote(string: lowE, fret: 1), FretNote(string: lowE, fret: 2),
            FretNote(string: lowE, fret: 3), FretNote(string: lowE, fret: 4),
            FretNote(string: aString, fret: 1), FretNote(string: aString, fret: 2),
            FretNote(string: aString, fret: 3), FretNote(string: aString, fret: 4)
        ]
        return FretboardDrill(notesPerBeat: 2, notes: notes)
    }()

    /// A **blank canvas** — `bars` bars of rests at the given resolution, nothing placed. The starting
    /// point when a player switches a Scales drill to "draw your own" (the custom-scale canvas), so they
    /// build the run from an empty neck rather than editing a pre-filled warm-up.
    static func emptyBar(beatsPerBar: Int, notesPerBeat: Int = 2, bars: Int = 1,
                         stringCount: Int = 6, openMidi: [Int]? = nil) -> FretboardDrill {
        let count = max(1, beatsPerBar) * max(1, notesPerBeat) * max(1, bars)
        return FretboardDrill(notesPerBeat: notesPerBeat, notes: Array(repeating: nil, count: count),
                              stringCount: stringCount, openMidi: openMidi)
    }
}
