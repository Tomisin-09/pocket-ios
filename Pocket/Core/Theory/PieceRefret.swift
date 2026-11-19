import Foundation

/// **A piece saved before the song's shift changed** (ADR 0305 D5, Q5). Its frets are right for the
/// strings it was saved with, but they no longer match what you hear: named in Standard, then the song was
/// raised 1, and every fret now sounds a semitone under the record. When it's opened to edit, the sheet
/// offers to move every fret by the difference, **on the same string**. Nothing moves until the player
/// says so.
///
/// **When it's offered.** A piece doesn't record the shift it was named at (D5 turned down a `namedAt`
/// field), so the offer reads the strings: the song is shifted, and the piece's strings as you hear them
/// are the player's own tuning moved evenly. A piece named at the song's shift is heard on exactly the
/// player's strings, so it's never offered. A player who changed the tuner's tuning with the song at 0
/// isn't either: *a new tuning keeps the frets* (ADR 0227), and that's not this.
///
/// **Where a fret would fall off the neck** (an open string lowered, or one past the last fret), it asks
/// rather than guessing a string: those notes are listed, and moving leaves them for the player to name
/// again.
///
/// Pure and SwiftUI-free (AGENTS.md), so the move is unit-tested.
struct PieceRefret: Equatable, Sendable {
    /// How far every fret moves on its string: up when the song was raised since the piece was named.
    let semitones: Int
    /// The notes, by index, that can't move on their string. Moving leaves them unnamed.
    let stuck: [Int]

    /// The offer for a piece as you hear it (`Loop.heardTranscription`), or `nil` when its frets already
    /// match the player's strings, the song isn't shifted, or the strings differ by more than one move.
    static func offer(for heard: PieceTranscription, playerStrings: [Int], songShift: Int) -> PieceRefret? {
        guard songShift != 0, heard.hasFrettedLabels, let strings = heard.openMidi,
              let difference = PieceTuning.evenOffset(strings, from: playerStrings), difference != 0 else {
            return nil
        }
        let stuck = heard.labels.indices.filter { index in
            guard let label = heard.labels[index] else { return false }
            return moved(label, by: difference) == nil
        }
        return PieceRefret(semitones: difference, stuck: stuck)
    }

    /// The labels with every fret moved, the stuck ones left unnamed.
    func applied(to labels: [PieceLabel?]) -> [PieceLabel?] {
        labels.map { label in label.flatMap { Self.moved($0, by: semitones) } }
    }

    /// `label` with its frets `semitones` higher on the same strings, or `nil` when one would land off
    /// the neck. Names said by ear and dead strings have no fret, so they come back as they are.
    static func moved(_ label: PieceLabel, by semitones: Int) -> PieceLabel? {
        guard case .fretted(let notes, let muted, let join) = label else { return label }
        var movedNotes: [FrettedNote] = []
        for note in notes {
            guard let moved = moved(note, by: semitones) else { return nil }
            movedNotes.append(moved)
        }
        return .fretted(movedNotes, muted: muted, into: join)
    }

    private static func moved(_ note: FrettedNote, by semitones: Int) -> FrettedNote? {
        let frets = 0...PieceLabel.maxFret
        var moved = note
        moved.fret += semitones
        guard frets.contains(moved.fret) else { return nil }
        if case .fret(let from) = note.leadIn?.from {
            guard frets.contains(from + semitones) else { return nil }
            moved.leadIn?.from = .fret(from + semitones)
        }
        return moved
    }

    // MARK: - What the sheet says

    /// The line over the neck: *These frets were placed before the song's pitch changed. In Standard they
    /// sound 1 semitone under what you hear.*
    func line(playerTuning: String) -> String {
        let under = semitones > 0 ? "under" : "over"
        let amount = abs(semitones) == 1 ? "1 semitone" : "\(abs(semitones)) semitones"
        return "These frets were placed before the song's pitch changed. In \(playerTuning) they sound "
            + "\(amount) \(under) what you hear."
    }

    /// The button: *Move them up 1*.
    var button: String { "Move them \(semitones > 0 ? "up" : "down") \(abs(semitones))" }

    /// What the confirmation says when some notes can't move: *Note 4 can't move: on its string it would be
    /// lower than the open string. The rest move, and note 4 is left for you to name again.*
    var stuckMessage: String? {
        guard !stuck.isEmpty else { return nil }
        let numbers = stuck.map { "\($0 + 1)" }
        let way = semitones > 0 ? "higher than the last fret" : "lower than the open string"
        if numbers.count == 1 {
            return "Note \(numbers[0]) can't move: on its string it would be \(way). "
                + "The rest move, and note \(numbers[0]) is left for you to name again."
        }
        return "Notes \(Self.list(numbers)) can't move: on their strings they would be \(way). "
            + "The rest move, and they're left for you to name again."
    }

    /// *2, 5 and 7*.
    private static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
