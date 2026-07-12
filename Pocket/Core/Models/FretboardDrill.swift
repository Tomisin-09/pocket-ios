import Foundation

/// How a fretboard note is sounded (ADR 0065) — carried on each note so a legato run can show a
/// hammer-on/pull-off differently from a picked note, and so the accessibility read is honest.
/// Generic common-practice vocabulary (T8), never anyone's protected expression. Optional on a
/// note: `nil` means an ordinary picked/struck note, the common case, so most drills stay terse.
enum FretTechnique: String, CaseIterable, Identifiable, Codable {
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
struct FretNote: Codable, Equatable {
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

    init(notesPerBeat: Int,
         notes: [FretNote?],
         stringCount: Int = 6,
         rootPitchClass: Int? = nil,
         version: Int = FretboardDrill.currentVersion) {
        self.version = version
        self.notesPerBeat = max(1, notesPerBeat)
        self.notes = notes
        self.stringCount = max(1, stringCount)
        self.rootPitchClass = rootPitchClass.map { (($0 % 12) + 12) % 12 }
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
}

// MARK: - Display window (pure — derived from the notes, so the payload stays lean)

/// The visible slice of neck the board draws: `lowestFret` is the leftmost fret **column**, `span`
/// the number of columns. A plain value so the following-viewport math (ADR 0083 S5) stays pure and
/// unit-testable, and both the model and the renderer read the same window.
struct FretWindow: Equatable {
    var lowestFret: Int
    var span: Int
}

extension FretboardDrill {
    /// The widest a run stays legible without following (ADR 0083 S5), and the width of the following
    /// window itself. A drill whose fretted span fits in this many columns keeps the static full
    /// window — a gentle climb (e.g. a +1-per-pass warm-up living inside ~7 frets) never scrolls; only
    /// a genuine neck-climb wider than this follows the hand while it walks.
    static let comfortableFretSpan = 8
    /// How close (in frets) the active note may get to a window edge before the window scrolls to keep
    /// it in view (ADR 0083 S5). The window holds completely still until this margin is breached, so it
    /// never moves while the note is comfortably mid-board — the "only scroll when you have to" rule.
    static let followEdgeMargin = 1
    /// How many frets of already-played neck the following window keeps **behind** the active note when
    /// it scrolls (ADR 0083 S5) — kept deliberately small: a climbing hand reads the frets *ahead*, so
    /// after a scroll the note sits near the trailing edge and most of the window is the runway to come.
    /// Fewer trailing frets ⇒ more look-ahead ⇒ the note travels further before the next scroll, so the
    /// board reframes less often. Nonzero so a sliver of context survives the reframe.
    static let followTrailing = 1

    /// The fretted (non-open) fret numbers the drill actually uses.
    private var frettedNumbers: [Int] { notes.compactMap { $0?.fret }.filter { $0 > 0 } }

    /// The lowest fret **column** the board shows — the lowest fretted note, at least 1. Open notes
    /// (fret 0) sit on the nut to the left of this and don't pull the window down.
    var displayLowestFret: Int {
        guard let low = frettedNumbers.min() else { return 1 }
        return max(1, low)
    }

    /// How many fret **columns** the board shows — enough to reach the highest fretted note, but at
    /// least a comfortable four so a two-fret drill isn't a cramped sliver.
    var displayFretSpan: Int {
        guard let high = frettedNumbers.max() else { return 4 }
        return max(4, high - displayLowestFret + 1)
    }

