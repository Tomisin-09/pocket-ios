import Foundation

// MARK: - Placing the chords (pure: SwiftUI-free, unit-tested in TriadRunTests)

extension TriadRun {
    /// The highest fret *Up the neck*'s starting shapes reach: one chord's every shape, and the shapes a
    /// progression's three passes start from.
    static let climbTopFret = 15
    /// A pass's later chords may reach a little above where the passes start.
    static let passTopFret = 17
    /// How many times a progression plays up the neck, each pass a position higher (D6).
    static let passCount = 3
    /// The widths a pass's range is tried at, narrowest first: five to eight frets (D6).
    static let passRangeWidths = 5...8

    /// A chord of the run with the shape it plays, or `nil` where it has none: a power chord, or a chord
    /// with no shape in the range (D5, D6). Either way it rests for its whole length.
    struct Placed: Equatable, Sendable {
        var chord: Chord
        var shape: TriadShape?
        /// Which pass of a progression up the neck the chord is in. 0 for everything else.
        var pass: Int = 0
    }

    /// Every chord the run plays, in order, with its shape. This is the whole policy of where each chord
    /// goes; the expansion only lays these out on the beat grid.
    func placed(preference: NoteSpelling = .default) -> [Placed] {
        let chords = chords(preference: preference)
        guard let first = chords.first else { return [] }
        if playedProgression != nil {
            return placement == .stayInFrets ? nearestChain(chords, in: fretRange) : passes(chords)
        }
        let ascent: [Placed]
        switch (source == .oneChord, placement) {
        case (true, .upTheNeck):
            ascent = shapes(of: first, maxFret: Self.climbTopFret).map { Placed(chord: first, shape: $0) }
        case (true, .stayInFrets):
            let fitting = shapes(of: first).filter { $0.fits(in: fretRange) }
            ascent = fitting.isEmpty ? [Placed(chord: first, shape: nil)]
                : fitting.map { Placed(chord: first, shape: $0) }
        case (false, .upTheNeck): ascent = climb(chords)
        case (false, .stayInFrets): ascent = nearestChain(chords, in: fretRange)
        }
        // Up and back drops the shared peak and start, so a looping run never plays one twice in a row.
        guard roundTrip, ascent.count > 2 else { return ascent }
        return ascent + ascent.dropFirst().dropLast().reversed()
    }

    /// A chord's shapes on the run's strings, lowest first. None for a power chord.
    private func shapes(of chord: Chord, maxFret: Int = TriadShapes.maxFret) -> [TriadShape] {
        guard let intervals = chord.intervals else { return [] }
        return TriadShapes.all(root: chord.root, intervals: intervals, on: strings, maxFret: maxFret)
    }

    /// Each chord takes the shape in `range` nearest the one before (D3, D6).
    private func nearestChain(_ chords: [Chord], in range: ClosedRange<Int>) -> [Placed] {
        var previous: TriadShape?
        return chords.map { chord in
            let shape = TriadShapes.nearest(to: previous, among: shapes(of: chord).filter { $0.fits(in: range) })
            if let shape { previous = shape }
            return Placed(chord: chord, shape: shape)
        }
    }

    /// The key's seven up the neck in one inversion (*Climb in*): each chord's lowest shape in that
    /// inversion whose bass is above the last one's. It ends where the neck does.
    private func climb(_ chords: [Chord]) -> [Placed] {
        var placed: [Placed] = []
        var previousBass = Int.min
        for chord in chords {
            let candidates = shapes(of: chord).filter { $0.inversion == climbInversion && $0.pitches[0] > previousBass }
            guard let shape = candidates.min(by: { $0.pitches[0] < $1.pitches[0] }) else { break }
            placed.append(Placed(chord: chord, shape: shape))
            previousBass = shape.pitches[0]
        }
        return placed
    }

