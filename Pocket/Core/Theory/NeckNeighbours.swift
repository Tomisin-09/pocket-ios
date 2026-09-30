import Foundation

/// One place on the neck: a string (highest-first, 0 the thinnest) and a fret.
struct NeckSpot: Hashable, Sendable {
    let string: Int
    let fret: Int
}

/// The pass around the note being named, **on the neck** (ADR 0234 D4): the note itself, the three before
/// it and the three after, each numbered, so the line reads in order on the board and not only in the strip.
/// The ones before are drawn filled and the ones after ringed, both fading with distance, so they differ in
/// shape as well as colour.
///
/// Pure and SwiftUI-free (AGENTS.md), so which note a shared spot shows is unit-tested.
enum NeckNeighbours {

    /// How far either side of the note being named the neck marks.
    static let reach = 3

    enum Tier: Hashable, Sendable {
        case current
        /// 1…`reach` notes before.
        case before(Int)
        /// 1…`reach` notes after.
        case after(Int)
        /// Any other note of the pass, drawn in ink as before (ADR 0227 D3).
        case other
    }

    /// What a spot shows: its tier, and the note it's numbered with.
    struct Mark: Equatable, Sendable {
        let tier: Tier
        let note: Int
    }

    static func tier(of index: Int, active: Int) -> Tier {
        let distance = index - active
        if distance == 0 { return .current }
        if (1...reach).contains(-distance) { return .before(-distance) }
        if (1...reach).contains(distance) { return .after(distance) }
        return .other
    }

    /// Lower is nearer: the note being named, then one before, one after, two before, and so on, then the
    /// rest. A note just behind wins a tie with one just ahead, since it's where the player has been.
    static func rank(_ tier: Tier) -> Int {
        switch tier {
        case .current: return 0
        case .before(let steps): return steps * 2 - 1
        case .after(let steps): return steps * 2
        case .other: return .max
        }
    }

    /// For every spot a placed note sits on, what it shows. A lick comes back to the same fret, so where
    /// notes share a spot the nearest one to the note being named is the one drawn.
    static func marks(_ labels: [PieceLabel?], active: Int) -> [NeckSpot: Mark] {
        var marks: [NeckSpot: Mark] = [:]
        for index in labels.indices {
            let tier = tier(of: index, active: active)
            for note in labels[index]?.frettedNotes ?? [] {
                let spot = NeckSpot(string: note.string, fret: note.fret)
                if let held = marks[spot], rank(held.tier) <= rank(tier) { continue }
                marks[spot] = Mark(tier: tier, note: index)
            }
        }
        return marks
    }
}
