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
    /// into this one can stop making sense, and it goes rather than claim a hammer-on that isn't one.
    /// Lead-ins go when they can't be played (`leadInsFit`). A note with a lead-in has no join from the
    /// tap before as well; it was heard as one.
    static func tidied(_ labels: [PieceLabel?]) -> [PieceLabel?] {
        labels.indices.map { index in
            guard case .fretted(var notes, var into) = labels[index] else { return labels[index] }
            if notes.contains(where: { $0.leadIn != nil }), !leadInsFit(notes) {
                for position in notes.indices { notes[position].leadIn = nil }
            }
            if notes.contains(where: { $0.leadIn != nil }) || direction(into: index, of: labels) == nil {
                into = nil
            }
            return .fretted(notes, into: into)
        }
    }
}

// MARK: - Lead-ins (ADR 0230)

extension NeckJoin {

    /// Whether a tap's lead-ins can be played. At least one note has one. The notes that move share one
    /// join and one direction, and each can be played into its fret; **the rest are held**, the way a
    /// finger hammers inside a chord (ADR 0252 D1). When every note moves, they move the same number of
    /// frets: a shape moving as one (0230 D6), the way a hand slides a double-stop.
    static func leadInsFit(_ notes: [FrettedNote]) -> Bool {
        let moving = notes.filter { $0.leadIn != nil }
        guard let first = moving.first?.leadIn, let way = first.direction(into: moving[0].fret) else { return false }
        let shared = moving.allSatisfy { note in
            note.leadIn?.join == first.join && note.leadIn?.direction(into: note.fret) == way
        }
        return shared && (moving.count < notes.count || movesAsOne(notes))
    }

    /// Whether every note has a lead-in, with the same join, from the same side and the same number of
    /// frets: the shape moves as one (0230 D6). A lone note with one does too.
    static func movesAsOne(_ notes: [FrettedNote]) -> Bool {
        guard let first = notes.first?.leadIn else { return false }
        let move = shift(of: notes[0])
        return notes.allSatisfy { $0.leadIn?.join == first.join && shift(of: $0) == move }
    }

    /// The notes with a start tapped at `string`, `fret` given to the note on that string alone, the rest
    /// held (ADR 0252 D1): the string tapped picks the note. `nil` when the tap isn't on their strings, or
    /// the start can't be played (its own fret, off the neck). Any other note's start goes.
    static func start(string: Int, fret: Int, of notes: [FrettedNote], join: Join) -> [FrettedNote]? {
        guard let moving = notes.firstIndex(where: { $0.string == string }),
              LeadIn(from: .fret(fret), join: join).direction(into: notes[moving].fret) != nil else { return nil }
        var started = notes
        for position in started.indices {
            started[position].leadIn = position == moving ? LeadIn(from: .fret(fret), join: join) : nil
        }
        return started
    }

    /// The notes with the lead-ins a start tapped at `string`, `fret` gives them: the note on that string
    /// starts there, and every other note as many frets from its own. `nil` when the tap isn't on their
    /// strings, or any start can't be played (its own fret, off the neck).
    static func starts(string: Int, fret: Int, of notes: [FrettedNote], join: Join) -> [FrettedNote]? {
        guard let anchor = notes.first(where: { $0.string == string }) else { return nil }
        let frets = fret - anchor.fret
        let started = notes.map { note in
            var note = note
            note.leadIn = LeadIn(from: .fret(note.fret + frets), join: join)
            return note
        }
        return started.allSatisfy { $0.leadIn?.direction(into: $0.fret) != nil } ? started : nil
    }

    /// *The whole chord moved?* (ADR 0252 D2): a hammer-on or pull-off on one note of a shape, given to
    /// every note as many frets from its own, so the shape moves as one. `nil` unless one note's start is
    /// a fret and the rest are held, or when a note would start off the neck.
    static func movedAsOne(_ notes: [FrettedNote]) -> [FrettedNote]? {
        let moving = notes.filter { $0.leadIn != nil }
        guard notes.count > 1, moving.count == 1, let leadIn = moving[0].leadIn, leadIn.join == .legato,
              case .fret(let start) = leadIn.from else { return nil }
        return starts(string: moving[0].string, fret: start, of: notes, join: leadIn.join)
    }

