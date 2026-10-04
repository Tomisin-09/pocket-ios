import Foundation

// MARK: - Legato joins (ADR 0251 — pure, SwiftUI-free, unit-tested)

extension FretboardDrill {
    /// The drill with its **hammer-ons and pull-offs worked out**, the way a Legato drill is played: the
    /// first note on each string is picked, and every later note on that string is hammered on going up
    /// or pulled off coming down. Nothing is authored; the frets decide.
    ///
    /// **One rule for what a hammer-on is.** The check is `NeckJoin.direction(into:of:)`, the rule Name
    /// the notes already joins taps by (ADR 0227 D5), so a drill and a named piece can't disagree about
    /// it: a join needs the note before on the same string at a different fret, and the direction decides
    /// which. A rest breaks the chain, a string change and a repeated fret stay picked, and the first note
    /// is always picked — there is no join across the wrap, so every loop starts with a pick.
    ///
    /// A note that already carries a technique keeps it: a climbing run's `.slide` seam (ADR 0083) is how
    /// that note is played, and a legato reading doesn't overrule it. Idempotent.
    ///
    /// Copies `self` and replaces only `notes`, so the transient render fields — `noteGroups` (pass focus),
    /// `openMidi`, `keySpelling` — survive; `replacingNote` rebuilds the drill and would drop some.
    func withLegatoJoins() -> FretboardDrill {
        let labels: [PieceLabel?] = notes.map { slot in slot.map { .fretted(string: $0.string, fret: $0.fret) } }
        var joined = self
        joined.notes = notes.indices.map { index in
            guard var note = notes[index], note.technique == nil else { return notes[index] }
            switch NeckJoin.direction(into: index, of: labels) {
            case .upward?: note.technique = .hammerOn
            case .downward?: note.technique = .pullOff
            case nil: break
            }
            return note
        }
        return joined
    }
}
