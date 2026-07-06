import Foundation

/// A **generated fretboard run** (ADR 0065 build 2, generative authoring) — the recipe behind a
/// warm-up / picking / legato drill, declared as a *shape* rather than placed note-by-note. The
/// player authors four small things — a **finger pattern** (e.g. 1-3-2-4), the **base fret** it
/// anchors to, the **string span** it travels, and whether it comes **back** — and this expands
/// them into the evenly-gridded `FretboardDrill` the board renders. Change the span from "low E → A"
/// to "A → e" and the whole run re-generates; nothing is moved by hand.
///
/// Stored as the recipe (not the expanded notes) so a drill stays semantically editable on reopen,
/// and carried inside the versioned `FretboardContent` payload (T4 — in-band `version`, decode-time
/// upgrade, no store migration). The expansion is **pure timing/geometry math**, SwiftUI-free and
/// unit-tested (T5); the editor and run screen only skin the result.
struct FretboardRun: Codable, Equatable {
    /// The schema version this build writes. Bump when the encoded shape changes and add a
    /// decode-time upgrade rather than a store migration (T4).
    static let currentVersion = 1

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

    init(fingers: [Int],
         baseFret: Int,
         fromString: Int,
         toString: Int,
         roundTrip: Bool = true,
         notesPerBeat: Int = 2,
         version: Int = FretboardRun.currentVersion) {
        self.version = version
        self.fingers = fingers
        self.baseFret = max(1, baseFret)
        self.fromString = fromString
        self.toString = toString
        self.roundTrip = roundTrip
        self.notesPerBeat = max(1, notesPerBeat)
    }
}

// MARK: - Expansion (pure — SwiftUI-free, unit-tested; the editor & renderer skin the result)

extension FretboardRun {
    /// The absolute fret a finger number lands on: finger 1 sits on `baseFret`, each higher finger
    /// one fret up. Never below 0 (an open string).
    func fret(forFinger finger: Int) -> Int { max(0, baseFret + finger - 1) }

    /// The strings the run visits, in travel order, inclusive of both ends.
    private var stringPath: [Int] {
        let step = fromString <= toString ? 1 : -1
        return Array(stride(from: fromString, through: toString, by: step))
    }

    /// The ascending pass: the finger pattern laid on each string along the path.
    private var ascendingNotes: [FretNote] {
        guard !fingers.isEmpty else { return [] }
        return stringPath.flatMap { string in
            fingers.map { FretNote(string: string, fret: fret(forFinger: $0)) }
        }
    }

    /// One full cycle of notes. Ascending only when `roundTrip` is off; otherwise the ascent plus a
    /// descent that **omits the shared peak and start** so the looping cycle never double-hits a
    /// note at the turnaround or the loop seam (a smooth up-down-up triangle).
    var sequence: [FretNote] {
        let ascent = ascendingNotes
        guard roundTrip, ascent.count > 2 else { return ascent }
        let descent = Array(ascent.dropFirst().dropLast().reversed())
        return ascent + descent
    }

    /// Expand into the evenly-gridded `FretboardDrill` the board plays — one note per subdivision,
    /// no rests, wrapping at its own natural length (it defines its own phrase, independent of the
    /// exercise meter).
    func expanded() -> FretboardDrill {
        FretboardDrill(notesPerBeat: notesPerBeat,
                       notes: sequence.map { Optional($0) },
                       stringCount: 6)
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
