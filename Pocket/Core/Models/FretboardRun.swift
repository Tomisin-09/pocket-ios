import Foundation

/// How the descent is built when a run comes **back** (ADR 0083 S9). Only meaningful when
/// `roundTrip` is on; a no-op otherwise. Additive optional field — an older blob decodes to
/// `.retrace`, so the shipped chromatic warm-up stays byte-identical.
enum ReturnStyle: String, Codable, CaseIterable, Identifiable {
    /// The strict palindrome: the ascent note-path reversed, so each string is played **4-3-2-1** on
    /// the way down (today's, and the default).
    case retrace
    /// The ascending finger pattern **restated** per string while the strings are walked back
    /// high→low: each string still **1-2-3-4**, string order reversed.
    case restate

    var id: String { rawValue }

    /// Short spoken/label form.
    var label: String {
        switch self {
        case .retrace: return "Retrace"
        case .restate: return "Restate"
        }
    }

    /// A one-line explanation for the editor.
    var caption: String {
        switch self {
        case .retrace: return "Reverse the path — each string 4-3-2-1 coming down."
        case .restate: return "Restate the pattern — each string 1-2-3-4, strings reversed."
        }
    }
}

/// A **generated fretboard run** (ADR 0065 build 2, generative authoring) — the recipe behind a
/// warm-up / picking / legato drill, declared as a *shape* rather than placed note-by-note. The
/// player authors four small things — a **finger pattern** (e.g. 1-3-2-4), the **base fret** it
/// anchors to, the **string span** it travels, and whether it comes **back** — and this expands
/// them into the evenly-gridded `FretboardDrill` the board renders. Change the span from "low E → A"
/// to "A → e" and the whole run re-generates; nothing is moved by hand.
///
/// **Position-shifting (ADR 0083).** A run may shift its anchor fret mid-sequence, on two additive
/// axes that both default to today's static behaviour: a **horizontal climb** (`fretShiftPerPass`
/// over `passCount` passes — the whole neck-climbing run becomes one wrapping cycle) and a
/// **vertical diagonal** (`fretShiftPerString` — the pattern lands higher/lower per string). A
/// same-string seam between passes is articulated as a `.slide`; a diagonal that crosses to a new
/// string is an ordinary repositioned note, not a slide (S2).
///
/// Stored as the recipe (not the expanded notes) so a drill stays semantically editable on reopen,
/// and carried inside the versioned `FretboardContent` payload (T4 — in-band `version`, decode-time
/// upgrade, no store migration). The expansion is **pure timing/geometry math**, SwiftUI-free and
/// unit-tested (T5); the editor and run screen only skin the result.
struct FretboardRun: Codable, Equatable {
    /// The schema version this build writes. Bump when the encoded shape changes and add a
    /// decode-time upgrade rather than a store migration (T4).
    static let currentVersion = 1

    /// The highest fret a real neck reaches — generation clamps every note to it (S10).
    static let maxFret = 24

    /// The most passes the editor offers regardless of neck room — keeps a wrapping cycle sane.
    static let passCountUICap = 8

    /// The version the blob was encoded at — for a future decode-time upgrade.
    var version: Int
    /// Finger numbers in playing order, laid on each string in turn — `[1, 3, 2, 4]` is the classic
    /// spider. Finger 1 sits on `baseFret`; each higher finger is one fret up (a movable shape, so
    /// the same pattern slides anywhere on the neck). Empty means an empty run.
    var fingers: [Int]
    /// The fret finger 1 sits on — where the whole shape is anchored. Clamped to at least 1.
    var baseFret: Int
    /// The string the run starts on (0 = high e … 5 = low E). A run from a higher-numbered string to
    /// a lower one travels low→high, as a chromatic warm-up does.
    var fromString: Int
    /// The string the run ends on.
    var toString: Int
    /// Whether the run descends back after the ascent — the "up and back" of a warm-up.
    var roundTrip: Bool
    /// Evenly-spaced notes per beat — 1 = quarters, 2 = eighths (the default), 3 = triplets,
    /// 4 = sixteenths. Clamped to at least 1.
    var notesPerBeat: Int
    /// **Horizontal climb (S1):** frets the anchor moves up after each completed pass. `0` (default)
    /// keeps every pass at `baseFret` — today's behaviour.
    var fretShiftPerPass: Int
    /// How many stacked passes make up the one wrapping cycle (S1). `1` (default) is a single pass.
    var passCount: Int
    /// **Vertical diagonal (S1):** frets the anchor gains per string as the run crosses strings, so
    /// the pattern lands higher (or lower, if negative) on each successive string. `0` (default) lays
    /// the same fret on every string — today's behaviour.
    var fretShiftPerString: Int
    /// How the descent is built when `roundTrip` is on (S9). `.retrace` (default) preserves today's
    /// strict palindrome; `.restate` re-states the ascending pattern per string.
    var returnStyle: ReturnStyle

