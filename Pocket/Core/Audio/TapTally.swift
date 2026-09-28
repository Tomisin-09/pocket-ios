import Foundation

/// One read of a looping engine's clock, taken at the instant of a tap (ADR 0225). Everything `TapTally`
/// needs to turn "now" into a place in the song, so the arithmetic never touches the engine and can be
/// unit-tested.
struct LoopClockReading: Equatable, Sendable {
    /// Source seconds played since this run of the loop began, **unwrapped** across passes, already
    /// pulled back through the time-stretcher's latency (ADR 0140 §3): the engine's own heard position.
    var elapsed: TimeInterval
    /// Where the looped region starts in the song, in seconds.
    var regionStart: TimeInterval
    /// One pass in source seconds: the region, less the crossfade folded into its seam.
    var passLength: TimeInterval
    /// Playback rate, × of original.
    var rate: Double
    /// Wall-clock seconds from a rendered buffer to the ear: the route's latency plus one IO buffer.
    /// Bluetooth puts 150–250 ms here, which is the whole reason this field exists.
    var outputLatency: TimeInterval
}

/// **Count the notes** (ADR 0225): the arithmetic behind the tap pad. Pure and SwiftUI-free (AGENTS.md).
///
/// A tap is stored as **song seconds**, never as a beat. Beats are worked out only for display, so a
/// wrong beat grid costs a wrong picture and never a wrong record.
enum TapTally {

    /// Wall-clock seconds: a tap this close before the loop wraps belongs to the **next** pass. The
    /// player anticipating the first note of the loop is still tapping that note.
    static let earlyWrap: TimeInterval = 0.06
    /// Fraction of a beat: a note tapped this far ahead of a beat still counts in that beat.
    static let beatTolerance = 0.12

    /// Where a tap landed: which pass of this run (0-based) and where in the song.
    struct Instant: Equatable, Sendable {
        let pass: Int
        let seconds: TimeInterval
    }

    /// Where the ear is **now**: the pass and the source seconds into it, after taking the output
    /// latency off. `nil` when the loop has no length.
    static func heardPosition(_ reading: LoopClockReading) -> (pass: Int, within: TimeInterval)? {
        guard reading.passLength > 0 else { return nil }
        // The latency is wall-clock time and the loop runs in source time, so it scales by the rate:
        // at half speed, 200 ms of route latency hides 100 ms of the song.
        let heard = max(0, reading.elapsed - reading.outputLatency * reading.rate)
        let pass = Int((heard / reading.passLength).rounded(.down))
        return (pass, heard - Double(pass) * reading.passLength)
    }

    /// Turn a clock reading into a stored tap, or `nil` when the loop has no length.
    static func instant(at reading: LoopClockReading) -> Instant? {
        guard let heard = heardPosition(reading) else { return nil }
        let early = earlyWrap * reading.rate
        // Only on a loop long enough for the window to be a sliver of it; on a tiny region every tap
        // would otherwise fall into the next pass.
        if reading.passLength > 4 * early, reading.passLength - heard.within < early {
            return Instant(pass: heard.pass + 1, seconds: reading.regionStart)
        }
        return Instant(pass: heard.pass, seconds: reading.regionStart + heard.within)
    }

    // MARK: - Beats (display only)

    /// How many taps fall in each beat of the region, first beat first, or `nil` when there is no grid
    /// to divide by. `beats` are song seconds (from `BeatGrid`), `interval` is one beat.
    ///
    /// A beat's slot opens `beatTolerance` of a beat **before** it, so a note tapped a hair early still
    /// counts where it was meant. A tap exactly on that edge belongs to the later beat. A sliver of a
    /// slot at either end of the region (under half a beat) folds into its neighbour, so a region drawn
    /// a little before or after a beat doesn't report a phantom beat of nothing.
    static func perBeatCounts(taps: [TimeInterval], beats: [TimeInterval], interval: TimeInterval,
                              regionStart: TimeInterval, regionEnd: TimeInterval) -> [Int]? {
        guard interval > 0, regionEnd > regionStart else { return nil }
        let lead = beatTolerance * interval
        var edges = beats.map { $0 - lead }.filter { $0 > regionStart && $0 < regionEnd }.sorted()
        if let first = edges.first, first - regionStart < interval / 2 { edges.removeFirst() }
        if let last = edges.last, regionEnd - last < interval / 2 { edges.removeLast() }
        guard !edges.isEmpty else { return nil }
        var counts = Array(repeating: 0, count: edges.count + 1)
        for tap in taps {
            counts[edges.filter { tap >= $0 }.count] += 1
        }
        return counts
    }

