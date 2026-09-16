import Foundation

/// What *Use a progression* is about to insert (ADR 0218) — the chords a selection resolves to, with the
/// swaps the player made in the preview applied. Pure: the sheet draws `Chord`s and inserts `changes(_:)`,
/// and the tests read exactly the same values.
enum ProgressionInsert {

    /// One slot of the preview, and of the insert.
    struct Chord: Equatable, Identifiable {
        /// The slot's position — swaps are keyed by it.
        let id: Int
        var voicing: ChordVoicing
        /// The numeral over the chip. `nil` for a two-chord change, which has no key.
        var numeral: String?
        var beats: Int
        /// One of the player's saved chords, chosen by *Use my chords where they fit*.
        var isYours: Bool
        /// Swapped by hand in the preview — which outranks everything the resolver would choose.
        var isSwapped: Bool
    }

    /// Everything about *where* a progression is placed, as the sheet's controls set it.
    struct Placement: Equatable {
        /// The key's tonic, 0 = C … 11 = B.
        var tonic: Int
        var hold: ProgressionHold = .bar
        /// The drill's bar.
        var beatsPerBar: Int = 4
        var instrument: Instrument = .guitar
        /// Saved voicings to prefer where one fits — empty when *Use my chords* is off.
        var myChords: [ChordVoicing] = []
        var preference: NoteSpelling = .default
    }

    /// Steps placed in a key — a built-in progression or one of the player's.
    ///
    /// A progression with fixed lengths (the blues) holds each chord for its own bars; anything else
    /// scales by the hold. A swap replaces the slot's shape but keeps its length and numeral: the player
    /// changed which chord, not where it falls.
    static func chords(for steps: [ProgressionStep], fixedLengths: Bool, placement: Placement,
                       swaps: [Int: ChordVoicing] = [:]) -> [Chord] {
        let key = ProgressionKey(tonic: placement.tonic, isMinor: steps.readsAsMinor)
        let hold = fixedLengths ? ProgressionHold.bar : placement.hold
        return steps.enumerated().map { index, step in
            let beats = hold.beats(forBars: step.bars, beatsPerBar: placement.beatsPerBar)
            if let swap = swaps[index] {
                return Chord(id: index, voicing: swap, numeral: step.numeral, beats: beats,
                             isYours: false, isSwapped: true)
            }
            let resolved = ProgressionResolver.resolve(step, in: key, instrument: placement.instrument,
                                                       myChords: placement.myChords, preference: placement.preference)
            return Chord(id: index, voicing: resolved.voicing, numeral: step.numeral, beats: beats,
                         isYours: resolved.isYours, isSwapped: false)
        }
    }

    /// Exact shapes — a curated pair, or the two the player picked — each held for `hold`.
    static func chords(for voicings: [ChordVoicing], hold: ProgressionHold, beatsPerBar: Int,
                       swaps: [Int: ChordVoicing] = [:]) -> [Chord] {
        let beats = hold.beats(forBars: 1, beatsPerBar: beatsPerBar)
        return voicings.enumerated().map { index, voicing in
            Chord(id: index, voicing: swaps[index] ?? voicing, numeral: nil, beats: beats,
                  isYours: false, isSwapped: swaps[index] != nil)
        }
    }

    /// The chord changes to write into the drill.
    static func changes(_ chords: [Chord]) -> [ChordChange] {
        chords.map { ChordChange($0.voicing, beats: $0.beats) }
    }

    /// "Add 4 chords" — the insert button's label.
    static func addLabel(count: Int) -> String {
        count == 1 ? "Add 1 chord" : "Add \(count) chords"
    }
}