    /// The shape's move given to the note at `index`, just moved or added, from another note that has one,
    /// so a shape keeps sliding as one. With none to copy, the note has none.
    static func carryingLeadIn(_ notes: [FrettedNote], to index: Int) -> [FrettedNote] {
        var notes = notes
        let other = notes.indices.first { $0 != index && notes[$0].leadIn != nil }
        notes[index].leadIn = other.flatMap { source in
            notes[source].leadIn.map { leadIn in
                guard case .fret(let start) = leadIn.from else { return leadIn }
                return LeadIn(from: .fret(notes[index].fret + start - notes[source].fret), join: leadIn.join)
            }
        }
        return notes
    }

    /// How far, and from which side, a note's lead-in starts: what a shape's notes share.
    private enum Shift: Equatable {
        case frets(Int), below, above
    }

    private static func shift(of note: FrettedNote) -> Shift? {
        switch note.leadIn?.from {
        case .fret(let start)?: .frets(start - note.fret)
        case .below?: .below
        case .above?: .above
        case nil: nil
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
    /// In a shape, whether the start moves **every** note as many frets (0230 D6), or only the note on
    /// the string tapped while the rest are held (ADR 0252 D1). A slide always moves them all: a hand
    /// slides the shape, a finger hammers.
    let together: Bool

    init(join: Join, direction: JoinDirection?, together: Bool = false) {
        self.join = join
        self.direction = direction
        self.together = together || join == .slide
    }

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

    /// The tap before when it fits the choice, else a lead-in inside this tap: for one note; in a chord,
    /// a hammer-on or pull-off on the note whose string is tapped (ADR 0252 D1); a slide for the shape as
    /// one.
    static func route(_ choice: IntoChoice, into index: Int, of labels: [PieceLabel?]) -> Route {
        guard labels.indices.contains(index), let notes = labels[index]?.frettedNotes, !notes.isEmpty else {
            return .unavailable
        }
        let before = direction(into: index, of: labels)
        switch choice {
        case .picked:
            return .clear
        case .hammerOn, .pullOff:
            let way: JoinDirection = choice == .hammerOn ? .upward : .downward
            if before == way { return .fromBefore(.legato) }
            return .inside(LeadInRequest(join: .legato, direction: way))
        case .slide:
            if before != nil { return .fromBefore(.slide) }
            return .inside(LeadInRequest(join: .slide, direction: nil))
        }
    }

    /// Whether a choice is the one the tap at `index` holds now, from the tap before or inside the note.
    /// Inside a shape it's the moving note's, wherever it is (0252 D1).
    static func holds(_ choice: IntoChoice, into index: Int, of labels: [PieceLabel?]) -> Bool {
        guard labels.indices.contains(index), case .fretted(let notes, let into) = labels[index],
              !notes.isEmpty else { return false }
        let moving = notes.first { $0.leadIn != nil } ?? notes[0]
        let leadIn = moving.leadIn
        let join = leadIn?.join ?? into
        let way = leadIn.flatMap { $0.direction(into: moving.fret) } ?? direction(into: index, of: labels)
        switch choice {
        case .picked: return join == nil
        case .hammerOn: return join == .legato && way == .upward
        case .pullOff: return join == .legato && way == .downward
        case .slide: return join == .slide
        }
    }

    /// Whether a tap on the neck at `string`, `fret` can be where `notes` started, for `request`.
    static func accepts(string: Int, fret: Int, asStartOf notes: [FrettedNote], for request: LeadInRequest) -> Bool {
        started(string: string, fret: fret, of: notes, for: request) != nil
    }

    /// The notes with the start a tap at `string`, `fret` gives them for `request`, or `nil` when it can't
    /// be one. On one of their strings, from the side the join moves from. When the request moves the
    /// shape, every note moves as many frets and stays on the neck (`starts`); otherwise only the note on
    /// that string moves and the rest are held (`start`, 0252 D1), so another note can't dim the fret.
    static func started(string: Int, fret: Int, of notes: [FrettedNote], for request: LeadInRequest) -> [FrettedNote]? {
        let started = request.together ? starts(string: string, fret: fret, of: notes, join: request.join)
            : start(string: string, fret: fret, of: notes, join: request.join)
        guard let started else { return nil }
        let fromTheSide = request.direction == nil || started.allSatisfy { note in
            note.leadIn.map { $0.direction(into: note.fret) == request.direction } ?? true
        }
        return fromTheSide ? started : nil
    }
}