    // MARK: - The Journal line

    /// The line a save writes to the loop's Journal: `"11 notes. A C D D♯ E G A G E D C"`, plus
    /// `"By beat: 2 · 3 · 3 · 3."` when beats are shown. `nil` for an empty pass.
    ///
    /// Each fact is said once. Names appear only if at least one note is named, with `?` holding the
    /// place of an unnamed one, and a long run of them said as a count (`nameList`). A by-beat split of a
    /// single beat would just repeat the count, so it's left out.
    static func summary(count: Int, names: [String?], perBeat: [Int]?, countsChords: Bool) -> String? {
        guard count > 0 else { return nil }
        let noun = countsChords ? (count == 1 ? "chord" : "chords") : (count == 1 ? "note" : "notes")
        var text = "\(count) \(noun)."
        let named = names.contains { $0 != nil }
        if named {
            text += " " + nameList(names)
        }
        if let perBeat, perBeat.count > 1 {
            text += (named ? ". " : " ") + "By beat: " + perBeat.map(String.init).joined(separator: " · ") + "."
        }
        return text
    }

    /// Unnamed notes in a row, from this many up, are said as a count rather than a `?` each: a long pass
    /// named only at the start would otherwise read as a wall of question marks.
    static let unnamedRun = 4

    /// The names in order, a `?` holding each unnamed note's place, and a run of `unnamedRun` or more said
    /// as how many: `"A ? D (12 unnamed) E"`.
    static func nameList(_ names: [String?]) -> String {
        var words: [String] = []
        var gap = 0
        func closeGap() {
            words += gap >= unnamedRun ? ["(\(gap) unnamed)"] : Array(repeating: "?", count: gap)
            gap = 0
        }
        for name in names {
            guard let name else {
                gap += 1
                continue
            }
            closeGap()
            words.append(name)
        }
        closeGap()
        return words.joined(separator: " ")
    }
}

/// The passes a player has tapped this visit (ADR 0225), newest last. One row per pass on screen.
///
/// Nothing here is saved. It lives as long as the ear-training screen, and **Save** copies one pass onto
/// the loop. Pure value type, so the numbering across stops and restarts is unit-tested.
struct TapPasses: Equatable {

    struct Pass: Identifiable, Equatable {
        /// Pass number as shown ("Pass 3"). Never reused within a visit, even across a Clear.
        let id: Int
        var taps: [PieceTranscription.Tap]
        var count: Int { taps.count }
    }

    /// How many passes are kept. The screen shows the newest few; the rest only feed Undo.
    static let kept = 12

    private(set) var passes: [Pass] = []
    /// The highest pass number handed out so far. Only ever rises.
    private(set) var highest = 0
    /// The number the current run's first pass is counted from.
    private var runBase = 0

    /// A new run of the loop starts counting after every pass already numbered.
    mutating func beginRun() { runBase = highest }

    /// The number shown for pass `runPass` (0-based) of the current run.
    func id(forRunPass runPass: Int) -> Int { runBase + runPass + 1 }

    func pass(id: Int) -> Pass? { passes.first { $0.id == id } }