    /// A progression up the neck (D6): three passes, each starting from the next shape of its first chord
    /// and kept to the narrowest range around that shape that holds every chord, so the three passes are
    /// three positions up the neck. A pass whose range holds nothing takes the nearest shape anywhere.
    private func passes(_ chords: [Chord]) -> [Placed] {
        // A power chord has no shape, so the passes start from the first chord that has one.
        guard let anchor = chords.firstIndex(where: { $0.intervals != nil }) else {
            return chords.map { Placed(chord: $0, shape: nil) }
        }
        let starts = shapes(of: chords[anchor], maxFret: Self.climbTopFret).prefix(Self.passCount)
        return starts.enumerated().flatMap { pass, start in
            let range = passRange(around: start, chords: chords)
            var previous = start
            return chords.enumerated().map { index, chord -> Placed in
                guard index != anchor else { return Placed(chord: chord, shape: start, pass: pass) }
                let every = shapes(of: chord, maxFret: Self.passTopFret)
                let inRange = range.map { range in every.filter { $0.fits(in: range) } } ?? []
                let shape = TriadShapes.nearest(to: previous, among: inRange.isEmpty ? every : inRange)
                if let shape { previous = shape }
                return Placed(chord: chord, shape: shape, pass: pass)
            }
        }
    }

    /// The narrowest range, five to eight frets, that holds `start` and a shape of every chord, with its
    /// low fret nearest one below the shape's, so the pass reads as a position on the way up.
    private func passRange(around start: TriadShape, chords: [Chord]) -> ClosedRange<Int>? {
        for width in Self.passRangeWidths {
            let lowest = max(0, start.highestFret - width + 1)
            guard lowest <= start.lowestFret else { continue }
            let lows = Array(lowest...start.lowestFret)
                .sorted { (abs($0 - (start.lowestFret - 1)), $0) < (abs($1 - (start.lowestFret - 1)), $1) }
            if let low = lows.first(where: { holdsEveryChord(chords, in: $0...($0 + width - 1)) }) {
                return low...(low + width - 1)
            }
        }
        return nil
    }

    private func holdsEveryChord(_ chords: [Chord], in range: ClosedRange<Int>) -> Bool {
        chords.allSatisfy { $0.intervals == nil || shapes(of: $0).contains { $0.fits(in: range) } }
    }
}

// MARK: - A range that can't hold a chord (D6)

extension TriadRun {
    /// Whether every chord that has a triad has a shape between the two frets. A power chord has none
    /// anywhere, so it never counts against a range.
    func holdsEveryChord(in range: ClosedRange<Int>) -> Bool { holdsEveryChord(chords(), in: range) }

    /// The chords with a triad and no shape between the frets, once each, named (D6). Empty unless the run
    /// stays in frets.
    func chordsWithNoShape(preference: NoteSpelling = .default) -> [String] {
        guard placement == .stayInFrets else { return [] }
        var names: [String] = []
        for item in placed(preference: preference)
        where item.shape == nil && item.chord.intervals != nil && !names.contains(item.chord.name) {
            names.append(item.chord.name)
        }
        return names
    }

    /// The nearest ranges that hold every chord (D6): the same width lower and the same width higher,
    /// the nearest of each. When neither exists, the narrowest wider one, up to four frets wider, keeping
    /// the low fret where it can. Each one is a range the Frets row can set.
    func rangesThatHoldEveryChord() -> [ClosedRange<Int>] {
        let chords = chords()
        let width = highFret - lowFret
        var found: [ClosedRange<Int>] = []
        if let lower = (0..<lowFret).reversed().first(where: { holdsEveryChord(chords, in: $0...($0 + width)) }) {
            found.append(lower...(lower + width))
        }
        let highest = TriadShapes.maxFret - width
        if lowFret < highest,
           let higher = ((lowFret + 1)...highest).first(where: { holdsEveryChord(chords, in: $0...($0 + width)) }) {
            found.append(higher...(higher + width))
        }
        let widest = min(width + 4, Self.maxFretSpan - 1)
        guard found.isEmpty, widest > width else { return found }
        for wider in (width + 1)...widest {
            for low in max(0, lowFret - (wider - width))...lowFret where low + wider <= TriadShapes.maxFret {
                if holdsEveryChord(chords, in: low...(low + wider)) { return [low...(low + wider)] }
            }
        }
        return []
    }
}

// MARK: - Expansion

extension TriadRun {
    /// How many slots a chord lasts (D7). A progression's chord holds for its bars, a bar being the
    /// exercise's own, and Broken repeats its three notes upward to fill them. Anything else plays its three
    /// notes once.
    func slotCount(for chord: Chord, beatsPerBar: Int) -> Int {
        guard let bars = chord.bars else { return 3 }
        return max(1, bars) * max(1, beatsPerBar) * notesPerBeat
    }

