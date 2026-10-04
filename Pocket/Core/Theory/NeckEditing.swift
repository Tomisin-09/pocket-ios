import Foundation

/// Where an editor on the neck is (ADR 0235 D9): the note being named or written, the note the marks are
/// still on after a placement moved past it, a shape's ringed string, *Chords*, and *Into it* waiting for
/// a start. Name the notes and the tab writer both keep one, so the rules below read and write it the same
/// way for both.
struct NeckCursor: Equatable, Sendable {
    /// The note being named or written.
    var active: Int
    /// The note just placed, while the editor has moved on past it (ADR 0234 D3): the marks stay on it
    /// until the next note is placed or another is picked. `nil` whenever the marks go with `active`.
    var placedNote: Int?
    /// The string of the **ringed** note in a shape, the one bend and vibrato go on.
    var ringed: Int?
    /// **Chords** on the neck (0227 D4): one note per string, so a tap adds rather than replaces.
    var chordsOn = false
    /// *Into it* waiting for the neck to say where the note started (0227 D5, a lead-in).
    var awaitingStart: LeadInRequest?

    init(active: Int, placedNote: Int? = nil, ringed: Int? = nil, chordsOn: Bool = false,
         awaitingStart: LeadInRequest? = nil) {
        self.active = active
        self.placedNote = placedNote
        self.ringed = ringed
        self.chordsOn = chordsOn
        self.awaitingStart = awaitingStart
    }

    /// The note the marks go on: the one just placed while the editor has moved past it, else `active`.
    func marked(count: Int) -> Int {
        placedNote.flatMap { (0..<count).contains($0) ? $0 : nil } ?? active
    }
}

/// **What a touch on the neck does** (ADR 0227 D3–D5, 0230, 0234 D3), lifted out of Name the notes so the
/// tab writer can share it (ADR 0235 D9): place a note and move on, mark it, join it from the note before
/// or start it inside itself. Each rule takes the answers and the cursor and gives back both; the editor
/// writes the answers as one step of its history and keeps the cursor.
///
/// Pure and SwiftUI-free (AGENTS.md), so the rules are unit-tested.
enum NeckEditing {

    struct Edit: Equatable {
        var labels: [PieceLabel?]
        var cursor: NeckCursor
    }

    /// A tap on the neck, by `NeckPlacement`'s rules: with Chords off it replaces the note (which keeps its
    /// marks), with Chords on it builds a shape one note per string. With Chords off, **placing a note moves
    /// on** and the marks stay on it (`NamingCursor`). While *Into it* waits for where a note started, the
    /// tap says that instead.
    static func place(string: Int, fret: Int, labels: [PieceLabel?], cursor: NeckCursor) -> Edit {
        if let request = cursor.awaitingStart {
            return takeStart(string: string, fret: fret, for: request, labels: labels, cursor: cursor)
        }
        let active = cursor.active
        guard labels.indices.contains(active) else { return Edit(labels: labels, cursor: cursor) }
        var labels = labels
        var cursor = cursor
        let outcome = NeckPlacement.tap(string: string, fret: fret, on: labels[active], ringed: cursor.ringed,
                                        chords: cursor.chordsOn)
        labels[active] = outcome.label
        cursor.ringed = outcome.ringed
        guard outcome.label.isOnTheNeck else { return Edit(labels: labels, cursor: cursor) }
        let move = NamingCursor.afterPlacing(at: active, count: labels.count, chords: cursor.chordsOn)
        // Where it doesn't move on (Chords on, the last note), the marks are the note's own again.
        cursor.placedNote = move.marked
        cursor.active = move.active
        return Edit(labels: labels, cursor: cursor)
    }

    /// The note bend and vibrato go on: the marked note, or a shape's ringed note (0227 D5).
    static func ringedNote(labels: [PieceLabel?], cursor: NeckCursor) -> FrettedNote? {
        let marked = cursor.marked(count: labels.count)
        let notes = labels.indices.contains(marked) ? labels[marked]?.frettedNotes ?? [] : []
        return notes.first { $0.string == cursor.ringed } ?? notes.last
    }

    /// Change the marks on the marked note, or on a shape's ringed note.
    static func mark(_ change: (inout FrettedNote) -> Void, labels: [PieceLabel?],
                     cursor: NeckCursor) -> [PieceLabel?] {
        let marked = cursor.marked(count: labels.count)
        guard labels.indices.contains(marked), case .fretted(var notes, let into) = labels[marked],
              !notes.isEmpty else { return labels }
        let index = notes.firstIndex { $0.string == cursor.ringed } ?? notes.count - 1
        change(&notes[index])
        var labels = labels
        labels[marked] = .fretted(notes, into: into)
        return labels
    }

