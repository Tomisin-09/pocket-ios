import Foundation

/// **Triads on three strings** (ADR 0313 D4), the Arpeggios exercise's second shape beside the CAGED box:
/// a key, a string set, where the chords come from, and where on the neck they're played. Each chord takes
/// a close triad shape on the three strings (`TriadShapes`), and the run plays them over the click.
///
/// Stored as the recipe inside the versioned `FretboardContent` payload (T4), never as notes: the notes
/// are generated on each expansion (`TriadRun+Expansion.swift`), as every other generated run's are. A
/// progression is held as a **copy** of its steps, with their bars, and the name it was chosen under, so
/// editing or deleting the progression later leaves the exercise as it was (D5).
struct TriadRun: Equatable, Sendable {
    /// The schema version this build writes (T4).
    static let currentVersion = 1

    /// Where the chords come from (D5). The raw values are stored.
    enum Source: String, CaseIterable, Identifiable, Sendable {
        /// The key's own chord, major or minor.
        case oneChord
        /// The key's triads in order, vii° (or ii° in minor) included, back to the tonic.
        case keysSeven
        /// A copy of a progression, each chord held for its bars.
        case progression

        var id: String { rawValue }
    }

    /// Where on the neck the chords are played (D6). The raw values are stored.
    enum Placement: String, CaseIterable, Identifiable, Sendable {
        /// One chord plays every shape from the nut up; the key's seven climbs in one inversion; a
        /// progression plays three passes, each a position higher.
        case upTheNeck
        /// Every chord between two frets, each taking the shape nearest the one before.
        case stayInFrets

        var id: String { rawValue }

        var label: String {
            switch self {
            case .upTheNeck: return "Up the neck"
            case .stayInFrets: return "Stay in frets"
            }
        }
    }

    /// A progression copied in (D5): its steps with their bars, and the name it was chosen under.
    struct Progression: Codable, Equatable, Sendable {
        var name: String
        var steps: [ProgressionStep]
    }

    /// The narrowest a range of frets can be: three frets, the span of the widest triad shape but one.
    static let minFretSpan = 3
    /// The widest a range of frets can be.
    static let maxFretSpan = 10

    var version: Int
    /// The key's tonic, 0 = C … 11 = B.
    var tonic: Int
    /// The key is minor. A progression's own reading wins over this (`readsAsMinor`).
    var isMinor: Bool
    var strings: TriadStrings
    var source: Source
    /// The progression copied in. Kept when `source` moves away from it, so coming back finds it again.
    var progression: Progression?
    var placement: Placement
    /// The range for *Stay in frets*, both ends included. Clamped so it spans `minFretSpan` to
    /// `maxFretSpan` frets and stays on the neck.
    var lowFret: Int
    var highFret: Int
    /// The inversion the key's seven climbs in under *Up the neck* (*Climb in*): 0 root position, 1 first, 2
    /// second.
    var climbInversion: Int
    /// Evenly spaced notes per beat. Clamped to at least 1.
    var notesPerBeat: Int
    /// Up and back, for one chord and the key's seven. A progression's order is the music, so it never
    /// plays back (D7).
    var roundTrip: Bool

    init(tonic: Int,
         isMinor: Bool = false,
         strings: TriadStrings = .gbe,
         source: Source = .keysSeven,
         progression: Progression? = nil,
         placement: Placement = .stayInFrets,
         lowFret: Int = 3,
         highFret: Int = 7,
         climbInversion: Int = 0,
         notesPerBeat: Int = 2,
         roundTrip: Bool = false,
         version: Int = TriadRun.currentVersion) {
        self.version = version
        self.tonic = ((tonic % 12) + 12) % 12
        self.isMinor = isMinor
        self.strings = strings
        self.source = source
        self.progression = progression
        self.placement = placement
        (self.lowFret, self.highFret) = Self.clampedRange(low: lowFret, high: highFret)
        self.climbInversion = min(2, max(0, climbInversion))
        self.notesPerBeat = max(1, notesPerBeat)
        self.roundTrip = roundTrip
    }