    init(fingers: [Int],
         baseFret: Int,
         fromString: Int,
         toString: Int,
         roundTrip: Bool = true,
         notesPerBeat: Int = 2,
         fretShiftPerPass: Int = 0,
         passCount: Int = 1,
         fretShiftPerString: Int = 0,
         returnStyle: ReturnStyle = .retrace,
         version: Int = FretboardRun.currentVersion) {
        self.version = version
        self.fingers = fingers
        self.baseFret = max(1, baseFret)
        self.fromString = fromString
        self.toString = toString
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
        self.fretShiftPerPass = fretShiftPerPass
        self.passCount = max(1, passCount)
        self.fretShiftPerString = fretShiftPerString
        self.returnStyle = returnStyle
    }

    private enum CodingKeys: String, CodingKey {
        case version, fingers, baseFret, fromString, toString, roundTrip, notesPerBeat
        case fretShiftPerPass, passCount, fretShiftPerString, returnStyle
    }

    /// Custom decode so the ADR 0083 shift fields default when absent (T4 — decode-time default, no
    /// store migration); an older blob missing them reproduces today's run exactly.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        fingers = try container.decode([Int].self, forKey: .fingers)
        baseFret = max(1, try container.decode(Int.self, forKey: .baseFret))
        fromString = try container.decode(Int.self, forKey: .fromString)
        toString = try container.decode(Int.self, forKey: .toString)
        roundTrip = try container.decode(Bool.self, forKey: .roundTrip)
        notesPerBeat = max(1, try container.decode(Int.self, forKey: .notesPerBeat))
        fretShiftPerPass = try container.decodeIfPresent(Int.self, forKey: .fretShiftPerPass) ?? 0
        passCount = max(1, try container.decodeIfPresent(Int.self, forKey: .passCount) ?? 1)
        fretShiftPerString = try container.decodeIfPresent(Int.self, forKey: .fretShiftPerString) ?? 0
        returnStyle = try container.decodeIfPresent(ReturnStyle.self, forKey: .returnStyle) ?? .retrace
    }
}

// MARK: - Expansion (pure — SwiftUI-free, unit-tested; the editor & renderer skin the result)

extension FretboardRun {
    /// The absolute fret a finger number lands on: finger 1 sits on `baseFret`, each higher finger
    /// one fret up. Never below 0 (an open string). The unshifted base anchor — the editor's finger
    /// chips read this; expansion uses per-pass / per-string anchors below.
    func fret(forFinger finger: Int) -> Int { clampFret(baseFret + finger - 1) }

    /// Clamp a fret to a real neck (S10): open strings stay valid at 0, nothing runs past the 24th.
    private func clampFret(_ fret: Int) -> Int { min(Self.maxFret, max(0, fret)) }

    /// The strings the run visits, in travel order, inclusive of both ends.
    private var stringPath: [Int] {
        let step = fromString <= toString ? 1 : -1
        return Array(stride(from: fromString, through: toString, by: step))
    }

