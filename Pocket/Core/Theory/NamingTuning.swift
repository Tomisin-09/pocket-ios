import Foundation

/// The strings Name the notes places frets on (ADR 0225 D6), chosen **per piece** since ADR 0227 D3: the
/// open strings highest-first, what to call them, and the instrument they belong to. A new piece starts
/// from the tuner's setting; changing it here never changes the tuner.
///
/// Pure and SwiftUI-free (AGENTS.md), so the move between tunings is unit-tested.
struct NamingTuning: Equatable {
    /// Open-string MIDI notes, **highest first**, as `PieceLabel.fretted` indexes them.
    let openMidi: [Int]
    /// What the instrument row over the neck says, e.g. "Guitar · Standard".
    let label: String
    let instrument: Instrument

    /// One of an instrument's curated tunings, labelled the way the tuner labels it.
    init(instrument: Instrument, tuning: Tuning) {
        self.openMidi = tuning.engineOpenMidi
        self.label = "\(instrument.displayName) · \(tuning.name)"
        self.instrument = instrument
    }

    /// The strings a piece was saved against, or the tuner's. A four-string piece is a bass piece,
    /// whatever the tuner says now.
    init(openMidi: [Int], label: String) {
        self.openMidi = openMidi
        self.label = label
        self.instrument = openMidi.count == Instrument.bass.stringCount ? .bass : .guitar
    }

    /// The curated tuning these strings are, or `nil` for strings that match none of them.
    var tuning: Tuning? { instrument.tunings.first { $0.engineOpenMidi == openMidi } }

    /// The answers after moving from this tuning to `next`. **A new tuning keeps the frets** and renames
    /// their notes. **A new instrument clears them**: a six-string position has nowhere to go on four
    /// strings, and moving it would be a guess. Answers named by ear have no position, so they stay.
    func carrying(_ labels: [PieceLabel?], to next: NamingTuning) -> [PieceLabel?] {
        guard next.instrument != instrument else { return labels }
        return labels.map { label in label?.isOnTheNeck == true ? nil : label }
    }

    /// How many answers sit on the neck: what a new instrument would clear, and so what it asks about.
    static func placed(in labels: [PieceLabel?]) -> Int {
        labels.filter { $0?.isOnTheNeck == true }.count
    }
}