    /// A range pulled onto the neck and into `minFretSpan`…`maxFretSpan` frets, keeping the low fret where
    /// it can.
    static func clampedRange(low: Int, high: Int) -> (low: Int, high: Int) {
        let low = min(max(0, low), TriadShapes.maxFret - (minFretSpan - 1))
        let high = min(TriadShapes.maxFret, max(low + minFretSpan - 1, min(high, low + maxFretSpan - 1)))
        return (low, high)
    }

    /// The range for *Stay in frets*.
    var fretRange: ClosedRange<Int> { lowFret...highFret }
}

// MARK: - Defaults (ADR 0313 D10)

extension TriadRun {
    /// What a new Triads run opens on (D10): the teacher's step 3. C major on G‑B‑e, the key's seven kept
    /// between frets 3 and 7, in eighths. It shows the range and the nearest move before anything is tapped.
    static let starter = TriadRun(tonic: 0)

    /// The progression the Chords row's *Progression* copies in when none is held yet: the four-chord loop,
    /// which *Use a progression* also opens on.
    static var defaultProgression: Progression {
        let loop = ProgressionTemplate.catalog.first { $0.id == "one-five-six-four" } ?? ProgressionTemplate.catalog[0]
        return Progression(name: loop.displayTitle, steps: loop.steps)
    }

    /// This run with the key of a box arpeggio (D2): its root, and minor when its quality is. The rest of
    /// the run is unchanged.
    func carryingKey(from box: ArpeggioRun) -> TriadRun {
        var run = self
        run.tonic = box.rootPitchClass
        run.isMinor = box.quality == .minor || box.quality == .minorSeventh
        return run
    }
}

// MARK: - Codable (tolerant: a newer value must not take the run with it)

extension TriadRun: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, tonic, isMinor, strings, source, progression, placement, lowFret, highFret
        case climbInversion, notesPerBeat, roundTrip
    }

    /// Everything but the version has a fallback, and an unknown string set, source or placement reads as
    /// D10's, so a run written by a newer build still plays here. A declared default doesn't survive a
    /// missing key under synthesized `Codable`, so the tolerance is written out.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let starter = TriadRun.starter
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let stringsRaw: String = value(.strings, starter.strings.rawValue)
        let sourceRaw: String = value(.source, starter.source.rawValue)
        let placementRaw: String = value(.placement, starter.placement.rawValue)
        self.init(tonic: value(.tonic, starter.tonic),
                  isMinor: value(.isMinor, starter.isMinor),
                  strings: TriadStrings(rawValue: stringsRaw) ?? starter.strings,
                  source: Source(rawValue: sourceRaw) ?? starter.source,
                  progression: (try? container.decodeIfPresent(Progression.self, forKey: .progression)) ?? nil,
                  placement: Placement(rawValue: placementRaw) ?? starter.placement,
                  lowFret: value(.lowFret, starter.lowFret),
                  highFret: value(.highFret, starter.highFret),
                  climbInversion: value(.climbInversion, starter.climbInversion),
                  notesPerBeat: value(.notesPerBeat, starter.notesPerBeat),
                  roundTrip: value(.roundTrip, starter.roundTrip),
                  version: try container.decode(Int.self, forKey: .version))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(tonic, forKey: .tonic)
        try container.encode(isMinor, forKey: .isMinor)
        try container.encode(strings.rawValue, forKey: .strings)
        try container.encode(source.rawValue, forKey: .source)
        try container.encodeIfPresent(progression, forKey: .progression)
        try container.encode(placement.rawValue, forKey: .placement)
        try container.encode(lowFret, forKey: .lowFret)
        try container.encode(highFret, forKey: .highFret)
        try container.encode(climbInversion, forKey: .climbInversion)
        try container.encode(notesPerBeat, forKey: .notesPerBeat)
        try container.encode(roundTrip, forKey: .roundTrip)
    }
}