    /// The ascending notes for one pass anchored at `anchor`, grouped **per string** in travel
    /// order — each successive string offset by `fretShiftPerString` (the diagonal, S1). Grouping is
    /// kept so `.restate` can re-emit whole strings on the descent.
    private func ascendingGroups(anchor: Int) -> [[FretNote]] {
        guard !fingers.isEmpty else { return [] }
        return stringPath.enumerated().map { step, string in
            let stringAnchor = anchor + step * fretShiftPerString
            return fingers.map { FretNote(string: string, fret: clampFret(stringAnchor + $0 - 1)) }
        }
    }

    /// One complete pass at `anchor` — the ascent, plus (when `roundTrip`) a descent built per
    /// `returnStyle` (S9). `.retrace` reverses the note-path (each string 4-3-2-1) omitting the
    /// shared peak and start; `.restate` re-states the ascending pattern per string walking the
    /// strings back, skipping the just-played peak string and de-duplicating the home note at the
    /// seam. Both keep the looping cycle from double-hitting a note.
    private func pass(anchor: Int) -> [FretNote] {
        let groups = ascendingGroups(anchor: anchor)
        let ascent = groups.flatMap { $0 }
        guard roundTrip, ascent.count > 2 else { return ascent }
        switch returnStyle {
        case .retrace:
            return ascent + ascent.dropFirst().dropLast().reversed()
        case .restate:
            var descent = groups.dropLast().reversed().flatMap { $0 }   // skip the peak string
            if descent.last == ascent.first { descent.removeLast() }    // de-dup the home note at the seam
            return ascent + descent
        }
    }

    /// One full cycle of notes, each paired with the **pass index** that emitted it (ADR 0083 S2b —
    /// "pass focus"). A single-pass run (the default) is one `pass`, so every note is tagged `0` — one
    /// group, which the renderer reads as "no dimming." A climbing run (`passCount` > 1 with a non-zero
    /// `fretShiftPerPass`) stacks each pass anchored one climb higher and concatenates them into the one
    /// wrapping cycle, marking the first note of a pass a `.slide` when it walks the **same string** up
    /// from where the previous pass ended (S2); every note carries its own pass index so the board can
    /// focus the pass being played. The two arrays are the same length and index-aligned by
    /// construction.
    var sequenceWithPasses: (notes: [FretNote], passes: [Int]) {
        var cycle: [FretNote] = []
        var passes: [Int] = []
        for index in 0..<max(1, passCount) {
            var notes = pass(anchor: baseFret + index * fretShiftPerPass)
            if index > 0, let previous = cycle.last, var first = notes.first,
               previous.string == first.string, previous.fret != first.fret {
                first.technique = .slide
                notes[0] = first
            }
            cycle += notes
            passes += Array(repeating: index, count: notes.count)
        }
        return (cycle, passes)
    }

    /// One full cycle of notes (the pass tags dropped) — the shape most callers and tests read.
    var sequence: [FretNote] { sequenceWithPasses.notes }

    /// Expand into the evenly-gridded `FretboardDrill` the board plays — one note per subdivision,
    /// no rests, wrapping at its own natural length (it defines its own phrase, independent of the
    /// exercise meter). Carries the per-note **pass groups** so the renderer can focus the active pass
    /// (ADR 0083 S2b); a single-pass run tags one uniform group, so nothing dims.
    func expanded() -> FretboardDrill {
        let (notes, passes) = sequenceWithPasses
        return FretboardDrill(notesPerBeat: notesPerBeat,
                              notes: notes.map { Optional($0) },
                              stringCount: 6,
                              noteGroups: passes)
    }

    /// The cap on `passCount` so the **top** pass still fits a real neck (S10): the highest finger of
    /// the last pass, including any per-string stagger, must land at or below `maxFret`. The editor
    /// uses this to refuse a pass that would fall off the board rather than silently clamp it.
    var maxPassCount: Int {
        // A climb that doesn't go up the neck can't run off the top; the editor caps its own UI max.
        guard fretShiftPerPass > 0, !fingers.isEmpty else { return Self.passCountUICap }
        let topFinger = fingers.max() ?? 1
        let stagger = max(0, (stringPath.count - 1) * max(0, fretShiftPerString))
        // baseFret + (n-1)*shift + stagger + topFinger-1 <= maxFret  ⇒  solve for n.
        let headroom = Self.maxFret - baseFret - stagger - (topFinger - 1)
        guard headroom >= 0 else { return 1 }
        return max(1, headroom / fretShiftPerPass + 1)
    }
}

