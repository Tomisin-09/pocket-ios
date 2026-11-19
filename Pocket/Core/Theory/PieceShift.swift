import Foundation

// **A piece always describes the recording** (ADR 0305 D5). A loop's piece is stored against the
// recording, so every piece on a song's map is in one frame, whatever the song's shift was when it was
// named. Screens show it, and Name the notes edits it, **as you hear it**: moved up by the song's shift.
// Saving moves it back down. The two moves are the same function, `moved(by:)`, with opposite signs.
//
// Moving a piece never moves a fret. Raising a song by *n* is the same as tuning the guitar down by *n*,
// and a new tuning keeps the frets (ADR 0227), so only the open strings move. Names said by ear (a note,
// a chord's root) have no strings, so they move themselves.
//
// Pure and SwiftUI-free (AGENTS.md), so the translation is unit-tested.

extension PieceLabel {
    /// The label `semitones` higher. A note or a chord named by ear moves its pitch; a placed note, a
    /// shape and a dead note stay as they are, since their pitch comes from the strings (`openMidi`),
    /// which the piece moves instead.
    func moved(by semitones: Int) -> PieceLabel {
        switch self {
        case .pitchClass(let value): .pitchClass(Self.normalised(value + semitones))
        case .chord(let root, let suffix): .chord(root: Self.normalised(root + semitones), suffix: suffix)
        case .fretted, .muted: self
        }
    }
}

extension PieceTranscription {
    /// The piece `semitones` higher: the open strings and every name said by ear move, the frets stay, and
    /// the strings are named again (`PieceTuning`). Moving by 0 changes nothing, and moving back by the
    /// opposite gives the same piece.
    ///
    /// Up by the song's shift is the piece **as you hear it**; down by it is what's saved (D5). *Standard*
    /// at +1 saves as *Half step down*, with the frets the player placed.
    func moved(by semitones: Int) -> PieceTranscription {
        guard semitones != 0 else { return self }
        var moved = self
        moved.taps = taps.map { PieceTranscription.Tap(seconds: $0.seconds, label: $0.label?.moved(by: semitones)) }
        if let openMidi {
            let strings = openMidi.map { $0 + semitones }
            moved.openMidi = strings
            moved.tuningLabel = PieceTuning.label(openMidi: strings, near: tuningLabel)
        }
        return moved
    }
}

/// What a piece's strings are called once a song's shift has moved them (ADR 0305 D5). Strings that are one
/// of the instrument's curated tunings take its name: *Standard* lowered by 1 is *Half step down*, already
/// in the list. Strings that match none are **a curated tuning moved evenly**, and say so: *Drop D* lowered
/// by 1 is *Drop D, 1 semitone down*.
///
/// Pure and SwiftUI-free, so every name is tested.
enum PieceTuning {

    /// The label for `openMidi` (highest-first), e.g. *Guitar · Half step down*, or *Guitar · Drop D, 1
    /// semitone down*. `near` is the label the strings had before they moved: when more than one tuning is
    /// the same distance away, the one it names is kept, so *Drop D* moved and moved back is *Drop D* again.
    /// Strings that aren't any curated tuning moved evenly keep `near`.
    static func label(openMidi: [Int], near: String?) -> String? {
        let instrument: Instrument = openMidi.count == Instrument.bass.stringCount ? .bass : .guitar
        let tunings = instrument.tunings.filter { $0.engineOpenMidi.count == openMidi.count }
        if let exact = tunings.first(where: { $0.engineOpenMidi == openMidi }) {
            return "\(instrument.displayName) · \(exact.name)"
        }
        let named = near.flatMap(tuningName(in:))
        let candidates = tunings.compactMap { tuning in
            evenOffset(openMidi, from: tuning.engineOpenMidi).map { (tuning: tuning, offset: $0) }
        }
        // The named tuning first, then the nearest: four semitones down from Standard is also one down from
        // Full step down, and the one the player plays reads better.
        let best = candidates.min { lhs, rhs in
            let left = (lhs.tuning.name == named ? 0 : 1, abs(lhs.offset))
            let right = (rhs.tuning.name == named ? 0 : 1, abs(rhs.offset))
            return left < right
        }
        guard let best else { return near }
        return "\(instrument.displayName) · \(best.tuning.name), \(semitones(best.offset))"
    }

    /// How far every string of `strings` sits from `base`'s, when it's the same for all of them; `nil` for
    /// strings that differ by more than one move (a different tuning) or count.
    static func evenOffset(_ strings: [Int], from base: [Int]) -> Int? {
        guard strings.count == base.count, let first = strings.first, let firstBase = base.first else {
            return nil
        }
        let offset = first - firstBase
        return zip(strings, base).allSatisfy { $0 - $1 == offset } ? offset : nil
    }

    /// *1 semitone down*, *3 semitones up*.
    static func semitones(_ offset: Int) -> String {
        "\(abs(offset)) semitone\(abs(offset) == 1 ? "" : "s") \(offset > 0 ? "up" : "down")"
    }

    /// The tuning line as you hear the piece (D5: *when the shift isn't 0, the tuning line says so*):
    /// *Guitar · Standard · song raised 1*. The frets are the player's on those strings because the song is
    /// moved, and the line says why. Never saved: a save names the strings again from `openMidi`.
    static func heard(_ label: String?, songShift: Int) -> String? {
        guard let label, songShift != 0 else { return label }
        return "\(label) · song \(songShift > 0 ? "raised" : "lowered") \(abs(songShift))"
    }

    /// The tuning a label names: *Drop D* in *Guitar · Drop D, 1 semitone down*, or in *Guitar · Drop D ·
    /// song raised 1*.
    private static func tuningName(in label: String) -> String? {
        let parts = label.components(separatedBy: " · ")
        guard parts.count > 1 else { return nil }
        return parts[1].components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces)
    }
}