// MARK: - The key and its chords (pure)

extension TriadRun {
    /// One chord of the run, named in the key.
    struct Chord: Equatable, Sendable {
        /// As written: "Dm7", "Bdim", "G5".
        var name: String
        /// The root's pitch class.
        var root: Int
        var quality: ChordGrip.Quality
        /// How many bars it holds for. Only a progression's chords have bars; the rest play their three
        /// notes once (D7).
        var bars: Int?
        /// The triad it plays, named, when that differs from how it's written: "Dm" for a Dm7 (D5).
        var playsAs: String?

        /// The triad's tones as semitones above the root, or `nil` for a power chord, which has none.
        var intervals: [Int]? { quality.triadIntervals }
    }

    /// The progression the run plays from, when its source is a progression. A run whose copy is missing
    /// or empty (a blob from a newer build, say) plays the key's seven instead.
    var playedProgression: Progression? {
        guard source == .progression, let progression, !progression.steps.isEmpty else { return nil }
        return progression
    }

    /// Whether the key reads as minor. A progression decides for itself, as the builder reads it (0218 D3):
    /// it does when it opens on a minor tonic chord.
    var readsAsMinor: Bool { playedProgression?.steps.readsAsMinor ?? isMinor }

    var key: ProgressionKey { ProgressionKey(tonic: tonic, isMinor: readsAsMinor) }

    /// The spelling the key demands (ADR 0123), or `nil` at the positions the circle leaves open.
    var keySpelling: NoteSpelling? {
        NoteSpelling.keySpelling(root: tonic, relativeMajorSemitones: readsAsMinor ? 3 : 0)
    }

    /// "C major", "A minor".
    func keyName(preference: NoteSpelling = .default) -> String {
        key.tonicName(preference: preference) + (readsAsMinor ? " minor" : " major")
    }

    /// The key's triads as steps, I to vii° in major and i to VII in minor.
    static func keysSevenSteps(minor: Bool) -> [ProgressionStep] {
        minor
            ? [.init(0, .minor), .init(2, .diminished), .init(3), .init(5, .minor), .init(7, .minor),
               .init(8), .init(10)]
            : [.init(0), .init(2, .minor), .init(4, .minor), .init(5), .init(7), .init(9, .minor),
               .init(11, .diminished)]
    }

    /// The steps the run plays, in order. The key's seven ends back on the tonic, the octave a climb closes
    /// on, as the mockup plays it.
    var steps: [ProgressionStep] {
        if let playedProgression { return playedProgression.steps }
        let seven = Self.keysSevenSteps(minor: isMinor)
        switch source {
        case .oneChord: return [seven[0]]
        case .keysSeven, .progression: return seven + [seven[0]]
        }
    }

    /// The chords the run plays, named in the key (ADR 0123: the key spells them, the preference only
    /// where it's silent). Only a progression's carry their bars.
    func chords(preference: NoteSpelling = .default) -> [Chord] {
        let key = self.key
        let hasBars = playedProgression != nil
        return steps.map { step in
            let name = key.chordName(of: step, preference: preference)
            let triad = step.quality.triadQuality
            let playsAs = triad.flatMap { $0 == step.quality ? nil : key.rootName(of: step, preference: preference)
                + $0.nameSuffix }
            return Chord(name: name, root: key.rootPitchClass(of: step), quality: step.quality,
                         bars: hasBars ? step.bars : nil, playsAs: playsAs)
        }
    }
}

extension TriadRun.Chord {
    /// The key's own chord, named: the *Just C* segment's chord (D5).
    static func keysOwnName(of run: TriadRun, preference: NoteSpelling) -> String {
        var oneChord = run
        oneChord.source = .oneChord
        return oneChord.chords(preference: preference).first?.name ?? ""
    }
}
