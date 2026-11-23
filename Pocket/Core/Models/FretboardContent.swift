import Foundation

/// The **content of a fretboard-template payload** (ADR 0065 build 2): a **generated** finger-pattern
/// run (warm-up families), a preprogrammed **scale** run (Scales, Slice 2), an **arpeggio** box, **triads**
/// on three strings (ADR 0313), or a **custom** hand-placed drill (the tap-to-place escape hatch). All
/// resolve to the one `FretboardDrill` the renderer plays, so the run screen never has to know which
/// authoring path produced a drill.
///
/// Persisted as the opaque `Exercise.templatePayload` blob; a discriminated `Codable` so a new case is
/// an additive decode, and `Exercise.fretboardContent` best-effort decodes an older
/// bare-`FretboardDrill` blob into `.custom` for back-compat. A build that doesn't know a case reads the
/// payload as nothing and plays a click (T5), and its editors leave the payload alone
/// (`Exercise.hasUnreadableContent`, ADR 0313 D4).
enum FretboardContent: Equatable {
    case run(FretboardRun)
    case scale(ScaleRun)
    case arpeggio(ArpeggioRun)
    /// Triads on three strings, a mode of the Arpeggios exercise (ADR 0313 D2, D4).
    case triads(TriadRun)
    case custom(FretboardDrill)
}

extension FretboardContent {
    /// The drill the board renders — a generated run, scale or arpeggio expanded, a custom drill as
    /// authored. The guitar overload is kept for the many guitar-only call sites and previews; the
    /// `instrument:` overload (ADR 0116) is what the owning `Exercise` calls so bass content draws on the
    /// four-string neck. A `.custom` drill already carries its own `stringCount`, so it's instrument-agnostic.
    var drill: FretboardDrill { drill(instrument: .guitar) }

    /// - Parameter beatsPerBar: the exercise's bar. Only a Triads run reads it, because a progression's
    ///   chords hold for their bars (ADR 0313 D4); every other recipe defines its own phrase length.
    func drill(instrument: Instrument, beatsPerBar: Int = 4) -> FretboardDrill {
        switch self {
        case .run(let run): return run.expanded(instrument: instrument)
        case .scale(let scaleRun): return scaleRun.expanded(instrument: instrument)
        case .arpeggio(let arpeggioRun): return arpeggioRun.expanded(instrument: instrument)
        // Guitar only (ADR 0313 D2): the editor offers Triads on a guitar exercise alone, and the shapes are
        // guitar shapes, so the six-string board draws them whatever the exercise says.
        case .triads(let triadRun): return triadRun.expanded(beatsPerBar: beatsPerBar)
        case .custom(let drill):
            // A `.custom` drill persists without its (transient) `openMidi`, so stamp the owning
            // exercise's tuning back on at render time — bass customs then label in bass tuning after a
            // reload, guitar customs are unchanged (ADR 0116 S5).
            guard instrument != .guitar else { return drill }
            var stamped = drill
            stamped.openMidi = instrument.engineOpenMidi
            return stamped
        }
    }

    /// The **note rate** this content is authored at — every case carries its own `notesPerBeat`
    /// (the Rhythm dropdown writes it), so the rate is read straight off the recipe rather than by
    /// expanding the drill. Read through `Exercise.noteRate`, which resolves it against the
    /// metronome subdivision.
    var notesPerBeat: Int {
        switch self {
        case .run(let run): run.notesPerBeat
        case .scale(let scaleRun): scaleRun.notesPerBeat
        case .arpeggio(let arpeggioRun): arpeggioRun.notesPerBeat
        case .triads(let triadRun): triadRun.notesPerBeat
        case .custom(let drill): drill.notesPerBeat
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

    /// The triads run, when this is a `.triads`.
    var triadsValue: TriadRun? { if case .triads(let triadRun) = self { return triadRun }; return nil }

    /// The custom drill, when this is a `.custom`.
    var customValue: FretboardDrill? { if case .custom(let drill) = self { return drill }; return nil }
}

extension FretboardContent: Codable {
    private enum CodingKeys: String, CodingKey { case kind, run, scale, arpeggio, triads, drill }
    private enum Kind: String, Codable { case run, scale, arpeggio, triads, custom }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .run: self = .run(try container.decode(FretboardRun.self, forKey: .run))
        case .scale: self = .scale(try container.decode(ScaleRun.self, forKey: .scale))
        case .arpeggio: self = .arpeggio(try container.decode(ArpeggioRun.self, forKey: .arpeggio))
        case .triads: self = .triads(try container.decode(TriadRun.self, forKey: .triads))
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
        case .triads(let triadRun):
            try container.encode(Kind.triads, forKey: .kind)
            try container.encode(triadRun, forKey: .triads)
        case .custom(let drill):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(drill, forKey: .drill)
        }
    }
}
