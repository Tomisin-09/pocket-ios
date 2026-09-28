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
    /// no longer fits. A note heard as one carries its join inside it, as its lead-in, and has none here.
    static func symbol(into index: Int, of labels: [PieceLabel?]) -> String? {
        guard labels.indices.contains(index), case .fretted(let notes, let into?) = labels[index],
              !notes.contains(where: { $0.leadIn != nil }),
              let direction = direction(into: index, of: labels) else { return nil }
        return direction.symbol(for: into)
    }

    /// The answers with every join that no longer fits dropped: when the note before moves, the join
    /// into this one can stop making sense, and it goes rather than claim a hammer-on that isn't one. A
    /// lead-in goes when it can't be played into its note any more, and from a shape: it's one note's.
    /// A note with a lead-in has no join from the tap before as well; it was heard as one.
    static func tidied(_ labels: [PieceLabel?]) -> [PieceLabel?] {
        labels.indices.map { index in
            guard case .fretted(var notes, var into) = labels[index] else { return labels[index] }
            for position in notes.indices {
                guard let leadIn = notes[position].leadIn else { continue }
                if notes.count > 1 || leadIn.direction(into: notes[position].fret) == nil {
                    notes[position].leadIn = nil
                }
            }
            if notes.contains(where: { $0.leadIn != nil }) || direction(into: index, of: labels) == nil {
                into = nil
            }
            return .fretted(notes, into: into)
        }
    }
}

// MARK: - The four ways in (ADR 0230)

/// The choices under the neck: **Picked**, **Hammer-on**, **Pull-off** and **Slide**, always all four, so
/// a pull-off is there to be seen before a note goes down to one.
enum IntoChoice: CaseIterable, Equatable, Sendable {
    case picked, hammerOn, pullOff, slide

    var title: String {
        switch self {
        case .picked: "Picked"
        case .hammerOn: "Hammer-on"
        case .pullOff: "Pull-off"
        case .slide: "Slide"
        }
    }
}

/// A lead-in waiting on the neck for its start: *Tap the fret it started on*. A hammer-on starts lower and
/// a pull-off higher; a slide can start either side, or come in from nowhere.
struct LeadInRequest: Equatable, Sendable {
    let join: Join
    /// The way it has to move into the note, or `nil` for a slide.
    let direction: JoinDirection?

    /// The choice it was asked for, lit while the neck waits.
    var choice: IntoChoice {
        join == .slide ? .slide : direction == .downward ? .pullOff : .hammerOn
    }
}

extension NeckJoin {

    /// What a choice does for the tap at `index`.
    enum Route: Equatable {
        /// Take any join and lead-in off: picked.
        case clear
        /// Join from the tap before, which fits this way.
        case fromBefore(Join)
        /// Start inside this note: ask for where, on the neck.
        case inside(LeadInRequest)
        /// Nothing to do here: the note isn't on the neck, or it's a shape the tap before doesn't fit.
        case unavailable
    }

    /// The tap before when it fits the choice, else a lead-in inside this note. A lead-in is one note's,
    /// so a shape only joins from the tap before.
    static func route(_ choice: IntoChoice, into index: Int, of labels: [PieceLabel?]) -> Route {
        guard labels.indices.contains(index), let notes = labels[index]?.frettedNotes, !notes.isEmpty else {
            return .unavailable
        }
        let before = direction(into: index, of: labels)
        let single = notes.count == 1
        switch choice {
        case .picked:
            return .clear
        case .hammerOn, .pullOff:
            let way: JoinDirection = choice == .hammerOn ? .upward : .downward
            if before == way { return .fromBefore(.legato) }
            return single ? .inside(LeadInRequest(join: .legato, direction: way)) : .unavailable
        case .slide:
            if before != nil { return .fromBefore(.slide) }
            return single ? .inside(LeadInRequest(join: .slide, direction: nil)) : .unavailable
        }
    }

    /// Whether a choice is the one the tap at `index` holds now, from the tap before or inside the note.
    static func holds(_ choice: IntoChoice, into index: Int, of labels: [PieceLabel?]) -> Bool {
        guard labels.indices.contains(index), case .fretted(let notes, let into) = labels[index],
              !notes.isEmpty else { return false }
        let leadIn = notes.count == 1 ? notes[0].leadIn : nil
        let join = leadIn?.join ?? into
        let way = leadIn.flatMap { $0.direction(into: notes[0].fret) } ?? direction(into: index, of: labels)
        switch choice {
        case .picked: return join == nil
        case .hammerOn: return join == .legato && way == .upward
        case .pullOff: return join == .legato && way == .downward
        case .slide: return join == .slide
        }
    }

    /// Whether a tap on the neck at `string`, `fret` can be where `note` started, for `request`: on its
    /// string, not its fret, and on the side the join moves from.
    static func accepts(string: Int, fret: Int, asStartOf note: FrettedNote, for request: LeadInRequest) -> Bool {
        guard string == note.string,
              let way = LeadIn(from: .fret(fret), join: request.join).direction(into: note.fret) else { return false }
        return request.direction == nil || request.direction == way
    }
}
