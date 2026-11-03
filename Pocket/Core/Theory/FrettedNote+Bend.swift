import Foundation

/// **How a bend moves** (ADR 0288): bent up and held, bent up and let back down, bent before the pick, or
/// bent before it and let down. Two flags on the note, `releases` and `preBent`, make the four. This reads
/// them as one shape, so the tab, the words, the glow and the drawing can't each decide differently.
///
/// Pure and SwiftUI-free (AGENTS.md), so every one of them is unit-tested.
extension FrettedNote {

    enum BendShape: Equatable, Sendable {
        /// Picked, then bent up: `7b9`.
        case bend
        /// Picked, bent up, then let back down to the fret: `7b9r7`.
        case bendAndRelease
        /// Bent up before it's picked, so it starts at the bent pitch: `7pb9`.
        case preBend
        /// Bent up before it's picked, then let down to the fret: `7pb9r7`.
        case preBendAndRelease
    }

    /// The bend's shape, or `nil` for a note that isn't bent.
    var bendShape: BendShape? {
        guard bend > 0 else { return nil }
        switch (preBent, releases) {
        case (false, false): return .bend
        case (false, true): return .bendAndRelease
        case (true, false): return .preBend
        case (true, true): return .preBendAndRelease
        }
    }

    /// The fret the bend reaches: the bent pitch, as a fret on the same string.
    var bentFret: Int { fret + bend }

    /// Set the bend's size. *None* takes its release and pre-bend with it, so a note with no bend never
    /// carries either, and two unbent notes on one fret are always equal.
    mutating func changeBend(to semitones: Int) {
        bend = semitones
        if semitones == 0 {
            releases = false
            preBent = false
        }
    }

    /// The bend as tab writes it after the fret: `b9`, `b9r7`, `pb9`, `pb9r7`, or `""` for none.
    var bendTab: String {
        guard bend > 0 else { return "" }
        return (preBent ? "pb" : "b") + "\(bentFret)" + (releases ? "r\(fret)" : "")
    }

    /// The bend in words, as the line over the strip and the By ear line say it: *bent a whole step*,
    /// *bent a whole step and released*, *pre-bent a half step*. `nil` for a note that isn't bent.
    var bendWords: String? {
        guard bend > 0 else { return nil }
        let size = Self.bendSizes[min(bend, Self.bendSizes.count - 1)]
        return (preBent ? "pre-bent " : "bent ") + size + (releases ? " and released" : "")
    }

    /// A bend's size, by semitones.
    private static let bendSizes = ["", "a half step", "a whole step", "a step and a half"]
}
