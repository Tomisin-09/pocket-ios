import Foundation

// MARK: - Curated default (T8 — common-practice vocabulary, authored in-house)

extension FretboardRun {
    /// The canonical **chromatic warm-up**: one finger per fret, 1-2-3-4 up every string from the
    /// low E to the high e and back, in eighths. The starter canvas a warm-up-family drill opens on —
    /// a full, real warm-up the moment it's created, not an empty board (ADR 0065 build 2).
    static let chromaticWarmup = FretboardRun(
        fingers: [1, 2, 3, 4], baseFret: 1,
        fromString: 5, toString: 0, roundTrip: true, notesPerBeat: 2)

    /// The **hammer-on / pull-off** figure a Legato drill opens on (ADR 0251): 1-2-4-2 at the 5th fret,
    /// low E to high e and back. Played as a Legato drill each string reads 5h6h8p6 — pick, hammer,
    /// hammer, pull — the joins worked out by `FretboardDrill.withLegatoJoins`.
    ///
    /// **Quarters**, a note a beat: at sixteenths the hammer and pull cues went by too fast to follow
    /// (Tomisin, on device, 2026-10-04). Faster is the Rhythm row, once the shape is in the hands.
    ///
    /// **Restate, not retrace, on the way back**, and four notes a string, so each string is one bar of
    /// 4/4 in both directions: 24 up and 20 down, 44 notes, 11 bars. A retraced descent drops the peak
    /// and the home note, which knocks the strings off the bar line coming down.
    static let hammerOnPullOff = FretboardRun(
        fingers: [1, 2, 4, 2], baseFret: 5,
        fromString: 5, toString: 0, roundTrip: true, notesPerBeat: 1,
        returnStyle: .restate)
}
