import Foundation

/// How the glow moves on the neck when a note sounds (ADR 0234 D5), shaped by **how it was played**, so the
/// lick is seen the way it's played and not only where. It replaces 0227 D2's one pop for every note.
///
/// How a note was reached comes first, since that's what's heard first: a hammer-on, pull-off or slide from
/// the tap before, or a lead-in inside the note (ADR 0230). A note reached plainly then shows what's done
/// to it: a bend glides to where it lands, vibrato shakes. Anything else pops. With Reduce Motion every one
/// of them only fades, where the note is placed (the view decides that, not this).
///
/// Pure and SwiftUI-free (AGENTS.md), so which glow a note gets is unit-tested.
enum HaloMotion: Equatable, Sendable {
    /// Picked: it pops in where it was played.
    case pop(NeckSpot)
    /// Bent: it lights where it was fretted, then glides to where the bend lands.
    case bend(from: NeckSpot, to: NeckSpot)
    /// Vibrato: it shakes on the note.
    case vibrato(NeckSpot)
    /// Hammered on or pulled off: the fret it came from flashes, then the glow snaps to the note.
    case legato(from: NeckSpot, to: NeckSpot)
    /// Slid: it travels along the string from the fret it came from.
    case slide(from: NeckSpot, to: NeckSpot)
    /// Slid in from nowhere: it comes in along the string from below or above, as the lead-in's arrow is
    /// drawn.
    case slideIn(to: NeckSpot, fromBelow: Bool)

    /// Where the glow ends up.
    var end: NeckSpot {
        switch self {
        case .pop(let spot), .vibrato(let spot): return spot
        case .bend(_, let to), .legato(_, let to), .slide(_, let to), .slideIn(let to, _): return to
        }
    }

    /// The glow for each note of tap `index`, one per note (a shape moves as one).
    static func motions(into index: Int, of labels: [PieceLabel?], maxFret: Int = PieceLabel.maxFret) -> [HaloMotion] {
        guard labels.indices.contains(index), case .fretted(let notes, let into)? = labels[index] else { return [] }
        let before = index > 0 ? labels[index - 1]?.frettedNotes ?? [] : []
        // A join from the tap before counts only when it still fits, as the tab and the strip read it.
        let join = NeckJoin.direction(into: index, of: labels) == nil ? nil : into
        return notes.map { note in
            let spot = NeckSpot(string: note.string, fret: note.fret)
            if let leadIn = note.leadIn, leadIn.direction(into: note.fret) != nil {
                switch leadIn.from {
                case .fret(let start):
                    return reached(spot, from: NeckSpot(string: note.string, fret: start), by: leadIn.join)
                case .below: return .slideIn(to: spot, fromBelow: true)
                case .above: return .slideIn(to: spot, fromBelow: false)
                }
            }
            if let join, let previous = before.first(where: { $0.string == note.string }) {
                return reached(spot, from: NeckSpot(string: note.string, fret: previous.fret), by: join)
            }
            if note.bend > 0 {
                return .bend(from: spot, to: NeckSpot(string: note.string, fret: min(note.fret + note.bend, maxFret)))
            }
            return note.vibrato ? .vibrato(spot) : .pop(spot)
        }
    }

    private static func reached(_ spot: NeckSpot, from start: NeckSpot, by join: Join) -> HaloMotion {
        join == .slide ? .slide(from: start, to: spot) : .legato(from: start, to: spot)
    }
}