    /// Expand into the evenly gridded drill the board plays. **Broken** plays each chord's three notes one at
    /// a time, low string to high (D7). **Together** holds all three for the same slots: each slot sounds
    /// the shape's bass, with its other two notes as the slot's companions (D8), so switching *Play as*
    /// never changes how long the run is. A chord with no shape rests for its whole length, so the run keeps
    /// time with the click and a progression doesn't get shorter (D5, D6). This is the one fretboard recipe
    /// whose length depends on the meter, so it takes the exercise's beats per bar (D4).
    ///
    /// The drill carries the key's tonic as its root and the key's spelling, the shaded range when the run
    /// stays in frets, and each note's pass when a progression climbs the neck, so the board fades the
    /// passes not being played (ADR 0083 S2b). It carries each chord with the slots it plays, so the board
    /// can name the triad under the hand, colour it and ring its root (*What the phone showed*).
    func expanded(beatsPerBar: Int) -> FretboardDrill {
        var notes: [FretNote?] = []
        var companions: [[FretNote]] = []
        var passes: [Int] = []
        var chords: [DrillChord] = []
        let together = playAs == .together
        let key = MusicalKey.make(pitchClass: tonic, quality: readsAsMinor ? .minor : .major)
        for item in placed() {
            let tones = item.shape?.notes
            let start = notes.count
            for slot in 0..<slotCount(for: item.chord, beatsPerBar: beatsPerBar) {
                if together, let tones {
                    notes.append(tones.first)
                    companions.append(Array(tones.dropFirst()))
                } else {
                    notes.append(tones.map { $0[slot % $0.count] })
                    companions.append([])
                }
                passes.append(item.pass)
            }
            chords.append(drillChord(item, key: key, slots: start..<notes.count))
        }
        return FretboardDrill(notesPerBeat: notesPerBeat, notes: notes, stringCount: 6,
                              rootPitchClass: tonic,
                              noteGroups: Set(passes).count > 1 ? passes : nil,
                              keySpelling: keySpelling,
                              shadedFrets: placement == .stayInFrets ? fretRange : nil,
                              chords: chords,
                              companions: together ? companions : nil)
    }

    /// A placed chord as the board names it: the triad it plays (a Dm7 is its Dm, D5), read against the key
    /// for its numeral and colour. A run of one chord adds the shape's inversion, the only thing that
    /// changes; a chord with no shape adds that it rests.
    private func drillChord(_ item: Placed, key: MusicalKey, slots: Range<Int>) -> DrillChord {
        let suffix = (item.chord.quality.triadQuality ?? item.chord.quality).nameSuffix
        let detail: String?
        if let shape = item.shape {
            let oneChord = source == .oneChord && playedProgression == nil
            detail = oneChord ? Self.inversionName(shape.inversion).lowercased() : nil
        } else {
            detail = "rests"
        }
        return DrillChord(root: item.chord.root, suffix: suffix,
                          numeral: ChordNumeral.read(root: item.chord.root, suffix: suffix, in: key),
                          detail: detail, slots: slots)
    }
}

// MARK: - Naming (pure)

extension TriadRun {
    /// *Climb in*'s three choices, by inversion.
    static func inversionName(_ inversion: Int) -> String {
        switch inversion {
        case 1: return "1st inversion"
        case 2: return "2nd inversion"
        default: return "Root position"
        }
    }

    /// The run's title: "Triads in C major", "C on three strings", "I – V – vi – IV in C major".
    func title(preference: NoteSpelling = .default) -> String {
        let key = keyName(preference: preference)
        if let playedProgression { return "\(playedProgression.name) in \(key)" }
        if source == .oneChord, let chord = chords(preference: preference).first {
            return "\(chord.name) on three strings"
        }
        return "Triads in \(key)"
    }

    /// The line under the title: the strings, and where on the neck the run is played.
    func caption(preference: NoteSpelling = .default) -> String {
        let set = strings.label
        if placement == .stayInFrets {
            return "\(set) · frets \(lowFret)–\(highFret)" + (playedProgression == nil ? "" : " · nearest shapes")
        }
        let placed = placed(preference: preference)
        if playedProgression != nil {
            let first = placed.first { $0.shape != nil }?.chord.name ?? ""
            return "\(set) · 3 times, each from a shape of \(first)"
        }
        let frets = placed.compactMap(\.shape).flatMap(\.frets)
        let span = "frets \(frets.min() ?? 0)–\(frets.max() ?? 0)"
        if source == .oneChord { return "\(set) · every shape, \(span)" }
        return "\(set) · \(Self.inversionName(climbInversion).lowercased()) · \(span)"
    }
}
