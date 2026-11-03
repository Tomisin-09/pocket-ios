import Foundation

/// The tempo the tempo sheet holds before Done (ADR 0284 D2): the number, where it came from, and
/// for an estimate the reading behind it, which Half and Double count again (ADR 0282 D5). Pure, so
/// the rules for Half, Double and a typed tempo are unit-tested rather than read off the sheet.
struct TempoDraft: Equatable {
    /// Where the tempo came from, which the sheet says above it.
    enum Source: Equatable {
        /// The song's own tempo, as the sheet opened on it.
        case song
        /// *Find the tempo*.
        case estimated
        /// *Tap along*.
        case tapped
        /// *Type a tempo*.
        case typed
    }

    let bpm: Double
    let source: Source
    /// The estimate this is, kept so Half and Double stay exact and place the 1 again.
    let reading: TempoEstimator.Reading?

    init(bpm: Double, source: Source) {
        self.bpm = bpm
        self.source = source
        reading = nil
    }

    init(reading: TempoEstimator.Reading) {
        bpm = reading.estimate.bpm
        source = .estimated
        self.reading = reading
    }

    /// Whether `factor` times the tempo stays inside `TempoMath.minTapBPM...maxTapBPM`.
    func allows(_ factor: Double) -> Bool {
        (TempoMath.minTapBPM...TempoMath.maxTapBPM).contains(bpm * factor)
    }

    /// **Half** (½) or **Double** (2). An estimate is counted again at the new tempo, so it stays exact
    /// and its 1 is found again (ADR 0282 D5). Any other tempo is multiplied, and keeps its source:
    /// half of a tapped tempo is still the player's taps. `nil` outside the tappable range.
    func scaled(by factor: Double) -> TempoDraft? {
        if let reading { return reading.scaled(by: factor).map(TempoDraft.init(reading:)) }
        guard allows(factor) else { return nil }
        return TempoDraft(bpm: bpm * factor, source: source)
    }

    /// The tempo *Type a tempo* sets, or `nil` for nothing usable. The sheet shows tempos as whole
    /// numbers, so typing the whole number of the tempo shown keeps that tempo exact: *Binta*'s
    /// 83.0015 shouldn't become 83 because "83" was typed over it (ADR 0282). Anything else is the
    /// number typed, with a comma read as a decimal point, clamped to the tappable range.
    static func typed(_ text: String, showing shown: Double?) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let shown, trimmed == TempoMath.wholeBPM(shown) { return shown }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value > 0 else {
            return nil
        }
        return value.clamped(to: TempoMath.minTapBPM...TempoMath.maxTapBPM)
    }

    /// What the sheet says above the tempo.
    var sourceLine: String {
        switch source {
        case .song: "This song's tempo"
        case .estimated: "Estimated from the song"
        case .tapped: "From your taps"
        case .typed: "Typed in"
        }
    }

    /// The line under the tempo: the bar, and where its 1 is. *"4 beats a bar · the 1 at 0:02"*. A
    /// meter in eighths reads as its name, since *6 beats a bar* isn't how a 6/8 song is counted.
    static func summary(beatsPerBar: Int, noteValue: Int, name: String, downbeat: TimeInterval?) -> String {
        let bar = noteValue == 4 ? "\(beatsPerBar) beats a bar" : name
        let one = downbeat.map { "the 1 at \(timecode($0))" } ?? "no 1 yet"
        return "\(bar) · \(one)"
    }
}

/// What heads the tempo sheet, under Play and the click (ADR 0284 D1, D2).
enum TempoSheetTop: Equatable {
    /// No tempo yet: the **Find the tempo** button.
    case find
    /// *Find the tempo* is running.
    case listening
    /// A song that follows its beat map, with nothing chosen yet: **The beats** (ADR 0281).
    case beats
    /// A tempo: the one chosen in the sheet, or the song's own.
    case tempo(TempoDraft)

    init(draft: TempoDraft?, isListening: Bool, hasBeatMap: Bool, songBPM: Double?) {
        if isListening {
            self = .listening
        } else if let draft {
            self = .tempo(draft)
        } else if hasBeatMap {
            self = .beats
        } else if let songBPM {
            self = .tempo(TempoDraft(bpm: songBPM, source: .song))
        } else {
            self = .find
        }
    }

    /// The tempo shown, which Half, Double and a typed tempo start from.
    var shown: TempoDraft? {
        if case .tempo(let draft) = self { draft } else { nil }
    }

    /// Whether the other ways list *Find the tempo* again: once something heads the sheet that
    /// didn't come from it. Running it again on its own estimate would read the same.
    var offersFindAgain: Bool {
        switch self {
        case .find, .listening: false
        case .beats: true
        case .tempo(let draft): draft.source != .estimated
        }
    }
}
