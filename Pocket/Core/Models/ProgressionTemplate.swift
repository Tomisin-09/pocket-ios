import Foundation

/// A **built-in progression** the *Use a progression* sheet offers (ADR 0218 D1) — steps in a key, named
/// by their numerals or, where the numerals aren't how players say it, by a plain description. Never
/// named after a song: a progression is common property, a title is not.
///
/// Authored in-house (T8): the standard progressions every method book teaches, written as degrees.
struct ProgressionTemplate: Identifiable, Equatable, Sendable {
    let id: String
    /// Shown instead of the numerals when set — "12-bar blues".
    let title: String?
    /// One line under the title.
    let detail: String
    let steps: [ProgressionStep]
    /// The steps' own lengths are the form, so the hold setting doesn't apply (the blues).
    var hasFixedLengths = false

    /// What a row reads as.
    var displayTitle: String { title ?? steps.numerals }
}

extension ProgressionTemplate {
    /// The curated set, in the order the sheet lists them: the three- and four-chord loops first, then the
    /// cadence, the blues, and the two borrowed-chord loops.
    static let catalog: [ProgressionTemplate] = [
        ProgressionTemplate(id: "one-four-five", title: nil, detail: "Three chords",
                            steps: [.init(0), .init(5), .init(7)]),
        ProgressionTemplate(id: "one-five-six-four", title: nil, detail: "Four-chord loop",
                            steps: [.init(0), .init(7), .init(9, .minor), .init(5)]),
        ProgressionTemplate(id: "six-four-one-five", title: nil, detail: "The same four, starting minor",
                            steps: [.init(9, .minor), .init(5), .init(0), .init(7)]),
        ProgressionTemplate(id: "one-six-four-five", title: nil, detail: "’50s loop",
                            steps: [.init(0), .init(9, .minor), .init(5), .init(7)]),
        ProgressionTemplate(id: "two-five-one", title: nil, detail: "Jazz cadence",
                            steps: [.init(2, .min7), .init(7, .dom7), .init(0, .maj7, bars: 2)]),
        ProgressionTemplate(id: "twelve-bar-blues", title: "12-bar blues",
                            detail: "Blues form — sets its own lengths",
                            steps: [.init(0, .dom7, bars: 4), .init(5, .dom7, bars: 2), .init(0, .dom7, bars: 2),
                                    .init(7, .dom7), .init(5, .dom7), .init(0, .dom7), .init(7, .dom7)],
                            hasFixedLengths: true),
        ProgressionTemplate(id: "descending-minor", title: nil, detail: "Descending minor",
                            steps: [.init(0, .minor), .init(10), .init(8), .init(7)]),
        ProgressionTemplate(id: "rock-loop", title: nil, detail: "Rock loop",
                            steps: [.init(0), .init(10), .init(5)])
    ]
}

/// How long each inserted chord is held (ADR 0218 D7) — one setting for the whole insert. A shorter
/// hold is how a changes drill gets harder without touching the command tempo.
enum ProgressionHold: String, CaseIterable, Identifiable, Sendable {
    case bar, twoBeats, oneBeat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bar: return "1 bar"
        case .twoBeats: return "2 beats"
        case .oneBeat: return "1 beat"
        }
    }

    /// The beats a step of `bars` bars is held for. A bar is the drill's own bar, so a 3/4 drill holds a
    /// chord for three beats, not four; the shorter holds scale by the step's length, so a two-bar chord
    /// stays twice as long as its neighbours.
    func beats(forBars bars: Int, beatsPerBar: Int) -> Int {
        let bars = max(1, bars)
        switch self {
        case .bar: return bars * max(1, beatsPerBar)
        case .twoBeats: return bars * 2
        case .oneBeat: return bars
        }
    }
}

/// A **two-chord change** (ADR 0218 D8) — stored as two exact shapes, never as steps in a key. A changes
/// drill is hard because of the grips, not the key: Am to E is the same grip moved one string over, and
/// transposing it would make it a different exercise. Guitar-only, like the shapes it names.
struct ChordPair: Identifiable, Equatable, Sendable {
    let id: String
    let first: ChordVoicing
    let second: ChordVoicing
    /// Why the change is worth drilling, in one line.
    let detail: String

    var title: String { "\(first.name) ↔ \(second.name)" }

    /// The two changes to insert, each held for `hold`.
    func changes(hold: ProgressionHold, beatsPerBar: Int) -> [ChordChange] {
        let beats = hold.beats(forBars: 1, beatsPerBar: beatsPerBar)
        return [ChordChange(first, beats: beats), ChordChange(second, beats: beats)]
    }
}

extension ChordPair {
    /// The curated changes, easiest grips first, ending on the first barre.
    static let curated: [ChordPair] = [
        ChordPair(id: "am-e", first: .aMinor, second: .eMajor, detail: "Same grip, one string over"),
        ChordPair(id: "em-c", first: .eMinor, second: .cMajor, detail: "A gentle start"),
        ChordPair(id: "c-g", first: .cMajor, second: .gMajor, detail: "The big stretch"),
        ChordPair(id: "g-d", first: .gMajor, second: .dMajor, detail: "Across the neck"),
        ChordPair(id: "d-a", first: .dMajor, second: .aMajor, detail: "Tight grips"),
        ChordPair(id: "c-f", first: .cMajor, second: .fBarre, detail: "Your first barre")
    ]
}