    /// The visible neck window given the currently-active note (ADR 0083 S5 — the following viewport).
    ///
    /// **At rest / animate-off (`activeIndex == nil`), or a run that already fits `comfortableFretSpan`,
    /// keep today's static full window** — the whole shape reads as a reference diagram, and a gentle
    /// climb that lives inside a comfortable board never scrolls at all. **Only a genuine neck-climb
    /// wider than that, while it walks,** follows the hand — and it follows by the *"only scroll when
    /// you have to"* rule: the window holds completely still until the active note comes within
    /// `followEdgeMargin` of an edge, then scrolls just enough to bring it back with `followLead` frets
    /// of runway ahead and the rest of the window as already-played history. It therefore never moves
    /// while the note is comfortably mid-board (the confusing case an earlier paged version produced).
    ///
    /// The window has memory (where it scrolled to last frame), but the whole thing stays a pure
    /// `fn(activeIndex)`: the walk is deterministic, so the window is recovered by folding the scroll
    /// rule over the notes from the start of the cycle up to the active one — no view state, still
    /// exhaustively unit-tested (S6), and the loop wrap (top of the climb → back to the bottom) falls
    /// out for free because the fold restarts at note 0.
    func displayWindow(activeIndex: Int?) -> FretWindow {
        let staticLow = displayLowestFret
        let staticSpan = displayFretSpan
        guard let activeIndex, noteCount > 0, staticSpan > Self.comfortableFretSpan else {
            return FretWindow(lowestFret: staticLow, span: staticSpan)
        }
        let width = Self.comfortableFretSpan
        let staticHigh = staticLow + staticSpan - 1
        let maxLow = max(staticLow, staticHigh - width + 1)   // never scroll past the run's own content
        let target = ((activeIndex % noteCount) + noteCount) % noteCount
        var low = staticLow                                   // the window starts anchored at the bottom
        for index in 0...target {
            let fret = followedFret(activeIndex: index) ?? low
            low = scrolled(low: low, toShow: fret, width: width, minLow: staticLow, maxLow: maxLow)
        }
        return FretWindow(lowestFret: low, span: width)
    }

    /// The scroll rule (ADR 0083 S5): keep the window put unless `fret` is within `followEdgeMargin` of
    /// an edge, in which case scroll so the note lands `followTrailing` frets in from the edge it is
    /// *leaving* — a little history behind, the rest of the window the runway it is heading into (so it
    /// travels far before scrolling again). Pure and total, clamped to `[minLow, maxLow]`.
    private func scrolled(low: Int, toShow fret: Int, width: Int, minLow: Int, maxLow: Int) -> Int {
        let high = low + width - 1
        if fret > high - Self.followEdgeMargin {           // climbing → reached the right edge; scroll up
            return min(maxLow, fret - Self.followTrailing)
        }
        if fret < low + Self.followEdgeMargin {            // descending → reached the left edge; scroll down
            return max(minLow, fret - (width - 1 - Self.followTrailing))
        }
        return low                                         // comfortably in view → hold
    }

    /// The fret the following window tracks: the active note's own fret when it is fretted, else the
    /// nearest fretted note on either side (so a rest or open string doesn't jerk the window). `nil`
    /// only when the drill has no fretted note at all.
    private func followedFret(activeIndex: Int) -> Int? {
        guard noteCount > 0 else { return nil }
        if let active = note(at: activeIndex), active.fret > 0 { return active.fret }
        for offset in 1...noteCount {
            if let back = note(at: activeIndex - offset), back.fret > 0 { return back.fret }
            if let forward = note(at: activeIndex + offset), forward.fret > 0 { return forward.fret }
        }
        return nil
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
                              stringCount: stringCount, rootPitchClass: rootPitchClass, version: version)
    }

    /// The drill re-gridded to a new resolution over `beatsPerBar` — `beatsPerBar * notesPerBeat`
    /// slots — remapping existing notes **by beat position**, not by raw array index (the same fix
    /// `StrumPattern.resized` carries). Each new slot inherits the old note that fell on the *same*
    /// beat offset; positions between old notes become rests. Refining keeps notes on their beats;
    /// coarsening keeps the on-beat notes and drops the sub-beat ones (an inherent, deliberate
    /// downsample), so visiting a coarser resolution and returning never wipes the tail.
    func resized(notesPerBeat newNotesPerBeat: Int, beatsPerBar: Int) -> FretboardDrill {
        let perBeat = max(1, newNotesPerBeat)
        let oldPerBeat = max(1, notesPerBeat)
        let count = max(1, beatsPerBar) * perBeat
        var resizedNotes: [FretNote?] = Array(repeating: nil, count: count)
        for newIndex in 0..<count {
            let oldPosition = Double(newIndex) * Double(oldPerBeat) / Double(perBeat)
            let rounded = oldPosition.rounded()
            guard abs(oldPosition - rounded) < 0.0001 else { continue }
            let oldIndex = Int(rounded)
            if notes.indices.contains(oldIndex) { resizedNotes[newIndex] = notes[oldIndex] }
        }
        return FretboardDrill(notesPerBeat: perBeat, notes: resizedNotes,
                              stringCount: stringCount, rootPitchClass: rootPitchClass, version: version)
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
}
