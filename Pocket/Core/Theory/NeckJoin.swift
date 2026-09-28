import Foundation

/// Which way the notes moved into a tap (ADR 0227 D5). It decides which join a tap can have: up is a
/// hammer-on or `/`, down a pull-off or `\`.
enum JoinDirection: Equatable, Sendable {
    case upward, downward

    /// The mark a join writes in the tab and between the chips: `h`, `p`, `/` or `\`.
    func symbol(for join: Join) -> String {
        switch (join, self) {
        case (.legato, .upward): return "h"
        case (.legato, .downward): return "p"
        case (.slide, .upward): return "/"
        case (.slide, .downward): return "\\"
        }
    }

    /// The legato join's name this way: *Hammer-on* up, *Pull-off* down.
    var legatoName: String { self == .upward ? "Hammer-on" : "Pull-off" }
}

/// The **joins** between taps (ADR 0227 D5): hammer-on, pull-off and slide live on the second tap, as
/// *Into it*. Pure and SwiftUI-free (AGENTS.md), so the rule is unit-tested.
enum NeckJoin {

    /// Why the tap at `index` can't be joined to the one before, for the line under *Into it*, or `nil`
    /// when it can. A join is valid only when the tap before is on the neck, on the same strings, with
    /// every note moving the same way.
    enum Blocker: Equatable {
        case notPlaced, first, previousUnnamed, previousByEar, otherStrings, sameFret, mixedDirections
    }

    /// The way the notes moved from tap `index - 1` into tap `index`, when a join could go there.
    static func direction(into index: Int, of labels: [PieceLabel?]) -> JoinDirection? {
        guard case .joinable(let direction) = check(into: index, of: labels) else { return nil }
        return direction
    }

    /// What stops a join into tap `index`, or `nil` when one can go there.
    static func blocker(into index: Int, of labels: [PieceLabel?]) -> Blocker? {
        guard case .blocked(let blocker) = check(into: index, of: labels) else { return nil }
        return blocker
    }

    private enum Outcome {
        case joinable(JoinDirection)
        case blocked(Blocker)
    }

    private static func check(into index: Int, of labels: [PieceLabel?]) -> Outcome {
        guard labels.indices.contains(index), let current = labels[index]?.frettedNotes, !current.isEmpty else {
            return .blocked(.notPlaced)
        }
        guard index > 0 else { return .blocked(.first) }
        guard let before = labels[index - 1] else { return .blocked(.previousUnnamed) }
        let previous = before.frettedNotes
        guard !previous.isEmpty else { return .blocked(.previousByEar) }
        guard previous.count == current.count, Set(previous.map(\.string)) == Set(current.map(\.string)) else {
            return .blocked(.otherStrings)
        }
        let moves = current.map { note in
            (note.fret - (previous.first { $0.string == note.string }?.fret ?? note.fret)).signum()
        }
        if moves.allSatisfy({ $0 == 0 }) { return .blocked(.sameFret) }
        guard Set(moves).count == 1 else { return .blocked(.mixedDirections) }
        return .joinable(moves[0] > 0 ? .upward : .downward)
    }

    /// The join into tap `index` as written (`h`, `p`, `/`, `\`), or `nil` when it has none or one that
    /// no longer fits.
    static func symbol(into index: Int, of labels: [PieceLabel?]) -> String? {
        guard labels.indices.contains(index), case .fretted(_, let into?) = labels[index],
              let direction = direction(into: index, of: labels) else { return nil }
        return direction.symbol(for: into)
    }

    /// The answers with every join that no longer fits dropped: when the note before moves, the join
    /// into this one can stop making sense, and it goes rather than claim a hammer-on that isn't one.
    static func tidied(_ labels: [PieceLabel?]) -> [PieceLabel?] {
        labels.indices.map { index in
            guard case .fretted(let notes, .some) = labels[index], direction(into: index, of: labels) == nil else {
                return labels[index]
            }
            return .fretted(notes, into: nil)
        }
    }
}