// MARK: - Curated default (T8 — common-practice vocabulary, authored in-house)

extension FretboardRun {
    /// The canonical **chromatic warm-up**: one finger per fret, 1-2-3-4 up every string from the
    /// low E to the high e and back, in eighths. The starter canvas a warm-up-family drill opens on —
    /// a full, real warm-up the moment it's created, not an empty board (ADR 0065 build 2).
    static let chromaticWarmup = FretboardRun(
        fingers: [1, 2, 3, 4], baseFret: 1,
        fromString: 5, toString: 0, roundTrip: true, notesPerBeat: 2)
}

/// The **content of a fretboard-template payload** (ADR 0065 build 2): a **generated** finger-pattern
/// run (warm-up families), a preprogrammed **scale** run (Scales, Slice 2), or a **custom** hand-placed
/// drill (the tap-to-place escape hatch). All resolve to the one `FretboardDrill` the renderer plays,
/// so the run screen never has to know which authoring path produced a drill.
///
/// Persisted as the opaque `Exercise.templatePayload` blob; a discriminated `Codable` so a new case is
/// an additive decode, and `Exercise.fretboardContent` best-effort decodes an older
/// bare-`FretboardDrill` blob into `.custom` for back-compat.
enum FretboardContent: Equatable {
    case run(FretboardRun)
    case scale(ScaleRun)
    case arpeggio(ArpeggioRun)
    case custom(FretboardDrill)
}

extension FretboardContent {
    /// The drill the board renders — a generated run, scale or arpeggio expanded, a custom drill as
    /// authored.
    var drill: FretboardDrill {
        switch self {
        case .run(let run): return run.expanded()
        case .scale(let scaleRun): return scaleRun.expanded()
        case .arpeggio(let arpeggioRun): return arpeggioRun.expanded()
        case .custom(let drill): return drill
        }
    }

    /// The generated finger-pattern run, when this is a `.run`.
    var runValue: FretboardRun? { if case .run(let run) = self { return run }; return nil }

    /// The scale run, when this is a `.scale`.
    var scaleValue: ScaleRun? { if case .scale(let scaleRun) = self { return scaleRun }; return nil }

    /// The arpeggio run, when this is an `.arpeggio`.
    var arpeggioValue: ArpeggioRun? {
        if case .arpeggio(let arpeggioRun) = self { return arpeggioRun }; return nil
    }

    /// The custom drill, when this is a `.custom`.
    var customValue: FretboardDrill? { if case .custom(let drill) = self { return drill }; return nil }
}

extension FretboardContent: Codable {
    private enum CodingKeys: String, CodingKey { case kind, run, scale, arpeggio, drill }
    private enum Kind: String, Codable { case run, scale, arpeggio, custom }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .run: self = .run(try container.decode(FretboardRun.self, forKey: .run))
        case .scale: self = .scale(try container.decode(ScaleRun.self, forKey: .scale))
        case .arpeggio: self = .arpeggio(try container.decode(ArpeggioRun.self, forKey: .arpeggio))
        case .custom: self = .custom(try container.decode(FretboardDrill.self, forKey: .drill))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .run(let run):
            try container.encode(Kind.run, forKey: .kind)
            try container.encode(run, forKey: .run)
        case .scale(let scaleRun):
            try container.encode(Kind.scale, forKey: .kind)
            try container.encode(scaleRun, forKey: .scale)
        case .arpeggio(let arpeggioRun):
            try container.encode(Kind.arpeggio, forKey: .kind)
            try container.encode(arpeggioRun, forKey: .arpeggio)
        case .custom(let drill):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(drill, forKey: .drill)
        }
    }
}