    // MARK: - Into it (ADR 0230)

    /// Join from the tap before when it fits, else ask the neck for where the note started. Tapping the
    /// choice already held changes nothing, so it can't swap a lead-in for the tap before by surprise.
    static func choose(_ choice: IntoChoice, labels: [PieceLabel?], cursor: NeckCursor) -> Edit {
        let marked = cursor.marked(count: labels.count)
        let route = NeckJoin.route(choice, into: marked, of: labels)
        var cursor = cursor
        let waiting = cursor.awaitingStart != nil
        cursor.awaitingStart = nil
        guard waiting || choice == .picked || !NeckJoin.holds(choice, into: marked, of: labels) else {
            return Edit(labels: labels, cursor: cursor)
        }
        switch route {
        case .clear:
            return Edit(labels: setInto(nil, at: marked, of: labels), cursor: cursor)
        case .fromBefore(let join):
            return Edit(labels: setInto(join, at: marked, of: labels), cursor: cursor)
        case .inside(let request):
            cursor.awaitingStart = request
            return Edit(labels: labels, cursor: cursor)
        case .unavailable:
            return Edit(labels: labels, cursor: cursor)
        }
    }

    /// Join from the tap before, or pick it: either way no lead-in. Never both (ADR 0230 D6).
    static func setInto(_ join: Join?, at index: Int, of labels: [PieceLabel?]) -> [PieceLabel?] {
        guard labels.indices.contains(index), case .fretted(var notes, _) = labels[index] else { return labels }
        for position in notes.indices { notes[position].leadIn = nil }
        var labels = labels
        labels[index] = .fretted(notes, into: join)
        return labels
    }

    /// A tap on the neck while *Into it* waits for a start: where the lead-in began, when it can be. In a
    /// shape, a hammer-on or pull-off moves the note on the string tapped and the rest are held (ADR 0252
    /// D1), one tap and done; a slide, or a request to move the shape, moves every other note as many
    /// frets. A tap on one of the tap's own notes gives up; any other is left alone, since the dimmed dots
    /// say where to tap.
    static func takeStart(string: Int, fret: Int, for request: LeadInRequest, labels: [PieceLabel?],
                          cursor: NeckCursor) -> Edit {
        let marked = cursor.marked(count: labels.count)
        var cursor = cursor
        guard labels.indices.contains(marked), case .fretted(let notes, _) = labels[marked], !notes.isEmpty else {
            cursor.awaitingStart = nil
            return Edit(labels: labels, cursor: cursor)
        }
        if let started = NeckJoin.started(string: string, fret: fret, of: notes, for: request) {
            var labels = labels
            labels[marked] = .fretted(started, into: nil)
            cursor.awaitingStart = nil
            return Edit(labels: labels, cursor: cursor)
        }
        if notes.contains(where: { $0.string == string && $0.fret == fret }) {
            cursor.awaitingStart = nil
        }
        return Edit(labels: labels, cursor: cursor)
    }

    /// *The whole chord moved?* (ADR 0252 D2): the one note's hammer-on or pull-off given to every note,
    /// as many frets from its own, by `NeckJoin.movedAsOne`. No change when a note would start off the neck.
    static func moveTogether(labels: [PieceLabel?], cursor: NeckCursor) -> Edit {
        let marked = cursor.marked(count: labels.count)
        var cursor = cursor
        cursor.awaitingStart = nil
        guard labels.indices.contains(marked), case .fretted(let notes, _) = labels[marked],
              let moved = NeckJoin.movedAsOne(notes) else { return Edit(labels: labels, cursor: cursor) }
        var labels = labels
        labels[marked] = .fretted(moved, into: nil)
        return Edit(labels: labels, cursor: cursor)
    }

    /// A slide in from nowhere, for every note of the tap.
    static func slideIn(from start: LeadIn.Start, labels: [PieceLabel?], cursor: NeckCursor) -> Edit {
        let marked = cursor.marked(count: labels.count)
        guard labels.indices.contains(marked), case .fretted(var notes, _) = labels[marked] else {
            return Edit(labels: labels, cursor: cursor)
        }
        for position in notes.indices { notes[position].leadIn = LeadIn(from: start, join: .slide) }
        var labels = labels
        labels[marked] = .fretted(notes, into: nil)
        var cursor = cursor
        cursor.awaitingStart = nil
        return Edit(labels: labels, cursor: cursor)
    }
}