    /// Record a tap. Returns the pass number it went to.
    @discardableResult
    mutating func record(_ instant: TapTally.Instant) -> Int {
        let id = id(forRunPass: instant.pass)
        highest = max(highest, id)
        let tap = PieceTranscription.Tap(seconds: instant.seconds)
        if let index = passes.firstIndex(where: { $0.id == id }) {
            let slot = passes[index].taps.firstIndex { $0.seconds > tap.seconds } ?? passes[index].taps.count
            passes[index].taps.insert(tap, at: slot)
        } else {
            passes.append(Pass(id: id, taps: [tap]))
            passes.sort { $0.id < $1.id }
            if passes.count > Self.kept { passes.removeFirst(passes.count - Self.kept) }
        }
        return id
    }

    /// Name the taps of one pass, in order. Extra labels are ignored and missing ones leave taps
    /// unnamed, so a label can never land on the wrong tap.
    mutating func setLabels(_ labels: [PieceLabel?], forPass id: Int) {
        guard let index = passes.firstIndex(where: { $0.id == id }) else { return }
        for tapIndex in passes[index].taps.indices {
            passes[index].taps[tapIndex].label = labels.indices.contains(tapIndex) ? labels[tapIndex] : nil
        }
    }

    /// Clear every pass, returning what was there so it can be put back.
    mutating func clear() -> [Pass] {
        defer { passes = [] }
        return passes
    }

    /// Put cleared passes back **alongside** anything tapped since. Numbers never collide, because
    /// `highest` never went down.
    mutating func restore(_ cleared: [Pass]) {
        let since = passes.filter { new in !cleared.contains { $0.id == new.id } }
        passes = (cleared + since).sorted { $0.id < $1.id }
        if passes.count > Self.kept { passes.removeFirst(passes.count - Self.kept) }
    }
}

/// The beats around one loop's region, for **Show beats** (ADR 0225). Drawn, never stored: the taps stay
/// in seconds, and this is rebuilt from the song's current grid each time, so correcting the grid (ADR
/// 0154 anchors) moves the lines and re-divides the same taps with nothing rewritten.
struct CountGrid: Equatable {

    /// A beat line on a pass row: where it falls across the region (0…1) and whether it starts a bar.
    struct Mark: Equatable {
        let fraction: Double
        let isDownbeat: Bool
    }

    /// Every beat from one before the region to one after, in song seconds, so a beat just outside
    /// either edge can still open the first slot or close the last.
    let beats: [TimeInterval]
    /// One beat, in seconds.
    let interval: TimeInterval
    /// The beats inside the region, as lines to draw.
    let marks: [Mark]
    let regionStart: TimeInterval
    let regionEnd: TimeInterval

    /// The grid for a region, or `nil` when the song has none: no tempo, or no 1 placed (ADR 0022 won't
    /// guess the phase, and neither does this).
    init?(tempo: Double?, anchors: [TimeInterval], beatsPerBar: Int, duration: TimeInterval,
          regionStart: TimeInterval, regionEnd: TimeInterval) {
        guard let tempo, tempo > 0, duration > 0, regionEnd > regionStart else { return nil }
        let interval = 60 / tempo
        let all = BeatGrid.beats(bpm: tempo, duration: duration, anchors: anchors, beatsPerBar: beatsPerBar)
        let near = all.map { (seconds: $0.fraction * duration, isDownbeat: $0.isDownbeat) }
            .filter { $0.seconds >= regionStart - interval && $0.seconds <= regionEnd + interval }
        guard !near.isEmpty else { return nil }
        let length = regionEnd - regionStart
        self.beats = near.map(\.seconds)
        self.interval = interval
        self.marks = near.filter { $0.seconds >= regionStart && $0.seconds < regionEnd }
            .map { Mark(fraction: ($0.seconds - regionStart) / length, isDownbeat: $0.isDownbeat) }
        self.regionStart = regionStart
        self.regionEnd = regionEnd
    }

    /// How many of `taps` fall in each beat. See `TapTally.perBeatCounts`.
    func perBeat(_ taps: [TimeInterval]) -> [Int]? {
        TapTally.perBeatCounts(taps: taps, beats: beats, interval: interval,
                               regionStart: regionStart, regionEnd: regionEnd)
    }
}
